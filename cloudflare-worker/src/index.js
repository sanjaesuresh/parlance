// Required env: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//               APPLE_TEAM_ID, APPLE_BUNDLE_ID, APPLE_KEY_ID, APPLE_P8_PRIVATE_KEY,
//               GEMINI_API_KEY, HUME_API_KEY, OPENAI_API_KEY (moderation)

import { generateRealLifePromptAndTips } from "./realLifeTips.js";
import { generateWeeklyBrief, validateRequest as validateBriefRequest } from "./weeklyBrief.js";

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": "null",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = new URL(request.url);

    if (url.pathname === "/feedback") {
      return handleFeedback(request, env, corsHeaders);
    }

    if (url.pathname === "/real-life/tips") {
      return handleRealLifeTips(request, env, corsHeaders);
    }

    if (url.pathname === "/emotion") {
      return handleEmotion(request, env, corsHeaders);
    }

    if (url.pathname === "/emotion/submit") {
      return handleEmotionSubmit(request, env, corsHeaders);
    }

    if (url.pathname === "/emotion/status") {
      return handleEmotionStatus(request, env, corsHeaders);
    }

    if (url.pathname === "/delete-user") {
      return handleDeleteUser(request, env, corsHeaders);
    }

    if (url.pathname === "/coach/weekly-brief") {
      return handleWeeklyBrief(request, env, corsHeaders);
    }

    return new Response(JSON.stringify({ error: "Not found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  },
};

/**
 * Calls OpenAI's moderation endpoint. Returns:
 *   { flagged: true, categories: [...] }   when content is unsafe,
 *   { flagged: false }                     when content is clean,
 *   { flagged: false, error: '...' }       fail-open on upstream failure.
 *
 * The API is free; we treat any error as "not flagged" to avoid creating a
 * new outage vector on top of the Gemini call. Errors are surfaced via the
 * returned object so callers can log them.
 */
export async function moderateTranscript(transcript, apiKey, fetchImpl = fetch) {
  if (!transcript || transcript.trim().length === 0) return { flagged: false };
  if (!apiKey) return { flagged: false, error: "missing_api_key" };
  try {
    const res = await fetchImpl("https://api.openai.com/v1/moderations", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        input: transcript,
        model: "omni-moderation-latest",
      }),
    });
    if (!res.ok) return { flagged: false, error: `upstream_${res.status}` };
    const body = await res.json();
    const first = body?.results?.[0];
    if (!first) return { flagged: false, error: "malformed_response" };
    if (first.flagged) {
      const cats = Object.entries(first.categories ?? {})
        .filter(([, v]) => v)
        .map(([k]) => k);
      return { flagged: true, categories: cats };
    }
    return { flagged: false };
  } catch (err) {
    return { flagged: false, error: `exception_${err?.message ?? "unknown"}` };
  }
}

// ---------------------------------------------------------------------------
// Auth helper — verifies Supabase JWT and returns { uid } or { error: Response }
// Required env vars: SUPABASE_URL, SUPABASE_ANON_KEY
// ---------------------------------------------------------------------------

