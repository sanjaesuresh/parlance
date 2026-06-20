// send-push — Supabase Edge Function (Deno 2)
// Looks up a user's APNs token and sends a push notification via the APNs HTTP/2 API.
//
// POST body: { userId: string, title: string, body: string, data?: object }
// Env vars (injected by Supabase runtime):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// Env vars (set manually via `supabase secrets set`):
//   APNS_KEY      — full PEM content of the .p8 file, newlines stored as \n
//   APNS_KEY_ID   — 10-character key ID from Apple Developer portal
//   APNS_TEAM_ID  — 10-character team ID

import { createClient } from "jsr:@supabase/supabase-js@2";

// ── APNs constants ────────────────────────────────────────────────────────────
const APNS_HOST = "https://api.push.apple.com";
const BUNDLE_ID = "org.Parlance";

// ── Module-level JWT + key cache ─────────────────────────────────────────────
let cachedJwt = "";
let jwtIssuedAt = 0;
let cachedCryptoKey: CryptoKey | null = null;

// ── JWT signing ───────────────────────────────────────────────────────────────

/**
 * Returns a valid APNs provider JWT, re-generating it if it is older than 55
 * minutes (APNs requires a fresh token at least every 60 minutes).
 */
async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - jwtIssuedAt < 55 * 60) return cachedJwt;

  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  if (!keyId || !teamId) {
    throw new Error("APNS_KEY_ID or APNS_TEAM_ID env var is missing");
  }

  const header = toBase64Url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const payload = toBase64Url(JSON.stringify({ iss: teamId, iat: now }));
  const signingInput = `${header}.${payload}`;

  const cryptoKey = await importApnsKey();
  const encoder = new TextEncoder();
  const signatureBuffer = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    encoder.encode(signingInput),
  );

  const sigB64 = toBase64UrlFromBuffer(new Uint8Array(signatureBuffer));

  cachedJwt = `${signingInput}.${sigB64}`;
  jwtIssuedAt = now;
  return cachedJwt;
}

/** Imports the p8 PEM key stored in APNS_KEY as a CryptoKey (cached for the isolate lifetime). */
async function importApnsKey(): Promise<CryptoKey> {
  if (cachedCryptoKey) return cachedCryptoKey;

  const rawPem = Deno.env.get("APNS_KEY");
  if (!rawPem) throw new Error("APNS_KEY env var is missing");

  // The secret is stored with literal \n — convert to real newlines.
  const pemKey = rawPem.replace(/\\n/g, "\n");
  const pemBody = pemKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  cachedCryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  return cachedCryptoKey;
}

// ── Base64url helpers ─────────────────────────────────────────────────────────

