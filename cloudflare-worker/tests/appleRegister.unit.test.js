import { describe, test, expect, beforeEach, afterEach, vi } from "vitest";
import worker from "../src/index.js";

// A throwaway P-256 PEM generated for tests only. Never used outside this file.
const TEST_P8_PEM = `-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg/ssodpln7AsiRdIrfz01sJ03yIyPanOw3ZkiA7Tj6EqhRANCAAT45smVcTPnvaAaSjK/DYGLv1PkkHmKC0JTLvCaFdsjnWRUvOOO4lDVyr94uD6tu+UVbUXA072+6PZnoLeqClmc
-----END PRIVATE KEY-----`;

const TEST_UID = "11111111-1111-4111-8111-111111111111";

function makeEnv(overrides = {}) {
  const kvStore = new Map();
  return {
    SUPABASE_URL: "https://example.supabase.co",
    SUPABASE_ANON_KEY: "anon-key",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-key",
    APPLE_TEAM_ID: "TEAMID0000",
    APPLE_BUNDLE_ID: "com.example.app",
    APPLE_KEY_ID: "KEYID00000",
    APPLE_P8_PRIVATE_KEY: TEST_P8_PEM,
    RATE_LIMIT: {
      get: async (k) => kvStore.get(k) ?? null,
      put: async (k, v) => {
        kvStore.set(k, v);
      },
    },
    ...overrides,
  };
}

function makeRequest({ body = { authorization_code: "abc.def.ghi" }, auth = "Bearer good-jwt" } = {}) {
  const bodyStr = JSON.stringify(body);
  const headers = {
    "Content-Type": "application/json",
    "content-length": String(new TextEncoder().encode(bodyStr).length),
  };
  if (auth) headers["Authorization"] = auth;
  return new Request("https://worker.test/apple/register", {
    method: "POST",
    headers,
    body: bodyStr,
  });
}

describe("/apple/register", () => {
  let originalFetch;
  beforeEach(() => {
    originalFetch = globalThis.fetch;
  });
  afterEach(() => {
    globalThis.fetch = originalFetch;
    vi.restoreAllMocks();
  });

  test("happy path: exchanges code, upserts refresh token, returns success", async () => {
    const calls = [];
    globalThis.fetch = async (url, init) => {
      const u = typeof url === "string" ? url : url.url;
      calls.push({ url: u, init });

      // Supabase auth verify (used by requireUser)
      if (u.endsWith("/auth/v1/user")) {
        return new Response(JSON.stringify({ id: TEST_UID }), { status: 200 });
      }

      // Apple token endpoint
      if (u === "https://appleid.apple.com/auth/token") {
        return new Response(
          JSON.stringify({ refresh_token: "rt-secret-do-not-log", access_token: "at" }),
          { status: 200 }
        );
      }

      // Supabase upsert
      if (u.endsWith("/rest/v1/apple_refresh_tokens")) {
        return new Response("", { status: 201 });
      }

      throw new Error(`unexpected fetch: ${u}`);
    };

    const res = await worker.fetch(makeRequest(), makeEnv());
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toEqual({ success: true });

    // Apple call carried form-encoded grant + bundle id + code, never logged token
    const apple = calls.find((c) => c.url === "https://appleid.apple.com/auth/token");
    expect(apple).toBeDefined();
    expect(apple.init.headers["Content-Type"]).toBe("application/x-www-form-urlencoded");
    const params = new URLSearchParams(apple.init.body);
    expect(params.get("grant_type")).toBe("authorization_code");
    expect(params.get("code")).toBe("abc.def.ghi");
    expect(params.get("client_id")).toBe("com.example.app");
    expect(params.get("client_secret")).toMatch(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);

    // Upsert sent user_id + refresh_token with merge-duplicates prefer header
    const upsert = calls.find((c) => c.url.endsWith("/rest/v1/apple_refresh_tokens"));
    expect(upsert).toBeDefined();
    expect(upsert.init.method).toBe("POST");
    expect(upsert.init.headers.Prefer).toContain("resolution=merge-duplicates");
    expect(upsert.init.headers.apikey).toBe("service-role-key");
    const upsertBody = JSON.parse(upsert.init.body);
    expect(upsertBody).toEqual([{ user_id: TEST_UID, refresh_token: "rt-secret-do-not-log" }]);
  });

  test("missing Authorization header returns 401", async () => {
    globalThis.fetch = async () => {
      throw new Error("requireUser should bail before any fetch");
    };
    const res = await worker.fetch(makeRequest({ auth: null }), makeEnv());
    expect(res.status).toBe(401);
    const body = await res.json();
    expect(body.error).toBe("Unauthorized");
  });

  test("invalid Supabase JWT returns 401", async () => {
    globalThis.fetch = async (url) => {
      const u = typeof url === "string" ? url : url.url;
      if (u.endsWith("/auth/v1/user")) {
        return new Response(JSON.stringify({ msg: "bad jwt" }), { status: 401 });
      }
      throw new Error(`unexpected fetch: ${u}`);
    };
    const res = await worker.fetch(makeRequest(), makeEnv());
    expect(res.status).toBe(401);
    const body = await res.json();
    expect(body.error).toMatch(/Invalid or expired token/);
  });

  test("missing authorization_code returns 400", async () => {
    globalThis.fetch = async (url) => {
      const u = typeof url === "string" ? url : url.url;
      if (u.endsWith("/auth/v1/user")) {
        return new Response(JSON.stringify({ id: TEST_UID }), { status: 200 });
      }
      throw new Error(`unexpected fetch: ${u}`);
    };
    const res = await worker.fetch(makeRequest({ body: {} }), makeEnv());
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error).toMatch(/authorization_code/);
  });

  test("Apple non-OK response returns 502 with generic error (does not leak Apple body)", async () => {
    globalThis.fetch = async (url) => {
      const u = typeof url === "string" ? url : url.url;
      if (u.endsWith("/auth/v1/user")) {
        return new Response(JSON.stringify({ id: TEST_UID }), { status: 200 });
      }
      if (u === "https://appleid.apple.com/auth/token") {
        return new Response("invalid_grant: specific apple detail", { status: 400 });
      }
      throw new Error(`unexpected fetch: ${u}`);
    };
    const res = await worker.fetch(makeRequest(), makeEnv());
    expect(res.status).toBe(502);
    const body = await res.json();
    expect(body).toEqual({ error: "apple_token_exchange_failed" });
    // Sanity: Apple's specific error text must not appear in our response
    expect(JSON.stringify(body)).not.toContain("specific apple detail");
  });

  test("Apple OK but missing refresh_token returns 502", async () => {
    globalThis.fetch = async (url) => {
      const u = typeof url === "string" ? url : url.url;
      if (u.endsWith("/auth/v1/user")) {
        return new Response(JSON.stringify({ id: TEST_UID }), { status: 200 });
      }
      if (u === "https://appleid.apple.com/auth/token") {
        return new Response(JSON.stringify({ access_token: "at-only" }), { status: 200 });
      }
      throw new Error(`unexpected fetch: ${u}`);
    };
    const res = await worker.fetch(makeRequest(), makeEnv());
    expect(res.status).toBe(502);
    const body = await res.json();
    expect(body).toEqual({ error: "no_refresh_token_in_response" });
  });
});