async function requireUser(request, env, corsHeaders) {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return {
      error: new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }),
    };
  }

  const userJWT = authHeader.slice(7);
  const userRes = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${userJWT}`,
      apikey: env.SUPABASE_ANON_KEY,
    },
  });

  if (!userRes.ok) {
    return {
      error: new Response(JSON.stringify({ error: "Invalid or expired token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }),
    };
  }

  const { id: uid } = await userRes.json();
  return { uid };
}

// ---------------------------------------------------------------------------
// Rate-limit helper — KV-backed per-user per-route per-minute bucket.
// Eventual consistency is acceptable; the small race window is fine for
// cost-protection. Uses binding: RATE_LIMIT (KV namespace).
// ---------------------------------------------------------------------------

async function checkRateLimit(env, uid, route, perMinute, corsHeaders) {
  const bucket = `rl:${uid}:${route}:${Math.floor(Date.now() / 60000)}`;
  const current = parseInt((await env.RATE_LIMIT.get(bucket)) ?? "0", 10);

  if (current >= perMinute) {
    return {
      error: new Response(JSON.stringify({ error: "Too many requests" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }),
    };
  }

  // Increment; TTL of 120s ensures the key expires after the minute window
  // (with a generous buffer for clock skew).
  await env.RATE_LIMIT.put(bucket, String(current + 1), { expirationTtl: 120 });
  return { ok: true };
}

/**
 * Per-day variant for surfaces that should run at most N times in a 24h
 * window (the weekly coach brief allows one Monday-auto + one manual
 * refresh = 2/day). Same KV binding, distinct key namespace.
 */
async function checkDailyRateLimit(env, uid, route, perDay, corsHeaders) {
  const bucket = `rld:${uid}:${route}:${Math.floor(Date.now() / 86400000)}`;
  const current = parseInt((await env.RATE_LIMIT.get(bucket)) ?? "0", 10);

  if (current >= perDay) {
    return {
      error: new Response(JSON.stringify({ error: "Daily limit reached" }), {
        status: 429,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }),
    };
  }

  // TTL slightly over 24h to absorb clock skew without blocking the next window.
  await env.RATE_LIMIT.put(bucket, String(current + 1), { expirationTtl: 90000 });
  return { ok: true };
}

// ---------------------------------------------------------------------------
// /delete-user — orchestrated account deletion:
//   1. Verify JWT
//   2. Look up user identities; attempt Apple token revoke if applicable
//   3. Delete per-table rows (service-role, sequential, best-effort)
//   4. Delete auth user record
// Required env vars: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//                    APPLE_TEAM_ID, APPLE_BUNDLE_ID, APPLE_KEY_ID, APPLE_P8_PRIVATE_KEY
// ---------------------------------------------------------------------------

async function handleDeleteUser(request, env, corsHeaders) {
  // Step 1 — verify JWT
  const authResult = await requireUser(request, env, corsHeaders);
  if (authResult.error) return authResult.error;
  const { uid } = authResult;

  const adminHeaders = {
    apikey: env.SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
  };

  // Step 2 — look up user identities via admin API
  let appleRevoked = false;
  try {
    const userRes = await fetch(`${env.SUPABASE_URL}/auth/v1/admin/users/${uid}`, {
      headers: adminHeaders,
    });
    if (userRes.ok) {
      const userData = await userRes.json();
      const identities = userData.identities ?? [];
      const appleIdentity = identities.find((i) => i.provider === "apple");

      if (appleIdentity) {
        // Try to find a refresh token. Supabase may expose it in identity_data or
        // raw_user_meta_data.provider_refresh_token.
        // NOTE: Supabase does not currently persist Apple refresh tokens server-side
        // via the standard Sign in with Apple flow. This path will typically log a
        // warning and skip the revoke step (graceful degradation). To enable revoke,
        // the iOS app would need to capture and store the Apple refresh token at
        // sign-in time — that is out of scope for this task.
        const refreshToken =
          appleIdentity.identity_data?.refresh_token ??
          userData.raw_user_meta_data?.provider_refresh_token ??
          null;

        if (refreshToken) {
          try {
            const clientSecret = await signAppleClientSecret(env);
            const revokeBody = new URLSearchParams({
              client_id: env.APPLE_BUNDLE_ID,
              client_secret: clientSecret,
              token: refreshToken,
              token_type_hint: "refresh_token",
            });
            const revokeRes = await fetch("https://appleid.apple.com/auth/revoke", {
              method: "POST",
              headers: { "Content-Type": "application/x-www-form-urlencoded" },
              body: revokeBody.toString(),
            });
            if (revokeRes.ok) {
              appleRevoked = true;
            } else {
              const revokeText = await revokeRes.text();
              console.warn(`[delete-user] Apple revoke returned ${revokeRes.status}: ${revokeText}`);
            }
          } catch (revokeErr) {
            console.warn(`[delete-user] Apple revoke failed: ${revokeErr}`);
          }
        } else {
          console.warn(
            `[delete-user] Apple identity found for uid=${uid} but no refresh token available; skipping revoke`
          );
        }
      }
    } else {
      console.warn(`[delete-user] Could not fetch user identities for uid=${uid}: ${userRes.status}`);
    }
  } catch (identityErr) {
    console.warn(`[delete-user] Identity lookup error: ${identityErr}`);
  }

  // Step 3 — delete per-table rows (sequential, best-effort)
  const restHeaders = {
    ...adminHeaders,
    Prefer: "return=minimal",
  };

  const tableDeletes = [
    `push_tokens?user_id=eq.${uid}`,
    `blocked_users?blocker_id=eq.${uid}`,
    `blocked_users?blocked_id=eq.${uid}`,
    `user_reports?reporter_id=eq.${uid}`,
    `friend_requests?from_user_id=eq.${uid}`,
    `friend_requests?to_user_id=eq.${uid}`,
    `friendships?user_id_1=eq.${uid}`,
    `friendships?user_id_2=eq.${uid}`,
    `session_scores?user_id=eq.${uid}`,
    `user_stats?user_id=eq.${uid}`,
    `profiles?id=eq.${uid}`,
  ];

  for (const path of tableDeletes) {
    try {
      const res = await fetch(`${env.SUPABASE_URL}/rest/v1/${path}`, {
        method: "DELETE",
        headers: restHeaders,
      });
      if (!res.ok) {
        const body = await res.text();
        console.warn(`[delete-user] DELETE ${path} returned ${res.status}: ${body}`);
      }
    } catch (err) {
      console.warn(`[delete-user] DELETE ${path} threw: ${err}`);
    }
  }

  // Step 4 — delete the auth user record
  const deleteAuthRes = await fetch(`${env.SUPABASE_URL}/auth/v1/admin/users/${uid}`, {
    method: "DELETE",
    headers: adminHeaders,
  });

  if (!deleteAuthRes.ok) {
    const details = await deleteAuthRes.text();
    return new Response(JSON.stringify({ error: "Failed to delete auth user", details }), {
      status: 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ success: true, appleRevoked }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// signAppleClientSecret — generate a Sign in with Apple client_secret JWT.
// Signs with the team's P8 private key (ES256) using WebCrypto.
// Note: WebCrypto's ECDSA sign already returns raw r||s (not DER), so no
// conversion is needed before base64url-encoding.
// ---------------------------------------------------------------------------

async function signAppleClientSecret(env) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: env.APPLE_KEY_ID, typ: "JWT" };
  const payload = {
    iss: env.APPLE_TEAM_ID,
    iat: now,
    exp: now + 60 * 60 * 24 * 180, // 180 days max
    aud: "https://appleid.apple.com",
    sub: env.APPLE_BUNDLE_ID,
  };

  const b64u = (obj) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const signingInput = `${b64u(header)}.${b64u(payload)}`;

  // Strip PEM headers/footers and whitespace to get raw base64
  const pem = env.APPLE_P8_PRIVATE_KEY.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const sigBytes = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sigBytes)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${signingInput}.${sigB64}`;
}

