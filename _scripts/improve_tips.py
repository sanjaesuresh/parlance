"""
Rewrites all coaching tips in questions.json to be specific, actionable, and 20-35 words each.
Run: ANTHROPIC_API_KEY=sk-... python3 _scripts/improve_tips.py

Progress is saved after each batch so it's safe to interrupt and re-run.
"""

import anthropic
import json
import os
import sys
import time
import shutil
from pathlib import Path

QUESTIONS_PATH = Path(__file__).parent.parent / "Parlance/Resources/questions.json"
BACKUP_PATH = QUESTIONS_PATH.with_suffix(".json.bak")
BATCH_SIZE = 15

SYSTEM = """\
You rewrite coaching tips for Parlance, a premium speech-practice app.
Each question has exactly 3 tips shown to the user before they record their answer.

Rules:
- Each tip must be 20-35 words. Currently tips are only 5-8 words — expand them with specifics.
- Actionable: say exactly what to do and why, not just a vague direction.
- Coach voice: direct, confident, no fluff. Like a coach, not a cheerleader.
- No em dashes. Use colons, commas, or periods instead.
- No filler phrases: "make sure to", "don't forget", "remember to", "try to".
- Tips must be distinct — each should cover a different aspect of the answer.
- Reference the question itself. Generic tips that could apply to any question are not acceptable.
- Calibrate to difficultyBand: band 1-2 tips explain fundamentals; band 9-10 tips assume mastery and push for excellence.

Mode-specific guidance:
- interview: reference STAR (Situation/Task/Action/Result), conciseness, confidence signals, specificity
- pitch: hook strength, urgency, problem/solution clarity, who-it's-for
- keynote: narrative arc, opening impact, emotional resonance, delivery pacing
- casual: clarity, naturalness, conversational flow, holding attention
- debate: argument structure, evidence types, addressing counterarguments, signposting
- storytelling: scene-setting, tension/conflict, sensory detail, emotional payoff
- explanation: analogies, chunking complexity, audience calibration, checking for understanding
- impromptu: committing to a position, structural signposts, confident delivery under pressure
- negotiation: anchoring, interest-based framing, concession strategy, tone management
- networking: memorable hooks, genuine curiosity, follow-up invitations, brevity

Output ONLY valid JSON, no other text:
{"results": [{"id": "...", "tips": ["tip1", "tip2", "tip3"]}, ...]}\
"""


def improve_batch(client: anthropic.Anthropic, batch: list[dict]) -> dict[str, list[str]]:
    payload = [
        {
            "id": q["id"],
            "mode": q["mode"],
            "difficultyBand": q["difficultyBand"],
            "difficultyNote": q.get("difficultyNote", ""),
            "targetDuration": q["targetDuration"],
            "question": q["question"],
            "current_tips": q["tips"],
        }
        for q in batch
    ]

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=8096,
        system=SYSTEM,
        messages=[
            {
                "role": "user",
                "content": (
                    f"Rewrite coaching tips for these {len(batch)} questions.\n\n"
                    + json.dumps(payload, indent=2)
                ),
            }
        ],
    )

    raw = response.content[0].text.strip()
    parsed = json.loads(raw)
    return {item["id"]: item["tips"] for item in parsed["results"]}


def main():
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("Error: ANTHROPIC_API_KEY not set.", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)

    with open(QUESTIONS_PATH) as f:
        data: list[dict] = json.load(f)

    # Back up original once
    if not BACKUP_PATH.exists():
        shutil.copy(QUESTIONS_PATH, BACKUP_PATH)
        print(f"Backed up to {BACKUP_PATH.name}")

    total = len(data)
    batches = [data[i : i + BATCH_SIZE] for i in range(0, total, BATCH_SIZE)]
    print(f"{total} questions, {len(batches)} batches of up to {BATCH_SIZE}")

    updated = 0
    for batch_num, batch in enumerate(batches, 1):
        ids = [q["id"] for q in batch]
        print(f"Batch {batch_num}/{len(batches)}: {ids[0]} … {ids[-1]}", end=" ", flush=True)

        try:
            new_tips = improve_batch(client, batch)
        except Exception as e:
            print(f"\n  ERROR on batch {batch_num}: {e}")
            print("  Saving progress so far and stopping.")
            break

        for q in data:
            if q["id"] in new_tips:
                tips = new_tips[q["id"]]
                # Validate word count — warn but don't block
                for i, tip in enumerate(tips):
                    wc = len(tip.split())
                    if wc < 15 or wc > 45:
                        print(f"\n  WARN [{q['id']}] tip {i+1} is {wc} words: {tip[:60]}")
                q["tips"] = tips
                updated += 1

        # Save after every batch
        with open(QUESTIONS_PATH, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        print(f"done ({updated} updated so far)")
        # Brief pause to avoid rate limits
        time.sleep(0.5)

    print(f"\nFinished. {updated}/{total} questions updated.")
    print("Run again to retry any failed batches (backup preserved at .bak).")


if __name__ == "__main__":
    main()
