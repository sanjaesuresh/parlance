import { describe, test, expect } from "vitest";
import {
  runSafetyPipeline,
  checkLength,
  checkProfanity,
  checkHedging,
  checkPII,
  checkHighlights,
  PROFANITY,
} from "../src/briefSafety.js";

const CLEAN_BRIEF =
  "You completed four sessions this week with an average score of 82, up 6 from last week. Your strongest gain was in filler control. Aim for at least one session a day to keep the streak going.";

describe("checkLength", () => {
  test("accepts a brief in the 25–80 word range", () => {
    expect(checkLength(CLEAN_BRIEF).ok).toBe(true);
  });

  test("rejects too-short brief", () => {
    const r = checkLength("You did some sessions.");
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/^length:/);
  });

  test("rejects too-long brief", () => {
    const r = checkLength("word ".repeat(120));
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/^length:/);
  });
});

describe("checkProfanity", () => {
  test("accepts a clean brief", () => {
    expect(checkProfanity(CLEAN_BRIEF).ok).toBe(true);
  });

  test("rejects an embedded profanity (case-insensitive)", () => {
    const r = checkProfanity("Your performance was shit this week despite three sessions.");
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("profanity:shit");
  });

  test("rejects an embedded slur", () => {
    const r = checkProfanity("You did fine, retard.");
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/^profanity:/);
  });

  test("the wordlist itself is sane (non-empty, lowercased, deduplicated)", () => {
    expect(PROFANITY.size).toBeGreaterThan(80);
    for (const w of PROFANITY) {
      expect(w).toBe(w.toLowerCase());
      expect(w).toMatch(/^[a-z][a-z'-]*$/);
    }
  });
});

describe("checkHedging", () => {
  test("accepts direct coaching tone", () => {
    expect(checkHedging(CLEAN_BRIEF).ok).toBe(true);
  });

  test("rejects 'maybe'", () => {
    const r = checkHedging("You might maybe consider slowing down on Tuesday.");
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/^hedge:/);
  });

  test("rejects 'I think'", () => {
    const r = checkHedging("I think you should keep going.");
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("hedge:i think");
  });

  test("'kindling' does NOT trigger 'kind' false-positive", () => {
    // 'kind of' is hedged, but bare 'kind' or 'kindling' should not be.
    // (The hedge list contains 'kind of' as a phrase.)
    const r = checkHedging("Your delivery had kindling energy throughout the week.");
    expect(r.ok).toBe(true);
  });
});

describe("checkPII", () => {
  test("accepts a clean brief", () => {
    expect(checkPII(CLEAN_BRIEF).ok).toBe(true);
  });

  test("rejects an email", () => {
    const r = checkPII("You can reach me at coach@example.com for next week.");
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("pii_match");
  });

  test("rejects a US phone number", () => {
    const r = checkPII("Call 415-555-1234 to schedule a follow-up.");
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("pii_match");
  });

  test("rejects a US SSN-shape", () => {
    const r = checkPII("Your ID 123-45-6789 is on file.");
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("pii_match");
  });

  test("rejects a street address", () => {
    const r = checkPII("Meet at 415 Market Street next Tuesday.");
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("pii_match");
  });

  test("date '2026-05-13' is NOT matched as a phone number", () => {
    const r = checkPII("Week starting 2026-05-13 showed strong results.");
    expect(r.ok).toBe(true);
  });
});

describe("checkHighlights", () => {
  test("accepts well-formed highlights present in the brief", () => {
    const r = checkHighlights({
      brief: CLEAN_BRIEF,
      highlights: [{ kind: "positive", phrase: "four sessions" }],
    });
    expect(r.ok).toBe(true);
  });

  test("rejects when highlights is missing", () => {
    const r = checkHighlights({ brief: CLEAN_BRIEF, highlights: null });
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("highlights_missing");
  });

  test("rejects too many highlights", () => {
    const r = checkHighlights({
      brief: CLEAN_BRIEF,
      highlights: Array.from({ length: 4 }, (_, i) => ({ kind: "positive", phrase: "four" })),
    });
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("highlights_too_many");
  });

  test("rejects highlight kind 'neutral'", () => {
    const r = checkHighlights({
      brief: CLEAN_BRIEF,
      highlights: [{ kind: "neutral", phrase: "four sessions" }],
    });
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("highlight_kind");
  });

  test("rejects a phrase not found in the brief", () => {
    const r = checkHighlights({
      brief: CLEAN_BRIEF,
      highlights: [{ kind: "positive", phrase: "twelve sessions" }],
    });
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/^highlight_not_in_brief:/);
  });
});

describe("runSafetyPipeline (end-to-end)", () => {
  test("clean brief + valid highlights pass", () => {
    expect(
      runSafetyPipeline({
        brief: CLEAN_BRIEF,
        highlights: [{ kind: "positive", phrase: "four sessions" }],
      }).ok,
    ).toBe(true);
  });

  test("short-circuits on first failure (length before profanity)", () => {
    const r = runSafetyPipeline({ brief: "shit", highlights: [] });
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/^length:/); // length fails before profanity
  });

  test("flags profanity inside a length-valid brief", () => {
    const brief = "Your sessions this week were absolute shit overall, with three completed and a sixty-eight average. Keep showing up Tuesday and Thursday for the consistency points.";
    const r = runSafetyPipeline({ brief, highlights: [] });
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("profanity:shit");
  });

  test("flags hedging after profanity passes", () => {
    const brief = "You completed four sessions this week with an average score of 82. You might want to maybe slow down on Tuesday. Aim for at least one session a day to keep the streak.";
    const r = runSafetyPipeline({ brief, highlights: [] });
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/^hedge:/);
  });

  test("flags PII after hedging passes", () => {
    const brief = "You completed four sessions this week with an average score of 82. The next coach call is at coach@example.com next Monday. Aim for at least one session a day this coming stretch.";
    const r = runSafetyPipeline({ brief, highlights: [] });
    expect(r.ok).toBe(false);
    expect(r.reason).toBe("pii_match");
  });

  test("flags highlight integrity after content checks pass", () => {
    const r = runSafetyPipeline({
      brief: CLEAN_BRIEF,
      highlights: [{ kind: "positive", phrase: "twelve sessions" }],
    });
    expect(r.ok).toBe(false);
    expect(r.reason).toMatch(/^highlight_not_in_brief:/);
  });
});
