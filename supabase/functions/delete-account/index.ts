// ============================================================================
// Blocco E.1a: Edge Function "delete-account" — cancellazione dell'account
// (Google Play 2024, Apple 5.1.1(v), GDPR art. 17).
//
// TOCCA AUTH E DATI PERSONALI. È l'unico punto che cancella un utente:
// la service role vive solo qui come secret, mai nell'app né nella pagina web.
//
// Chiamata dall'app (E.1b) e dalla pagina web su GitHub Pages (E.1c), con la
// sessione dell'utente:
//   POST /functions/v1/delete-account
//   body: { "password": "...", "channel": "app" | "web" }
//
// Passi, tutti rieseguibili (se uno fallisce, l'utente riprova e la seconda
// chiamata completa il lavoro):
//   1. utente dal JWT (mai dal body) e riautenticazione: la password viene
//      verificata con un login separato, che deve restituire lo stesso uid;
//   2. file nello Storage (galleria e copertine), con l'API Storage: il
//      cascade non li tocca e Supabase non permette di cancellarli via SQL;
//   3. dati nel database, in una transazione (delete_account_data, 0016);
//   4. utente auth (auth.admin.deleteUser): sparisce con sessioni e
//      refresh token;
//   5. una riga anonima nel registro account_deletions (ruolo e canale).
// Se il passo 3 è fatto e il 4 fallisce, un nuovo login ricreerebbe un
// profilo vuoto (riparazione in main.dart): basta riprovare, il passo 3
// lo cancella di nuovo.
//
// Deploy (dashboard Supabase, zero budget), DOPO aver applicato la 0016:
//   Edge Functions -> Deploy a new function -> nome "delete-account" ->
//   incolla questo file. LASCIA ATTIVO "Verify JWT". Nessun secret da
//   aggiungere: SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY
//   sono iniettate in automatico.
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

// Solo la pagina web ufficiale può chiamarla da un browser. L'app Android
// non manda Origin, quindi il CORS non la riguarda.
const ALLOWED_ORIGIN = "https://fuchs665.github.io";

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const NO_SESSION = {
  auth: { persistSession: false, autoRefreshToken: false },
};

const admin = createClient(
  SUPABASE_URL,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  NO_SESSION,
);

// Risposte: { ok: true } oppure { error: <codice> }. I codici sono quelli
// che l'app e la pagina web traducono in messaggi.
function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Nei log niente email né uid: solo il passo e l'errore.
function fail(step: string, error: unknown): Response {
  console.error(`delete-account: passo ${step} fallito`, error);
  return json({ error: step }, 500);
}

type StorageFile = { bucket: string; path: string };

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  // --- 1. Chi è e riautenticazione ---
  const jwt = (req.headers.get("Authorization") ?? "")
    .replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "unauthorized" }, 401);

  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (userError || !user || !user.email) {
    return json({ error: "unauthorized" }, 401);
  }

  let body: { password?: unknown; channel?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  const password = typeof body.password === "string" ? body.password : "";
  if (!password) return json({ error: "bad_request" }, 400);
  const channel = body.channel === "web" ? "web" : "app";

  const verifier = createClient(
    SUPABASE_URL,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    NO_SESSION,
  );
  const { data: signIn, error: signInError } = await verifier.auth
    .signInWithPassword({ email: user.email, password });
  if (signInError || signIn.user?.id !== user.id) {
    if (signInError?.status === 429) {
      return json({ error: "rate_limited" }, 429);
    }
    return json({ error: "wrong_password" }, 401);
  }

  // --- 2. File nello Storage ---
  const { data: files, error: filesError } = await admin.rpc(
    "account_deletion_files",
    { p_user_id: user.id },
  );
  if (filesError) return fail("storage", filesError);

  const byBucket = new Map<string, string[]>();
  for (const f of (files ?? []) as StorageFile[]) {
    byBucket.set(f.bucket, [...(byBucket.get(f.bucket) ?? []), f.path]);
  }
  for (const [bucket, paths] of byBucket) {
    for (let i = 0; i < paths.length; i += 100) {
      const { error } = await admin.storage
        .from(bucket)
        .remove(paths.slice(i, i + 100));
      if (error) return fail("storage", error);
    }
  }

  // --- 3. Dati nel database ---
  const { data: summary, error: dataError } = await admin.rpc(
    "delete_account_data",
    { p_user_id: user.id },
  );
  if (dataError) return fail("database", dataError);

  // --- 4. Utente auth ---
  const { error: authError } = await admin.auth.admin.deleteUser(user.id);
  if (authError) return fail("auth", authError);

  // --- 5. Registro anonimo (best effort: la cancellazione è già avvenuta) ---
  const { error: logError } = await admin.from("account_deletions").insert({
    role: (summary as { role?: string | null } | null)?.role ?? null,
    channel,
  });
  if (logError) console.error("delete-account: registro non scritto", logError);

  return json({ ok: true });
});
