// Setup type definitions for built-in Supabase Runtime APIs
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type WebhookPayload = {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: "public";
  record: {
    id: string;
    user_id: string;
    title: string | null;
  };
  old_record: null | Record<string, unknown>;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID");
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL");
let FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY");

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY");
}
if (!FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
  throw new Error(
    "Missing FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / FIREBASE_PRIVATE_KEY",
  );
}

// private_key kommer ofte med \n i secrets; gjør den om til ekte linjeskift
FIREBASE_PRIVATE_KEY = FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n");

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function base64UrlEncode(input: Uint8Array): string {
  // base64url (RFC 7515)
  const b64 = btoa(String.fromCharCode(...input));
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function signJwtRs256(payload: Record<string, unknown>): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };

  const enc = new TextEncoder();
  const headerB64 = base64UrlEncode(enc.encode(JSON.stringify(header)));
  const payloadB64 = base64UrlEncode(enc.encode(JSON.stringify(payload)));
  const unsigned = `${headerB64}.${payloadB64}`;

  // Import PEM private key
  const pem = FIREBASE_PRIVATE_KEY!;
  const pkcs8 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  const keyDer = Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    enc.encode(unsigned),
  );

  const sigB64 = base64UrlEncode(new Uint8Array(sig));
  return `${unsigned}.${sigB64}`;
}

async function getGoogleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const jwt = await signJwtRs256({
    iss: FIREBASE_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 60 * 60, // 1 time
  });

  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion: jwt,
  });

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const txt = await res.text();
  if (!res.ok) {
    console.log("OAuth token error body:", txt);
    throw new Error(`OAuth token failed ${res.status}: ${txt}`);
  }

  const json = JSON.parse(txt);
  const accessToken = json.access_token as string | undefined;
  if (!accessToken) throw new Error("No access_token in OAuth response");
  return accessToken;
}

async function sendFcmV1(token: string, noteTitle: string): Promise<void> {
  const accessToken = await getGoogleAccessToken();

  const url =
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`;

  const message = {
    message: {
      token,
      notification: {
        title: `Nytt notat: ${noteTitle}`,
        body: "Åpne appen for å lese.",
      },
      data: { kind: "new_note" },
      android: {
        priority: "high",
      },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(message),
  });

  const txt = await res.text();
  console.log("FCM status:", res.status);
  console.log("FCM body:", txt);

  if (!res.ok) {
    throw new Error(`FCM v1 send failed ${res.status}: ${txt}`);
  }
}

Deno.serve(async (req) => {
  try {
    console.log("push_notes hit");
    console.log("req method:", req.method);

    const payload: WebhookPayload = await req.json();

    console.log("event:", payload.type, "table:", payload.table);
    console.log("record:", JSON.stringify(payload.record));

    // Kun INSERT på notes
    if (payload.type !== "INSERT" || payload.table !== "notes") {
      return new Response(JSON.stringify({ ok: true, skipped: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const authorId = payload.record.user_id;
    const title = (payload.record.title ?? "").trim() || "(Uten tittel)";

    const { data, error } = await supabase
      .from("device_tokens")
      .select("token,user_id,platform")
      .eq("platform", "android")
      .neq("user_id", authorId);

    if (error) {
      console.log("DB error:", JSON.stringify(error));
      throw error;
    }

    console.log("tokens found:", (data ?? []).length);

    const tokens = (data ?? []).map((x) => x.token).filter(Boolean);

    for (const t of tokens) {
      console.log("sending to token (first 12):", t.slice(0, 12));
      await sendFcmV1(t, title);
    }

    return new Response(JSON.stringify({ ok: true, sent: tokens.length }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.log("FUNCTION ERROR:", e?.message ?? String(e));
    return new Response(
      JSON.stringify({ ok: false, error: e?.message ?? String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});