# AI Quality Harness — Runbook

## Status

Active — v1, on-demand only. Built 2026-05-08.

## What it is

A Swift Testing suite under `ParlanceTests/AIQuality/` that runs curated transcript fixtures through the real `/feedback` endpoint and asserts the response is in expected shape (score bands + behavioral checks).

- Spec: `_docs/specs/2026-05-08-ai-quality-harness-design.md`
- Plan: `_docs/plans/2026-05-08-ai-quality-harness.md`

## Running it

The harness is gated by the `RUN_AI_QUALITY` environment variable. Without it, the suite reports as skipped — so accidental `cmd-U` and default `xcodebuild test` runs do not hit the worker.

**Run all 8 fixtures (live worker):**

```bash
RUN_AI_QUALITY=1 xcodebuild test \
  -project ParlanceApp/Parlance.xcodeproj \
  -scheme Parlance \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:ParlanceTests/AIQualityHarness
```

**Run with verbose result printing** (each fixture prints its full `ScoringResult`):

The harness already prints the full result per fixture to the test log. To capture them:

```bash
RUN_AI_QUALITY=1 xcodebuild test \
  -project ParlanceApp/Parlance.xcodeproj \
  -scheme Parlance \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:ParlanceTests/AIQualityHarness 2>&1 | tee /tmp/ai-harness.log
```

Each run hits the live worker (Cloudflare → Gemini) and uses API quota. Cost: a few cents per full run (8 fixtures × ~1k tokens × Haiku/Flash pricing).

## When to run it

Before shipping changes that touch:

- `FeedbackGenerator.buildPrompt` (prompt template, mode/level tone logic)
- `cloudflare-worker/src/index.js` `handleFeedback` (model, temperature, generation config)
- The model name in `wrangler.toml` env vars (`GEMINI_MODEL`)
- Any of the prompt-shaping data structures (`TimingStats`, `AudioFeatures`, `MetricKey`, `ScoringResult`)
- The scoring response schema

Don't run on every PR — quota cost adds up and bands aren't tight enough for that.

## Stability

The Cloudflare worker accepts an optional `temperature` field in the `/feedback` request body (added 2026-05-08, working-tree only — deploy via `wrangler deploy` from `cloudflare-worker/` to make it live). The harness pins `temperature: 0` via `AIQualityTestClient`, so successive runs are near-deterministic.

**Important:** until the worker is deployed with the temperature change, the harness will run with the worker's hardcoded `temperature: 0.3` and produce more varied scores. Bands may need to be wider until then.

Gemini at `temperature: 0` is not strictly deterministic. Observed spread (fill in after first runs):

| Fixture | Run 1 overall | Run 2 overall | Run 3 overall | Spread |
|---|---|---|---|---|
| `interview-empty` | TBD | TBD | TBD | TBD |
| `interview-great-star` | TBD | TBD | TBD | TBD |
| `interview-rambling` | TBD | TBD | TBD | TBD |
| `interview-filler-heavy` | TBD | TBD | TBD | TBD |
| `interview-off-topic` | TBD | TBD | TBD | TBD |
| `pitch-strong-hook` | TBD | TBD | TBD | TBD |
| `keynote-flat-open` | TBD | TBD | TBD | TBD |
| `casual-clear` | TBD | TBD | TBD | TBD |

If a fixture flakes after band-tuning, prefer widening the band. Only escalate to N-run-median if multiple fixtures flake.

## Tuning bands

After the first 3 runs, edit `ParlanceTests/AIQuality/AIQualityFixtures.swift` per fixture:

- All 3 runs in band: leave alone or tighten by 2–3 points if spread is < 4
- Any run out of band: widen the band to cover the spread + 5 points headroom on the side that drifted
- Fixture fundamentally wrong (Gemini doesn't catch the failure mode): revise the transcript to be more clearly broken, or drop the fixture and document why

## When to add a fixture

Add when you find a real-world failure mode the harness doesn't catch. Avoid adding just to expand coverage — each fixture costs API budget per run and is a maintenance burden when prompts change.

## Architecture notes

- `AIQualityTestClient` wraps `ClaudeClient` with `temperature: 0` pinned. Both conform to `ScoringClient` (added in commit `26ff710`).
- `FeedbackGenerator.fetchScoring` accepts `any ScoringClient` (commit `3c951a2`), so the harness injects the test client through the production code path — exercising the real `buildPrompt`, the real wrapped-decode logic in `ClaudeClient.fetchScoring`, and the real worker call.
- The harness is in test target `ParlanceTests`, in folder `ParlanceTests/AIQuality/`. The folder is part of a `PBXFileSystemSynchronizedRootGroup`, so new files added there are automatically included in the test target without `project.pbxproj` edits.
- The suite is gated by `.enabled(if: ProcessInfo.processInfo.environment["RUN_AI_QUALITY"] == "1", ...)`. Without the env var, the suite is reported skipped with a clear reason.

## Out of scope (deferred)

See spec § *Out of scope (deferred)*. Notably:

- Recording UI flow tests (mic-mocked `SessionCoordinator` drive)
- `SpeechTranscriber` audio-fixture tests
- Snapshot/baseline diffing
- Per-PR or nightly CI
- Pace / audio-feature variation fixtures
- Test plan integration (attempted on Xcode 26.4.1, plan files weren't readable; pivoted to env-var gating + `-only-testing` filtering, which is robust regardless of Xcode version)
