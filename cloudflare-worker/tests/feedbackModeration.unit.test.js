import { describe, test, expect } from "vitest";
import { moderateTranscript } from "../src/index.js";

describe("moderateTranscript", () => {
  test("returns flagged:false for empty input", async () => {
    const result = await moderateTranscript("", "sk-test");
    expect(result).toEqual({ flagged: false });
  });

  test("returns flagged:false when API key missing", async () => {
    const result = await moderateTranscript("hello", "");
    expect(result.flagged).toBe(false);
    expect(result.error).toBe("missing_api_key");
  });

  test("flags content the API marks as flagged", async () => {
    const stubFetch = async () => ({
      ok: true,
      json: async () => ({
        results: [
          { flagged: true, categories: { hate: true, harassment: false } },
        ],
      }),
    });
    const result = await moderateTranscript("bad words", "sk-test", stubFetch);
    expect(result.flagged).toBe(true);
    expect(result.categories).toEqual(["hate"]);
  });

  test("passes through clean content", async () => {
    const stubFetch = async () => ({
      ok: true,
      json: async () => ({
        results: [{ flagged: false, categories: { hate: false } }],
      }),
    });
    const result = await moderateTranscript("perfectly fine speech", "sk-test", stubFetch);
    expect(result).toEqual({ flagged: false });
  });

  test("fails open on upstream non-2xx", async () => {
    const stubFetch = async () => ({ ok: false, status: 503, json: async () => ({}) });
    const result = await moderateTranscript("anything", "sk-test", stubFetch);
    expect(result.flagged).toBe(false);
    expect(result.error).toBe("upstream_503");
  });

  test("fails open on thrown exception", async () => {
    const stubFetch = async () => {
      throw new Error("ECONNRESET");
    };
    const result = await moderateTranscript("anything", "sk-test", stubFetch);
    expect(result.flagged).toBe(false);
    expect(result.error).toMatch(/^exception_/);
  });
});
