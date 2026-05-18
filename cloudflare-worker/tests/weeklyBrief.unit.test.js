import { describe, test, expect, vi } from "vitest";
import {
  validateRequest,
  buildUserMessage,
  buildPrompt,
  parseGeminiResponseText,
  buildFallbackBrief,
  generateWeeklyBrief,
  SYSTEM_PROMPT,
} from "../src/weeklyBrief.js";

// -- Reusable valid fixture ------------------------------------------------

function makeValidPayload(overrides = {}) {
  return {
    weekStart: "2026-05-11T07:00:00Z",
    isPro: true,
    user: { currentStreak: 17, rankName: "Confident Communicator", level: 5 },
    thisWeek: {
      sessionCount: 4,
      avgScore: 82,
      totalDurationSec: 720,
      modeDistribution: { interview: 1, casual: 1, explanation: 1, impromptu: 1 },
      paceWatchSessionCount: 1,
      bestSession: {
        mode: "Explanation",
        score: 90,
        question: "Walk me through how a vaccine works.",
        date: "2026-05-05",
        aiCoachFeedback: "One of your strongest sessions.",
      },
      worstSession: null,
    },
    priorWeek: { sessionCount: 2, avgScore: 76, totalDurationSec: 360 },
    allTime: { sessionCount: 24, avgScore: 79, totalDurationSec: 8280 },
    metrics: [
      { key: "filler",     thisWeek: 7.8, priorWeek: 5.4, allTime: 6.5, deltaVsPrior: 2.4,  deltaVsAllTime: 1.3 },
      { key: "pace",       thisWeek: 7.2, priorWeek: 7.6, allTime: 7.5, deltaVsPrior: -0.4, deltaVsAllTime: -0.3 },
      { key: "clarity",    thisWeek: 8.4, priorWeek: 8.0, allTime: 7.9, deltaVsPrior: 0.4,  deltaVsAllTime: 0.5 },
      { key: "structure",  thisWeek: 6.5, priorWeek: 6.2, allTime: 5.8, deltaVsPrior: 0.3,  deltaVsAllTime: 0.7 },
      { key: "vocabulary", thisWeek: 8.1, priorWeek: 7.8, allTime: 7.5, deltaVsPrior: 0.3,  deltaVsAllTime: 0.6 },
    ],
    biggestImprovement: { key: "filler", delta: 2.4 },
    biggestRegression: null,
    proEmotion: {
      avgConfidence: 0.62,
      avgNervousness: 0.28,
      avgEnthusiasm: 0.54,
      dominantEmotion: "Determination",
    },
    ...overrides,
  };
}

// -- validateRequest -------------------------------------------------------

describe("validateRequest", () => {
  test("accepts a complete payload", () => {
    expect(validateRequest(makeValidPayload()).ok).toBe(true);
  });

  test("rejects null", () => {
    expect(validateRequest(null).ok).toBe(false);
  });

  test("rejects when sessionCount < 2", () => {
    const r = validateRequest(makeValidPayload({ thisWeek: { ...makeValidPayload().thisWeek, sessionCount: 1 } }));
    expect(r.ok).toBe(false);
    expect(r.error).toBe("insufficient_data");
  });

  test("rejects when metrics array is wrong length", () => {
    const p = makeValidPayload();
    p.metrics = p.metrics.slice(0, 3);
    const r = validateRequest(p);
    expect(r.ok).toBe(false);
    expect(r.error).toBe("metrics_length");
  });

  test("rejects an unknown metric key", () => {
    const p = makeValidPayload();
    p.metrics[0] = { ...p.metrics[0], key: "delivery_confidence" };
    const r = validateRequest(p);
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/^metric_key:/);
  });

  test("rejects a non-number metric field", () => {
    const p = makeValidPayload();
    p.metrics[0] = { ...p.metrics[0], deltaVsPrior: "0.5" };
    const r = validateRequest(p);
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/^metric_filler_deltaVsPrior$/);
  });
});

// -- buildUserMessage / buildPrompt ----------------------------------------

