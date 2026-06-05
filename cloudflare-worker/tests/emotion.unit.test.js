import { describe, test, expect } from "vitest";
import { summarizeEmotions } from "../src/index.js";

function makePredictions(segments) {
  return [
    {
      results: {
        predictions: [
          {
            models: {
              prosody: {
                grouped_predictions: [{ predictions: segments }],
              },
            },
          },
        ],
      },
    },
  ];
}

function segment(scores) {
  return {
    emotions: Object.entries(scores).map(([name, score]) => ({ name, score })),
  };
}

describe("summarizeEmotions", () => {
  test("returns neutral fallback shape when no segments", () => {
    const result = summarizeEmotions(makePredictions([]));
    expect(result.dominantEmotion).toBe("Neutral");
    expect(result.emotionArc).toEqual([]);
    expect(result.topEmotions).toEqual([]);
    expect(result.emotionTimelines).toEqual({});
  });

  test("averages emotions across segments and picks the dominant one", () => {
    const result = summarizeEmotions(
      makePredictions([
        segment({ Determination: 0.8, Anxiety: 0.2, Excitement: 0.5 }),
        segment({ Determination: 0.6, Anxiety: 0.4, Excitement: 0.3 }),
      ])
    );

    expect(result.dominantEmotion).toBe("Determination");
    expect(result.confidenceScore).toBeCloseTo(0.7, 5);
    expect(result.nervousnessScore).toBeCloseTo(0.3, 5);
    expect(result.enthusiasmScore).toBeCloseTo(0.4, 5);
  });

  test("topEmotions returns up to 10 entries ranked by averaged score", () => {
    const labels = Array.from({ length: 15 }, (_, i) => `E${i}`);
    // Each emotion's score = (15 - i) / 15, so E0 ranks highest, E14 lowest
    const scores = Object.fromEntries(
      labels.map((name, i) => [name, (15 - i) / 15])
    );

    const result = summarizeEmotions(makePredictions([segment(scores)]));

    expect(result.topEmotions).toHaveLength(10);
    expect(result.topEmotions[0].name).toBe("E0");
    expect(result.topEmotions[9].name).toBe("E9");
    expect(result.topEmotions[0].score).toBeCloseTo(1.0, 5);
    // Sorted strictly descending
    for (let i = 1; i < result.topEmotions.length; i++) {
      expect(result.topEmotions[i - 1].score).toBeGreaterThanOrEqual(
        result.topEmotions[i].score
      );
    }
  });

  test("emotionTimelines has one arc per top emotion, length = segment count", () => {
    const segs = [
      segment({ Determination: 0.1, Excitement: 0.9 }),
      segment({ Determination: 0.5, Excitement: 0.5 }),
      segment({ Determination: 0.9, Excitement: 0.1 }),
    ];
    const result = summarizeEmotions(makePredictions(segs));

    expect(Object.keys(result.emotionTimelines).sort()).toEqual([
      "Determination",
      "Excitement",
    ]);
    expect(result.emotionTimelines.Determination).toEqual([0.1, 0.5, 0.9]);
    expect(result.emotionTimelines.Excitement).toEqual([0.9, 0.5, 0.1]);
  });

  test("emotionArc tracks the dominant emotion's timeline", () => {
    const result = summarizeEmotions(
      makePredictions([
        segment({ Determination: 0.2, Excitement: 0.05 }),
        segment({ Determination: 0.6, Excitement: 0.05 }),
        segment({ Determination: 0.9, Excitement: 0.05 }),
      ])
    );
    expect(result.dominantEmotion).toBe("Determination");
    expect(result.emotionArc).toEqual([0.2, 0.6, 0.9]);
  });

  test("missing emotion in a segment is treated as 0 in its timeline", () => {
    const result = summarizeEmotions(
      makePredictions([
        segment({ Determination: 0.8, Anxiety: 0.1 }),
        segment({ Determination: 0.6 }), // no Anxiety
      ])
    );
    expect(result.emotionTimelines.Anxiety).toEqual([0.1, 0]);
  });
});
