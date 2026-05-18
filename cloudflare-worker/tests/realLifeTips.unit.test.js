import { describe, test, expect } from "vitest";
import { buildPrompt, parseGeminiResponseText } from "../src/realLifeTips.js";

describe("buildPrompt", () => {
  test("wraps user scenario in tags", () => {
    const out = buildPrompt({
      scenario: "asking for a raise",
      level: 5,
      durationSeconds: 60,
    });
    expect(out).toContain("<user_scenario>");
    expect(out).toContain("asking for a raise");
    expect(out).toContain("</user_scenario>");
    expect(out).toContain("Practice level: 5");
    expect(out).toContain("Target duration: 60 seconds");
  });

  test("includes second-person rewriting rule", () => {
    const out = buildPrompt({ scenario: "x", level: 1, durationSeconds: 30 });
    expect(out).toMatch(/second-person practice prompt/);
    expect(out).toMatch(/addressed to 'you'/);
  });
});

describe("parseGeminiResponseText - success", () => {
  test("accepts valid JSON with prompt + 3 tips", () => {
    const raw = JSON.stringify({
      rewrittenPrompt: "Ask your boss for a 10% raise based on your impact this year.",
      tips: ["Open with one concrete win.", "Name a specific number.", "Pause after the ask."],
    });
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(true);
    expect(r.rewrittenPrompt).toMatch(/Ask your boss/);
    expect(r.tips).toHaveLength(3);
  });

  test("trims whitespace from rewrittenPrompt", () => {
    const raw = JSON.stringify({
      rewrittenPrompt: "   Tell your team the deadline is slipping.   ",
      tips: ["a", "b", "c"],
    });
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(true);
    expect(r.rewrittenPrompt).toBe("Tell your team the deadline is slipping.");
  });

  test("strips markdown code fences", () => {
    const raw = "```json\n" + JSON.stringify({
      rewrittenPrompt: "Apologize to your sister for missing the wedding.",
      tips: ["a", "b", "c"],
    }) + "\n```";
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(true);
  });
});

describe("parseGeminiResponseText - refusal", () => {
  test("accepts explicit refusal shape", () => {
    const raw = JSON.stringify({ refused: true, reason: "Can't coach this." });
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(false);
    expect(r.refused).toBe(true);
    expect(r.reason).toBe("Can't coach this.");
  });

  test("supplies default reason if missing", () => {
    const raw = JSON.stringify({ refused: true });
    const r = parseGeminiResponseText(raw);
    expect(r.refused).toBe(true);
    expect(r.reason).toMatch(/coach/i);
  });

  test("extracts kind: notASpeakingPrompt", () => {
    const raw = JSON.stringify({
      refused: true,
      kind: "notASpeakingPrompt",
      reason: "Tell us about a conversation, not a recipe.",
    });
    const r = parseGeminiResponseText(raw);
    expect(r.refused).toBe(true);
    expect(r.kind).toBe("notASpeakingPrompt");
    expect(r.reason).toMatch(/conversation/i);
  });

  test("extracts kind: unsafe when present", () => {
    const raw = JSON.stringify({
      refused: true,
      kind: "unsafe",
      reason: "Can't coach this.",
    });
    const r = parseGeminiResponseText(raw);
    expect(r.kind).toBe("unsafe");
  });

  test("defaults kind to unsafe when missing", () => {
    const raw = JSON.stringify({ refused: true, reason: "nope" });
    const r = parseGeminiResponseText(raw);
    expect(r.kind).toBe("unsafe");
  });

  test("defaults kind to unsafe when unrecognized", () => {
    const raw = JSON.stringify({
      refused: true,
      kind: "completelyMadeUp",
      reason: "nope",
    });
    const r = parseGeminiResponseText(raw);
    expect(r.kind).toBe("unsafe");
  });

  test("malformed JSON refusal also carries kind: unsafe", () => {
    const r = parseGeminiResponseText("not json at all");
    expect(r.refused).toBe(true);
    expect(r.kind).toBe("unsafe");
  });
});

describe("parseGeminiResponseText - rejection of malformed output", () => {
  test("invalid JSON falls back to refusal", () => {
    const r = parseGeminiResponseText("not json at all");
    expect(r.ok).toBe(false);
    expect(r.refused).toBe(true);
  });

  test("missing rewrittenPrompt rejected", () => {
    const raw = JSON.stringify({ tips: ["a", "b", "c"] });
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(false);
    expect(r.refused).toBe(true);
  });

  test("only 2 tips rejected", () => {
    const raw = JSON.stringify({
      rewrittenPrompt: "Do the thing.",
      tips: ["a", "b"],
    });
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(false);
  });

  test("empty tip string rejected", () => {
    const raw = JSON.stringify({
      rewrittenPrompt: "Do the thing.",
      tips: ["a", "", "c"],
    });
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(false);
  });

  test("rewrittenPrompt over 200 chars rejected", () => {
    const raw = JSON.stringify({
      rewrittenPrompt: "x".repeat(201),
      tips: ["a", "b", "c"],
    });
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(false);
  });

  test("empty rewrittenPrompt rejected", () => {
    const raw = JSON.stringify({ rewrittenPrompt: "   ", tips: ["a", "b", "c"] });
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(false);
  });
});