// ---------------------------------------------------------------------------
// /feedback — proxy to Gemini (Claude-compatible messages format)
// ---------------------------------------------------------------------------

async function handleFeedback(request, env, corsHeaders) {
  // 1. Auth
  const authResult = await requireUser(request, env, corsHeaders);
  if (authResult.error) return authResult.error;
  const { uid } = authResult;

  // 2. Body size cap — 50 KB
  const contentLength = parseInt(request.headers.get("content-length") ?? "0", 10);
  if (contentLength > 51200) {
    return new Response(JSON.stringify({ error: "Request too large" }), {
      status: 413,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 3. Rate limit — 20 requests per minute per user
  const rlResult = await checkRateLimit(env, uid, "feedback", 20, corsHeaders);
  if (rlResult.error) return rlResult.error;

  let body;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 4. Server-side moderation on the user-spoken transcript.
  // Fail-open: a moderation outage must not break scoring.
  const transcript = typeof body.transcript === "string" ? body.transcript : "";
  if (transcript.length > 0) {
    const mod = await moderateTranscript(transcript, env.OPENAI_API_KEY);
    if (mod.flagged) {
      console.log(
        `[feedback] uid=${uid.slice(0, 8)} moderation_flagged categories=${(mod.categories ?? []).join(",")}`
      );
      return new Response(
        JSON.stringify({ refused: true, reason: "inappropriate_content" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (mod.error) {
      console.log(`[feedback] moderation_error=${mod.error}`);
    }
  }

  try {
    const messages = body.messages;
    const temperature = typeof body.temperature === "number" ? body.temperature : 0.3;

    if (!messages || !Array.isArray(messages)) {
      return new Response(JSON.stringify({ error: "Invalid request body" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Concatenate all message content into a single prompt for Gemini
    const prompt = messages.map((m) => m.content).join("\n");
    const model = env.GEMINI_MODEL || "gemini-3-flash-preview";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

    const geminiResponse = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature, maxOutputTokens: 2048 },
      }),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      return new Response(JSON.stringify({ error: "Upstream API error", details: errorText }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const result = await geminiResponse.json();
    const feedback = result.candidates?.[0]?.content?.parts?.[0]?.text || "";

    return new Response(JSON.stringify({ feedback }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

// ---------------------------------------------------------------------------
// /real-life/tips — Generate 3 coaching tips for a user-supplied scenario.
//
// The user's scenario is UNTRUSTED FREE TEXT. It is always wrapped in
// <user_scenario> tags inside the user-role message; the system prompt
// instructs the model to ignore any directives inside the tags. Output is
// always JSON validated against a fixed shape — anything else is treated
// as a refusal.
// ---------------------------------------------------------------------------

async function handleRealLifeTips(request, env, corsHeaders) {
  // 1. Auth
  const authResult = await requireUser(request, env, corsHeaders);
  if (authResult.error) return authResult.error;
  const { uid } = authResult;

  // 2. Body size cap — 4 KB is plenty for a 500-char scenario + metadata
  const contentLength = parseInt(request.headers.get("content-length") ?? "0", 10);
  if (contentLength > 4096) {
    return new Response(JSON.stringify({ error: "Request too large" }), {
      status: 413,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 3. Rate limit — 10 requests per minute per user (cheaper than /feedback)
  const rlResult = await checkRateLimit(env, uid, "real-life-tips", 10, corsHeaders);
  if (rlResult.error) return rlResult.error;

  let body;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const scenario = typeof body.scenario === "string" ? body.scenario : "";
  const level = Number.isInteger(body.level) ? body.level : 5;
  const durationSeconds = Number.isInteger(body.durationSeconds) ? body.durationSeconds : 60;

  // Enforce input invariants server-side (defense in depth)
  if (scenario.length === 0 || scenario.length > 500) {
    return new Response(JSON.stringify({ error: "Invalid scenario length" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  if (level < 1 || level > 10) {
    return new Response(JSON.stringify({ error: "Invalid level" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  if (durationSeconds < 15 || durationSeconds > 180) {
    return new Response(JSON.stringify({ error: "Invalid duration" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const result = await generateRealLifePromptAndTips({
      scenario,
      level,
      durationSeconds,
      geminiApiKey: env.GEMINI_API_KEY,
      model: env.GEMINI_MODEL || "gemini-3-flash-preview",
    });

    if (result.ok) {
      return new Response(
        JSON.stringify({ rewrittenPrompt: result.rewrittenPrompt, tips: result.tips }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (result.refused) {
      return new Response(
        JSON.stringify({ refused: true, reason: result.reason }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ error: "Upstream API error", details: result.error }),
      { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

// ---------------------------------------------------------------------------
// /emotion — proxy to Hume AI batch API
// ---------------------------------------------------------------------------

async function handleEmotion(request, env, corsHeaders) {
  if (!env.HUME_API_KEY) {
    return new Response(JSON.stringify({ error: "HUME_API_KEY not configured" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 1. Auth
  const authResult = await requireUser(request, env, corsHeaders);
  if (authResult.error) return authResult.error;
  const { uid } = authResult;

  // 2. Body size cap — 30 MB
  const contentLength = parseInt(request.headers.get("content-length") ?? "0", 10);
  if (contentLength > 31457280) {
    return new Response(JSON.stringify({ error: "Request too large" }), {
      status: 413,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 3. Rate limit — 10 requests per minute per user
  const rlResult = await checkRateLimit(env, uid, "emotion", 10, corsHeaders);
  if (rlResult.error) return rlResult.error;

  try {
    const audioBytes = await request.arrayBuffer();

    // Step 1: Submit batch job to Hume
    const formData = new FormData();
    formData.append(
      "json",
      JSON.stringify({ models: { prosody: {} } }),
      { type: "application/json", filename: "config.json" }
    );
    formData.append(
      "file",
      new Blob([audioBytes], { type: "audio/mp4" }),
      "recording.m4a"
    );

    const submitRes = await fetch("https://api.hume.ai/v0/batch/jobs", {
      method: "POST",
      headers: { "X-Hume-Api-Key": env.HUME_API_KEY },
      body: formData,
    });

    if (!submitRes.ok) {
      const text = await submitRes.text();
      return new Response(JSON.stringify({ error: "Hume submission failed", details: text }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { job_id } = await submitRes.json();

    // Step 2: Poll for completion — up to 8 retries × 2s = 16s max
    // Cloudflare Workers have a 30s wall-clock limit; 16s leaves headroom for submit + predict fetches.
    for (let i = 0; i < 8; i++) {
      await new Promise((r) => setTimeout(r, 2000));

      const statusRes = await fetch(`https://api.hume.ai/v0/batch/jobs/${job_id}`, {
        headers: { "X-Hume-Api-Key": env.HUME_API_KEY },
      });
      const statusBody = await statusRes.json();
      const status = statusBody?.state?.status;

      if (status === "COMPLETED") {
        const predRes = await fetch(
          `https://api.hume.ai/v0/batch/jobs/${job_id}/predictions`,
          { headers: { "X-Hume-Api-Key": env.HUME_API_KEY } }
        );
        const predictions = await predRes.json();
        const summary = summarizeEmotions(predictions);
        return new Response(JSON.stringify(summary), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if (status === "FAILED") {
        return new Response(JSON.stringify({ error: "Hume job failed" }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    return new Response(JSON.stringify({ error: "Emotion analysis timed out" }), {
      status: 504,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

// ---------------------------------------------------------------------------
// /emotion/submit — upload audio to Hume, return { job_id } immediately
// Client then polls /emotion/status?job_id=… until completed.
// Decouples Hume's variable latency from Cloudflare's 30s wall-clock ceiling.
// ---------------------------------------------------------------------------

async function handleEmotionSubmit(request, env, corsHeaders) {
  if (!env.HUME_API_KEY) {
    return new Response(JSON.stringify({ error: "HUME_API_KEY not configured" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const authResult = await requireUser(request, env, corsHeaders);
  if (authResult.error) return authResult.error;
  const { uid } = authResult;

  const contentLength = parseInt(request.headers.get("content-length") ?? "0", 10);
  if (contentLength > 31457280) {
    return new Response(JSON.stringify({ error: "Request too large" }), {
      status: 413,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const rlResult = await checkRateLimit(env, uid, "emotion", 10, corsHeaders);
  if (rlResult.error) return rlResult.error;

  try {
    const audioBytes = await request.arrayBuffer();

    const formData = new FormData();
    formData.append(
      "json",
      JSON.stringify({ models: { prosody: {} } }),
      { type: "application/json", filename: "config.json" }
    );
    formData.append(
      "file",
      new Blob([audioBytes], { type: "audio/mp4" }),
      "recording.m4a"
    );

    const submitRes = await fetch("https://api.hume.ai/v0/batch/jobs", {
      method: "POST",
      headers: { "X-Hume-Api-Key": env.HUME_API_KEY },
      body: formData,
    });

    if (!submitRes.ok) {
      const text = await submitRes.text();
      return new Response(JSON.stringify({ error: "Hume submission failed", details: text }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { job_id } = await submitRes.json();

    // Bind job_id to uid so /emotion/status can verify ownership. 10-min TTL
    // matches the worst-case end-to-end wait + a safety buffer.
    await env.RATE_LIMIT.put(`emotion_job:${job_id}`, uid, { expirationTtl: 600 });

    return new Response(JSON.stringify({ job_id }), {
      status: 202,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

// ---------------------------------------------------------------------------
// /emotion/status — check Hume job state; return result when COMPLETED.
// Body: { job_id }. Responses: 200 {status:"pending"|"completed", result?},
// 404 if job unknown/expired, 403 if not owner, 502 if Hume job failed.
// ---------------------------------------------------------------------------

async function handleEmotionStatus(request, env, corsHeaders) {
  if (!env.HUME_API_KEY) {
    return new Response(JSON.stringify({ error: "HUME_API_KEY not configured" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const authResult = await requireUser(request, env, corsHeaders);
  if (authResult.error) return authResult.error;
  const { uid } = authResult;

  let body;
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const jobId = body?.job_id;
  if (typeof jobId !== "string" || jobId.length === 0 || jobId.length > 128) {
    return new Response(JSON.stringify({ error: "Missing or invalid job_id" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Cheap rate-limit on polling — clients backoff but this guards abuse.
  const rlResult = await checkRateLimit(env, uid, "emotion-status", 120, corsHeaders);
  if (rlResult.error) return rlResult.error;

  const ownerUid = await env.RATE_LIMIT.get(`emotion_job:${jobId}`);
  if (!ownerUid) {
    return new Response(JSON.stringify({ error: "Job not found or expired" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  if (ownerUid !== uid) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const statusRes = await fetch(`https://api.hume.ai/v0/batch/jobs/${jobId}`, {
      headers: { "X-Hume-Api-Key": env.HUME_API_KEY },
    });
    const statusBody = await statusRes.json();
    const status = statusBody?.state?.status;

    if (status === "COMPLETED") {
      const predRes = await fetch(
        `https://api.hume.ai/v0/batch/jobs/${jobId}/predictions`,
        { headers: { "X-Hume-Api-Key": env.HUME_API_KEY } }
      );
      const predictions = await predRes.json();
      const summary = summarizeEmotions(predictions);
      return new Response(JSON.stringify({ status: "completed", result: summary }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (status === "FAILED") {
      return new Response(JSON.stringify({ error: "Hume job failed" }), {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ status: "pending" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

// ---------------------------------------------------------------------------
// Parse Hume predictions into EmotionResult shape
// ---------------------------------------------------------------------------

export function summarizeEmotions(predictions) {
  // Hume response path: [0].results.predictions[0].models.prosody.grouped_predictions[0].predictions
  const segments =
    predictions?.[0]?.results?.predictions?.[0]?.models?.prosody
      ?.grouped_predictions?.[0]?.predictions ?? [];

  if (segments.length === 0) {
    return {
      dominantEmotion: "Neutral",
      dominantScore: 0.5,
      confidenceScore: 0.5,
      nervousnessScore: 0.3,
      enthusiasmScore: 0.3,
      emotionArc: [],
      topEmotions: [],
      emotionTimelines: {},
    };
  }

  // Accumulate scores per emotion label across all segments
  const totals = {};
  for (const segment of segments) {
    for (const e of segment.emotions ?? []) {
      totals[e.name] = (totals[e.name] ?? 0) + e.score;
    }
  }

  // Average across segments
  const n = segments.length;
  const averaged = Object.fromEntries(
    Object.entries(totals).map(([k, v]) => [k, v / n])
  );

  // Find dominant emotion
  const [dominantEmotion, dominantScore] = Object.entries(averaged).sort(
    (a, b) => b[1] - a[1]
  )[0];

  // Top 10 emotions by averaged score
  const topEmotions = Object.entries(averaged)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([name, score]) => ({ name, score }));

  // Per-segment arc for each top emotion (so the client can show when each rose/fell)
  const emotionTimelines = {};
  for (const { name } of topEmotions) {
    emotionTimelines[name] = segments.map(
      (s) => (s.emotions ?? []).find((e) => e.name === name)?.score ?? 0
    );
  }

  // Confidence arc kept for backwards compat with the card's sparkline
  const emotionArc =
    emotionTimelines["Confidence"] ??
    segments.map(
      (s) => (s.emotions ?? []).find((e) => e.name === "Confidence")?.score ?? 0
    );

  return {
    dominantEmotion,
    dominantScore,
    confidenceScore: averaged["Confidence"] ?? 0,
    nervousnessScore: averaged["Nervousness"] ?? 0,
    enthusiasmScore: averaged["Excitement"] ?? 0,
    emotionArc,
    topEmotions,
    emotionTimelines,
  };
}


// ---------------------------------------------------------------------------
// /coach/weekly-brief — generates the Progress-tab weekly coach note.
// Pre-aggregated payload from the client; we do not touch raw sessions here.
// ---------------------------------------------------------------------------

async function handleWeeklyBrief(request, env, corsHeaders) {
  // Auth
  const authResult = await requireUser(request, env, corsHeaders);
  if (authResult.error) return authResult.error;
  const { uid } = authResult;

  // Rate limit: 5/day per user — covers retry slack and edge cases (cold launch,
  // sign-out/in, multi-device). When hit, the client treats 429 as a silent
  // no-op and keeps showing the previously cached brief.
  const rate = await checkDailyRateLimit(env, uid, "coach-weekly-brief", 5, corsHeaders);
  if (rate.error) return rate.error;

  // Payload
  let payload;
  try {
    payload = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Schema check (lets us bail out before calling Gemini for under-2 sessions etc.)
  const validation = validateBriefRequest(payload);
  if (!validation.ok) {
    const status = validation.error === "insufficient_data" ? 400 : 400;
    return new Response(JSON.stringify({ error: validation.error }), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Generate (with internal fallback on every model/safety failure)
  let result;
  try {
    result = await generateWeeklyBrief({
      payload,
      geminiApiKey: env.GEMINI_API_KEY,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: `internal:${err?.message ?? "unknown"}` }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Telemetry: log only the reason code, never the brief content
  if (result.errorContext) {
    console.log("[weekly-brief] uid=" + uid.slice(0, 8) + " source=" + result.source + " ctx=" + result.errorContext);
  }

  return new Response(JSON.stringify({
    brief: result.brief,
    highlights: result.highlights,
    generatedAt: result.generatedAt,
    model: result.model,
    source: result.source,
  }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