describe("buildUserMessage", () => {
  test("wraps the data in <weekly_data> tags", () => {
    const out = buildUserMessage(makeValidPayload());
    expect(out).toMatch(/^<weekly_data>/);
    expect(out).toMatch(/<\/weekly_data>$/);
  });

  test("includes all five metrics in this-week / prior / all-time order", () => {
    const out = buildUserMessage(makeValidPayload());
    for (const label of ["Filler control", "Pace", "Clarity", "Structure", "Vocabulary"]) {
      expect(out).toContain(label);
    }
    expect(out).toMatch(/Skill averages \(0-10\), this week \/ prior week \/ all time:/);
  });

  test("includes Pro emotion line only when proEmotion is non-null", () => {
    const withPro = buildUserMessage(makeValidPayload());
    expect(withPro).toContain("Vocal emotion signals");

    const withoutPro = buildUserMessage(makeValidPayload({ proEmotion: null, isPro: false }));
    expect(withoutPro).not.toContain("Vocal emotion signals");
  });

  test("includes 'Biggest regression: none flagged' when no regression", () => {
    const out = buildUserMessage(makeValidPayload());
    expect(out).toContain("Biggest regression: none flagged");
  });
});

describe("buildPrompt", () => {
  test("prepends SYSTEM_PROMPT and a blank line before the user message", () => {
    const out = buildPrompt(makeValidPayload());
    expect(out.startsWith(SYSTEM_PROMPT)).toBe(true);
    expect(out).toMatch(/\n\n<weekly_data>/);
  });
});

// -- parseGeminiResponseText -----------------------------------------------

describe("parseGeminiResponseText", () => {
  test("parses a clean JSON response", () => {
    const r = parseGeminiResponseText(JSON.stringify({
      brief: "Two short sentences.",
      highlights: [{ kind: "positive", phrase: "Two short sentences." }],
    }));
    expect(r.ok).toBe(true);
    expect(r.brief).toBe("Two short sentences.");
  });

  test("strips ```json code fences before parsing", () => {
    const raw = "```json\n" + JSON.stringify({ brief: "Hi.", highlights: [] }) + "\n```";
    const r = parseGeminiResponseText(raw);
    expect(r.ok).toBe(true);
  });

  test("returns ok:false on invalid JSON", () => {
    const r = parseGeminiResponseText("not json");
    expect(r.ok).toBe(false);
    expect(r.error).toBe("json_parse");
  });

  test("recognises the model's own refusal contract", () => {
    const r = parseGeminiResponseText(JSON.stringify({ refused: true, reason: "insufficient_signal" }));
    expect(r.ok).toBe(false);
    expect(r.error).toBe("model_refused");
  });

  test("rejects when brief is missing", () => {
    const r = parseGeminiResponseText(JSON.stringify({ highlights: [] }));
    expect(r.ok).toBe(false);
    expect(r.error).toBe("brief_missing");
  });
});

// -- buildFallbackBrief ----------------------------------------------------

describe("buildFallbackBrief", () => {
  test("renders a deterministic up-trending brief", () => {
    const fb = buildFallbackBrief(makeValidPayload());
    expect(fb.brief).toContain("4 sessions");
    expect(fb.brief).toContain("82");
    expect(fb.brief).toContain("up");
    expect(fb.highlights).toEqual([]);
  });

  test("renders a holding-steady brief when avg score is flat", () => {
    const p = makeValidPayload({
      thisWeek: { ...makeValidPayload().thisWeek, avgScore: 76 },
    });
    const fb = buildFallbackBrief(p);
    expect(fb.brief).toContain("holding steady");
  });
});

// -- generateWeeklyBrief (with stubbed fetch) ------------------------------

