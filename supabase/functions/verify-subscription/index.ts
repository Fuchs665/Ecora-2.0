// ============================================================================
// Block 5.2: Edge Function "verify-subscription" — verifica abbonamento gestore
//
// Chiamata dall'app (utente loggato) dopo un acquisto o un restore:
//   POST /functions/v1/verify-subscription   body: { "purchase_token": "..." }
//
// Flusso: identita' dal JWT utente -> deve essere un gestore -> Google Play
// Developer API (purchases.subscriptionsv2.get) dice lo stato reale del
// token -> se valido, upsert su public.subscriptions con service_role
// (unica via di scrittura: il client non ha policy INSERT/UPDATE, vedi 0013).
// Il gate vero resta la RLS su events (has_active_subscription()).
//
// Deploy (dashboard Supabase, zero budget):
//   1. Edge Functions -> Deploy a new function -> nome "verify-subscription"
//      -> incolla questo file. LASCIA ATTIVO "Verify JWT" (a differenza di
//      "push": qui il chiamante e' l'utente loggato, non un webhook).
//   2. Secret della funzione:
//        PLAY_SERVICE_ACCOUNT = intero JSON della chiave del service account
//        DEDICATO a Google Play (separato da FIREBASE_SERVICE_ACCOUNT:
//        meno blast radius se una delle due chiavi va ruotata).
//      (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY iniettate in automatico.)
//   3. Setup Google una tantum (gratuito): su GCP crea il service account e
//      la chiave JSON e abilita "Google Play Android Developer API"; in
//      Play Console -> Impostazioni -> Accesso API collega il progetto GCP
//      e concedi al service account il permesso "Visualizza dati finanziari".
//
// Anti-replay: purchase_token e' UNIQUE in tabella (0013); se il token e'
// gia' associato a un ALTRO account l'upsert fallisce con 23505 -> 409.
//
// Limiti v1 (accettati, decisioni 2026-07-15):
//   - niente RTDN/Pub-Sub: verifica solo on-demand. Un rimborso (REVOKED)
//     non azzera la riga: l'expiry gia' scritto scade da solo (max ~1 mese).
//   - acknowledgment lato client: in_app_purchase.completePurchase() (5.3).
//     Senza ack entro 3 giorni Google rimborsa da solo l'acquisto.
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

type ServiceAccount = {
  client_email: string;
  private_key: string;
};

// Risposta (parziale) di purchases.subscriptionsv2.get
type PlaySubscription = {
  subscriptionState?: string;
  lineItems?: Array<{
    productId?: string;
    expiryTime?: string;
    autoRenewingPlan?: { autoRenewEnabled?: boolean };
  }>;
};

const PACKAGE_NAME = "com.ecora.app";
const PRODUCT_ID = "ecora_gestore_monthly";

// Stati che danno accesso fino a expiryTime. CANCELED = rinnovo disattivato
// ma periodo gia' pagato: resta attivo fino alla scadenza (decisione v1).
const VALID_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// CORS: serve solo per i test da build web; su Android non ha effetto.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// --- OAuth2 verso Google (stesso schema della funzione "push", scope
// androidpublisher invece di firebase.messaging) ---

let cachedToken: { value: string; expiresAt: number } | null = null;

function b64url(data: Uint8Array | string): string {
  const bytes =
    typeof data === "string" ? new TextEncoder().encode(data) : data;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

async function getPlayAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.value;
  }

  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const jwt = `${unsigned}.${b64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`OAuth token error ${res.status}: ${await res.text()}`);
  }
  const data = await res.json();
  cachedToken = {
    value: data.access_token,
    expiresAt: now + Math.min(data.expires_in ?? 3600, 3600),
  };
  return cachedToken.value;
}

// --- Handler ---

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  // 1) Identita': il gateway (Verify JWT) ha gia' validato la firma, ma
  //    l'utente va risolto comunque — MAI fidarsi di uno user_id nel body.
  const jwt = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "");
  const { data: userData, error: userError } = await supabase.auth.getUser(
    jwt,
  );
  const user = userData?.user;
  if (userError || !user) {
    return json({ error: "non autenticato" }, 401);
  }

  // 2) Solo i gestori hanno un abbonamento.
  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  if (profile?.role !== "gestore") {
    return json({ error: "riservato ai gestori" }, 403);
  }

  // 3) Input.
  let purchaseToken = "";
  try {
    const body = await req.json();
    purchaseToken = String(body?.purchase_token ?? "").trim();
  } catch {
    // body assente o non-JSON: gestito sotto
  }
  if (purchaseToken === "") {
    return json({ error: "purchase_token mancante" }, 400);
  }

  // 4) Stato reale del token secondo Google.
  const sa: ServiceAccount = JSON.parse(
    Deno.env.get("PLAY_SERVICE_ACCOUNT")!,
  );
  const accessToken = await getPlayAccessToken(sa);
  const playRes = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${
      encodeURIComponent(purchaseToken)
    }`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  if (playRes.status === 400 || playRes.status === 404) {
    // Token inesistente o malformato: NON e' un errore nostro.
    return json({ active: false, error: "purchase token non valido" }, 400);
  }
  if (!playRes.ok) {
    console.error(`Play API ${playRes.status}: ${await playRes.text()}`);
    return json({ error: "verifica non disponibile, riprova" }, 502);
  }
  const sub: PlaySubscription = await playRes.json();

  const state = String(sub.subscriptionState ?? "");
  const line = (sub.lineItems ?? []).find((l) => l.productId === PRODUCT_ID);
  const expiry = line?.expiryTime ? new Date(line.expiryTime) : null;
  if (
    !VALID_STATES.has(state) || !expiry || Number.isNaN(expiry.getTime())
  ) {
    // Stato non abilitante (PENDING/ON_HOLD/PAUSED/EXPIRED/REVOKED/...):
    // nessuna scrittura, il DB resta com'era.
    return json({ active: false, state });
  }

  // 5) Upsert con service_role (bypassa RLS: e' l'unico punto di scrittura).
  const { error: upsertError } = await supabase.from("subscriptions").upsert({
    user_id: user.id,
    product_id: PRODUCT_ID,
    purchase_token: purchaseToken,
    expiry_time: expiry.toISOString(),
    auto_renewing: line?.autoRenewingPlan?.autoRenewEnabled === true,
    last_verified_at: new Date().toISOString(),
  }, { onConflict: "user_id" });
  if (upsertError) {
    if (upsertError.code === "23505") {
      // UNIQUE(purchase_token): il token appartiene gia' a un altro account.
      return json(
        { error: "abbonamento gia' associato a un altro account" },
        409,
      );
    }
    console.error("upsert subscriptions:", upsertError);
    return json({ error: "scrittura stato fallita" }, 500);
  }

  return json({
    active: expiry.getTime() > Date.now(),
    expiry_time: expiry.toISOString(),
    state,
  });
});
