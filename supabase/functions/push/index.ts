// ============================================================================
// Block 4.3b: Edge Function "push" — invio notifiche FCM
//
// Invocata dai Database Webhooks su event_requests:
//   INSERT                  -> push al GESTORE ("nuova richiesta")
//   UPDATE (cambio status)  -> push al CLIENTE ("approvata"/"non accettata")
//
// Deploy (dashboard Supabase, zero budget):
//   1. Edge Functions -> New function -> nome "push" -> incolla questo file.
//      DISATTIVA "Verify JWT": l'auth e' il secret header qui sotto.
//   2. Secrets della funzione:
//        FIREBASE_SERVICE_ACCOUNT = intero JSON della chiave service account
//        WEBHOOK_SECRET           = stringa lunga casuale (generata da te)
//      (SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY sono iniettate in automatico.)
//   3. Database -> Webhooks -> due webhook sulla tabella event_requests
//      (uno per INSERT, uno per UPDATE), method POST, URL:
//        https://<project-ref>.supabase.co/functions/v1/push
//      con HTTP header:  x-webhook-secret: <lo stesso WEBHOOK_SECRET>
//
// Sicurezza: service role e chiave Firebase vivono SOLO qui come secret;
// nessuna chiave di invio nell'app. Il testo delle notifiche resta discreto
// (niente riferimenti espliciti sulla lock screen).
// ============================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

type WebhookPayload = {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: Record<string, unknown> | null;
  old_record: Record<string, unknown> | null;
};

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// --- OAuth2 verso Google (JWT RS256 firmato con la chiave service account) ---

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

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) {
    return cachedToken.value;
  }

  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
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

// --- Invio FCM v1 ---

async function sendPush(
  projectId: string,
  accessToken: string,
  deviceToken: string,
  title: string,
  body: string,
): Promise<"ok" | "unregistered" | "error"> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: { token: deviceToken, notification: { title, body } },
      }),
    },
  );
  if (res.ok) return "ok";
  const text = await res.text();
  // Token scaduto/app disinstallata: la riga va ripulita da device_tokens.
  if (res.status === 404 || text.includes("UNREGISTERED")) {
    return "unregistered";
  }
  console.error(`FCM error ${res.status}: ${text}`);
  return "error";
}

// --- Handler webhook ---

Deno.serve(async (req: Request): Promise<Response> => {
  const secret = Deno.env.get("WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-webhook-secret") !== secret) {
    return Response.json({ error: "forbidden" }, { status: 403 });
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return Response.json({ error: "bad payload" }, { status: 400 });
  }
  if (payload.table !== "event_requests" || !payload.record) {
    return Response.json({ skipped: true });
  }

  const record = payload.record;
  const eventId = String(record.event_id ?? "");
  const newStatus = String(record.status ?? "");
  const oldStatus = String(payload.old_record?.status ?? "");

  // Titolo evento + host (service role: bypassa RLS, solo lato server).
  const { data: event } = await supabase
    .from("events")
    .select("title, host_id")
    .eq("id", eventId)
    .maybeSingle();
  if (!event) return Response.json({ skipped: "event not found" });

  // Destinatario e testo (copy discreta: finisce sulla lock screen).
  let recipient: string;
  let title: string;
  let body: string;
  if (payload.type === "INSERT") {
    recipient = String(event.host_id);
    title = "Nuova richiesta ospiti";
    body = `Un profilo si e' candidato per "${event.title}".`;
  } else if (
    payload.type === "UPDATE" &&
    newStatus !== oldStatus &&
    (newStatus === "approved" || newStatus === "rejected")
  ) {
    recipient = String(record.user_id ?? "");
    if (newStatus === "approved") {
      title = "Richiesta approvata";
      body = `Sei in lista per "${event.title}". Benvenuto al tavolo.`;
    } else {
      title = "Richiesta non accettata";
      body = `La candidatura per "${event.title}" non e' andata a buon fine.`;
    }
  } else {
    return Response.json({ skipped: "no notification for this change" });
  }

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", recipient);
  if (!tokens || tokens.length === 0) {
    return Response.json({ sent: 0, reason: "no device tokens" });
  }

  const sa: ServiceAccount = JSON.parse(
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!,
  );
  const accessToken = await getFcmAccessToken(sa);

  let sent = 0;
  const stale: string[] = [];
  for (const row of tokens) {
    const outcome = await sendPush(
      sa.project_id,
      accessToken,
      row.token,
      title,
      body,
    );
    if (outcome === "ok") sent++;
    if (outcome === "unregistered") stale.push(row.token);
  }
  if (stale.length > 0) {
    await supabase
      .from("device_tokens")
      .delete()
      .eq("user_id", recipient)
      .in("token", stale);
  }

  return Response.json({ sent, stale: stale.length });
});