describe("generateWeeklyBrief", () => {
  function stubGemini({ candidateText, ok = true, status = 200, finishReason = null } = {}) {
    return vi.fn(async () => ({
      ok,
      status,
      json: async () => ({
        candidates: [
          {
            finishReason,
            content: { parts: [{ text: candidateText }] },
          },
        ],
      }),
    }));
  }

  test("returns source=gemini when the model produces a clean brief", async () => {
    const briefText = "You completed four sessions this week with an average score of 82, up 6 from last week. Filler control improved most. Aim for one session a day to keep the streak.";
    const stub = stubGemini({
      candidateText: JSON.stringify({ brief: briefText, highlights: [{ kind: "positive", phrase: "four sessions" }] }),
    });

    const r = await generateWeeklyBrief({
      payload: makeValidPayload(),
      geminiApiKey: "fake",
      fetchImpl: stub,
    });

    expect(r.ok).toBe(true);
    expect(r.source).toBe("gemini");
    expect(r.brief).toBe(briefText);
    expect(stub).toHaveBeenCalledOnce();
  });

  test("falls back when finishReason is SAFETY", async () => {
    const stub = stubGemini({ candidateText: "", finishReason: "SAFETY" });
    const r = await generateWeeklyBrief({
      payload: makeValidPayload(),
      geminiApiKey: "fake",
      fetchImpl: stub,
    });
    expect(r.source).toBe("fallback");
    expect(r.errorContext).toMatch(/SAFETY/);
  });

  test("falls back when the model emits invalid JSON", async () => {
    const stub = stubGemini({ candidateText: "not json at all" });
    const r = await generateWeeklyBrief({
      payload: makeValidPayload(),
      geminiApiKey: "fake",
      fetchImpl: stub,
    });
    expect(r.source).toBe("fallback");
  });

  test("falls back when the safety pipeline rejects (profanity)", async () => {
    const briefText = "You did some shit sessions this week with an average score of 82. Filler control improved most. Aim for one session a day to keep the streak going strong.";
    const stub = stubGemini({
      candidateText: JSON.stringify({ brief: briefText, highlights: [] }),
    });
    const r = await generateWeeklyBrief({
      payload: makeValidPayload(),
      geminiApiKey: "fake",
      fetchImpl: stub,
    });
    expect(r.source).toBe("fallback");
    expect(r.errorContext).toMatch(/^safety:profanity:shit$/);
  });

  test("falls back on upstream HTTP error", async () => {
    const stub = stubGemini({ ok: false, status: 503, candidateText: "" });
    const r = await generateWeeklyBrief({
      payload: makeValidPayload(),
      geminiApiKey: "fake",
      fetchImpl: stub,
    });
    expect(r.source).toBe("fallback");
    expect(r.errorContext).toMatch(/upstream:503/);
  });

  test("falls back on network error (fetch throws)", async () => {
    const stub = vi.fn(async () => { throw new Error("conn refused"); });
    const r = await generateWeeklyBrief({
      payload: makeValidPayload(),
      geminiApiKey: "fake",
      fetchImpl: stub,
    });
    expect(r.source).toBe("fallback");
    expect(r.errorContext).toMatch(/^network:/);
  });

  test("under-2-session payload rejects before any model call", async () => {
    const stub = vi.fn();
    const r = await generateWeeklyBrief({
      payload: makeValidPayload({ thisWeek: { ...makeValidPayload().thisWeek, sessionCount: 1 } }),
      geminiApiKey: "fake",
      fetchImpl: stub,
    });
    expect(r.ok).toBe(false);
    expect(r.error).toBe("insufficient_data");
    expect(stub).not.toHaveBeenCalled();
  });

  test("Gemini request body includes the four safety settings", async () => {
    const briefText = "You completed four sessions this week with an average score of 82, up 6 from last week. Filler control improved most. Aim for one session a day to keep the streak.";
    const stub = stubGemini({
      candidateText: JSON.stringify({ brief: briefText, highlights: [] }),
    });
    await generateWeeklyBrief({ payload: makeValidPayload(), geminiApiKey: "fake", fetchImpl: stub });

    const body = JSON.parse(stub.mock.calls[0][1].body);
    expect(body.safetySettings).toBeDefined();
    expect(body.safetySettings).toHaveLength(4);
    for (const setting of body.safetySettings) {
      expect(setting.threshold).toBe("BLOCK_LOW_AND_ABOVE");
    }
    expect(body.generationConfig.thinkingConfig.thinkingBudget).toBe(0);
    expect(body.generationConfig.responseMimeType).toBe("application/json");
  });

  test("Gemini request body sends prompt as a single contents text part (no systemInstruction field)", async () => {
    const briefText = "You completed four sessions this week with an average score of 82, up 6 from last week. Filler control improved most. Aim for one session a day to keep the streak.";
    const stub = stubGemini({
      candidateText: JSON.stringify({ brief: briefText, highlights: [] }),
    });
    await generateWeeklyBrief({ payload: makeValidPayload(), geminiApiKey: "fake", fetchImpl: stub });

    const body = JSON.parse(stub.mock.calls[0][1].body);
    expect(body.systemInstruction).toBeUndefined();
    expect(body.contents).toHaveLength(1);
    expect(body.contents[0].parts).toHaveLength(1);
    // The single text part should contain both the system prompt and the wrapped data.
    expect(body.contents[0].parts[0].text).toContain("safe for children");
    expect(body.contents[0].parts[0].text).toContain("<weekly_data>");
  });
});