function toBase64Url(str: string): string {
  return btoa(str)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function toBase64UrlFromBuffer(buf: Uint8Array): string {
  return btoa(String.fromCharCode(...buf))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

// ── Supabase client (service role — bypasses RLS) ─────────────────────────────

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ── Caller-auth helper ───────────────────────────────────────────────────────
//
// Defense in depth alongside `verify_jwt = true` in `supabase/config.toml`,
// which makes the Supabase gateway reject any unauthenticated call before
// the function even runs. Once inside, we still need to decide what the
// caller is allowed to do:
//   - service_role (cron + `notify_friend_request` trigger) → may push to any user
//   - authenticated user (regular session JWT)              → may push only to themselves
//   - anon                                                  → reject
//
// The gateway has already validated the signature, so a no-verify decode of
// the claims is sufficient for this check.

function decodeJwtClaims(authHeader: string | null): Record<string, unknown> | null {
  if (!authHeader || !authHeader.toLowerCase().startsWith("bearer ")) return null;
  const token = authHeader.slice(7);
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload + "=".repeat((4 - (payload.length % 4)) % 4);
    return JSON.parse(atob(padded)) as Record<string, unknown>;
  } catch {
    return null;
  }
}

// ── Main handler ──────────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Parse request body.
  let userId: string;
  let title: string;
  let body: string;
  let data: Record<string, unknown> | undefined;

  try {
    const json = await req.json();
    userId = json.userId;
    title = json.title;
    body = json.body;
    data = json.data;

    if (!userId || !title || !body) {
      return new Response(
        JSON.stringify({ error: "userId, title, and body are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Caller-auth check. Cron jobs and the friend-request trigger send a
  // service-role bearer (any userId allowed). Regular users may only push
  // to themselves. Without this, anyone authenticated could spam pushes to
  // any user UUID.
  const claims = decodeJwtClaims(req.headers.get("authorization") ?? req.headers.get("Authorization"));
  const callerRole = typeof claims?.role === "string" ? (claims.role as string) : null;
  const callerSub = typeof claims?.sub === "string" ? (claims.sub as string) : null;
  const isServiceRole = callerRole === "service_role";
  const isOwnUser = callerRole === "authenticated" && callerSub === userId;

  if (!isServiceRole && !isOwnUser) {
    console.warn(`[send-push] forbidden caller role=${callerRole ?? "null"} sub=${callerSub?.slice(0, 8) ?? "null"} target=${userId.slice(0, 8)}`);
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Sanity caps so a malformed caller can't trigger an APNs reject for size.
  if (title.length > 120 || body.length > 400) {
    return new Response(JSON.stringify({ error: "title/body too long" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Look up APNs token for the user.
  const { data: tokenRow, error: dbError } = await supabase
    .from("push_tokens")
    .select("token")
    .eq("user_id", userId)
    .single();

  if (dbError || !tokenRow) {
    // User has no registered token — not an error, just skip.
    console.log(`[send-push] No push token for user ${userId}; skipping.`);
    return new Response(JSON.stringify({ status: "no_token" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const deviceToken: string = tokenRow.token;

  // Build the APNs payload. Custom data is spread FIRST and `aps` last, so a
  // caller-supplied `data.aps` (or non-object data) can never override the
  // server-built notification envelope.
  const customData =
    data && typeof data === "object" && !Array.isArray(data) ? data : {};
  const apnsPayload = {
    ...customData,
    aps: {
      alert: { title, body },
      sound: "default",
      badge: 1, // TODO: reflect actual unread count per user
    },
  };

  // Sign and send.
  let jwt: string;
  try {
    jwt = await getApnsJwt();
  } catch (err) {
    console.error("[send-push] Failed to sign APNs JWT:", err);
    // Return 200 — push failure should not block the caller.
    return new Response(JSON.stringify({ status: "jwt_error" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const apnsUrl = `${APNS_HOST}/3/device/${deviceToken}`;

  let apnsResponse: Response;
  try {
    apnsResponse = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": BUNDLE_ID,
        "apns-push-type": "alert",
        "content-type": "application/json",
      },
      body: JSON.stringify(apnsPayload),
    });
  } catch (err) {
    console.error("[send-push] Network error sending to APNs:", err);
    return new Response(JSON.stringify({ status: "network_error" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (apnsResponse.status === 200) {
    console.log(`[send-push] Delivered to ${deviceToken.slice(0, 8)}…`);
    return new Response(JSON.stringify({ status: "ok" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 410 = Unregistered / BadDeviceToken — prune the stale token.
  if (apnsResponse.status === 410) {
    console.warn(
      `[send-push] APNs returned 410 for token ${deviceToken.slice(0, 8)}… — deleting stale row.`,
    );
    const { error: deleteError } = await supabase
      .from("push_tokens")
      .delete()
      .eq("user_id", userId)
      .eq("token", deviceToken);

    if (deleteError) {
      console.error("[send-push] Failed to delete stale token:", deleteError);
    }
    return new Response(JSON.stringify({ status: "token_expired" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Any other non-200 status — log and return 200 (non-fatal).
  const responseBody = await apnsResponse.text();
  console.error(
    `[send-push] APNs returned ${apnsResponse.status}: ${responseBody}`,
  );
  return new Response(
    JSON.stringify({ status: "apns_error", code: apnsResponse.status }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
