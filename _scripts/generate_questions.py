#!/usr/bin/env python3
"""
Parlance question bank expander.
Generates questions to reach target counts per mode/difficulty band.

Targets:
  - Main modes (interview, pitch, keynote, casual): 60 per band
  - Sub-modes (debate, explanation, impromptu, negotiation, networking, storytelling): 40 per band

Usage:
  ANTHROPIC_API_KEY=sk-ant-... python3 generate_questions.py
"""

import anthropic
import json
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

QUESTIONS_PATH = Path(__file__).parent.parent / "Parlance/Resources/questions.json"
OUTPUT_PATH = Path(__file__).parent / "generated_questions.json"

client = anthropic.Anthropic()

BANDS = ["1-2", "3-4", "5-6", "7-8", "9-10"]

BAND_DESCRIPTIONS = {
    "1-2": "Nervous Novice / First-Timer — very beginner, low stakes, familiar everyday topics, short responses",
    "3-4": "Getting Warmed Up / Emerging Orator — building confidence, slightly more complex topics, structured responses",
    "5-6": "Confident Communicator / Polished Speaker — intermediate, professional topics, nuanced answers expected",
    "7-8": "Compelling Storyteller / Stage Commander — advanced, high-stakes scenarios, sophisticated language and structure",
    "9-10": "Master Presenter / Elite Orator — expert level, complex multi-part challenges, near-professional quality expected",
}

TARGET_DURATIONS = {
    "interview": {"1-2": 60, "3-4": 90, "5-6": 90, "7-8": 120, "9-10": 120},
    "pitch":     {"1-2": 60, "3-4": 90, "5-6": 90, "7-8": 120, "9-10": 120},
    "keynote":   {"1-2": 60, "3-4": 90, "5-6": 90, "7-8": 120, "9-10": 120},
    "casual":    {"1-2": 60, "3-4": 90, "5-6": 90, "7-8": 120, "9-10": 120},
    "debate":        {"1-2": 45, "3-4": 60, "5-6": 75, "7-8": 90, "9-10": 120},
    "explanation":   {"1-2": 45, "3-4": 60, "5-6": 75, "7-8": 90, "9-10": 120},
    "negotiation":   {"1-2": 45, "3-4": 60, "5-6": 75, "7-8": 90, "9-10": 120},
    "storytelling":  {"1-2": 45, "3-4": 60, "5-6": 75, "7-8": 90, "9-10": 120},
    "impromptu":     {"1-2": 30, "3-4": 45, "5-6": 60, "7-8": 75, "9-10": 90},
    "networking":    {"1-2": 30, "3-4": 45, "5-6": 60, "7-8": 75, "9-10": 90},
}

TARGETS = {
    "interview": 60, "pitch": 60, "keynote": 60, "casual": 60,
    "debate": 40, "explanation": 40, "impromptu": 40,
    "negotiation": 40, "networking": 40, "storytelling": 40,
}

MODE_CONTEXT = {
    "interview": "Job interview practice — behavioral (STAR method), situational, and values-based questions. Covers all levels from intern to executive.",
    "pitch": "Pitch and sales practice — investor pitches, cold outreach, objection handling, product demos. Focus on hook, urgency, and persuasion.",
    "keynote": "Keynote and public speaking — TED-style talks, conference presentations, toasts, panel discussions. Focus on narrative arc, opening impact, and pacing.",
    "casual": "Daily conversation practice — explaining ideas, impromptu speaking, holding attention, natural communication.",
    "debate": "Debate practice — argue a position clearly and persuasively. Each question specifies a topic; user argues for one side.",
    "explanation": "Explanation practice — explain complex concepts, products, or ideas to different audiences. Focus on clarity, analogies, and avoiding jargon.",
    "impromptu": "Impromptu speaking — spontaneous short speeches on everyday topics. Focus on quick thinking, structure, and confidence.",
    "negotiation": "Negotiation practice — salary negotiations, vendor deals, conflict resolution, business scenarios. Focus on anchoring, listening, and finding common ground.",
    "networking": "Networking practice — introductions, small talk, following up, elevator pitches in social contexts.",
    "storytelling": "Storytelling practice — personal anecdotes, professional stories, narratives with a clear arc (setup, conflict, resolution, lesson).",
}


def load_existing() -> list[dict]:
    with open(QUESTIONS_PATH) as f:
        return json.load(f)


def get_existing_text_set(questions: list[dict], mode: str, band: str) -> set[str]:
    return {q["question"].lower().strip() for q in questions
            if q["mode"] == mode and q["difficultyBand"] == band}


def get_count(questions: list[dict], mode: str, band: str) -> int:
    return sum(1 for q in questions if q["mode"] == mode and q["difficultyBand"] == band)


def get_max_index(questions: list[dict], mode: str, band: str) -> int:
    max_idx = 0
    band_clean = band.replace("-", "-")
    for q in questions:
        if q["mode"] == mode and q["difficultyBand"] == band:
            m = re.search(r"_(\d+)$", q["id"])
            if m:
                max_idx = max(max_idx, int(m.group(1)))
    return max_idx


def get_sample_questions(questions: list[dict], mode: str, band: str, n: int = 5) -> list[dict]:
    matching = [q for q in questions if q["mode"] == mode and q["difficultyBand"] == band]
    return matching[:n]


def generate_batch(mode: str, band: str, count: int, existing_questions: list[str], samples: list[dict]) -> list[dict]:
    """Call Claude Haiku to generate `count` questions for the given mode/band."""
    sample_text = json.dumps(samples, indent=2) if samples else "[]"
    existing_sample = "\n".join(f"- {q}" for q in existing_questions[:20]) if existing_questions else "(none yet)"

    prompt = f"""You are generating questions for Parlance, an AI speech coaching iOS app.

MODE: {mode}
CONTEXT: {MODE_CONTEXT[mode]}

DIFFICULTY BAND: {band}
DIFFICULTY DESCRIPTION: {BAND_DESCRIPTIONS[band]}

TARGET DURATION: {TARGET_DURATIONS[mode][band]} seconds

EXISTING QUESTIONS FOR THIS COMBINATION (do NOT repeat these):
{existing_sample}

SAMPLE QUESTIONS (for format reference only):
{sample_text}

Generate exactly {count} NEW and DIVERSE questions for this mode/band combination.

Requirements:
1. Each question must be meaningfully different from ALL existing questions listed above
2. Match the difficulty level described — not too easy, not too hard for the band
3. Cover diverse scenarios, industries, and contexts across the batch
4. Each question should be a single clear prompt (1-3 sentences)
5. Tips must be specific, actionable coaching advice (not generic)
6. difficultyNote: brief phrase describing what makes this question appropriate for the band (under 10 words)
7. Do NOT include a targetDuration field — it will be added automatically

Return ONLY a JSON array, no other text:
[
  {{
    "question": "...",
    "tips": ["...", "...", "..."],
    "difficultyNote": "..."
  }},
  ...
]"""

    response = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=8000,
        messages=[{"role": "user", "content": prompt}]
    )

    text = response.content[0].text.strip()
    # Extract JSON array from response
    start = text.find("[")
    end = text.rfind("]") + 1
    if start == -1 or end == 0:
        print(f"  WARNING: No JSON array found in response for {mode}/{band}")
        return []

    try:
        questions = json.loads(text[start:end])
    except json.JSONDecodeError as e:
        print(f"  WARNING: JSON parse error for {mode}/{band}: {e}")
        return []

    return questions


def review_question(q: dict, mode: str, band: str, existing_texts: set[str]) -> bool:
    """
    Review a generated question for quality. Returns True if it passes.
    Checks:
    - Has required fields
    - Question is not a duplicate
    - Tips list has exactly 3 items
    - Nothing is empty
    """
    if not isinstance(q, dict):
        return False
    if "question" not in q or "tips" not in q or "difficultyNote" not in q:
        return False
    if not q["question"] or not q["difficultyNote"]:
        return False
    if not isinstance(q["tips"], list) or len(q["tips"]) != 3:
        return False
    if any(not tip for tip in q["tips"]):
        return False
    if q["question"].lower().strip() in existing_texts:
        return False
    return True


def main():
    print("Loading existing questions...")
    existing = load_existing()
    print(f"  Loaded {len(existing)} questions")

    # Track all questions including newly generated ones
    all_questions = list(existing)
    new_questions = []

    # Determine what needs to be generated
    work = []
    for mode in TARGETS:
        target = TARGETS[mode]
        for band in BANDS:
            current = get_count(all_questions, mode, band)
            needed = target - current
            if needed > 0:
                work.append((mode, band, needed))

    total_needed = sum(n for _, _, n in work)
    print(f"\nTotal new questions to generate: {total_needed}")
    print(f"Combinations to fill: {len(work)}\n")

    done = 0
    for mode, band, needed in work:
        print(f"[{done+1}/{len(work)}] {mode}/{band}: generating {needed} questions...", end=" ", flush=True)

        max_idx = get_max_index(all_questions, mode, band)
        existing_texts = get_existing_text_set(all_questions, mode, band)
        samples = get_sample_questions(existing, mode, band)

        generated_for_combo = []
        attempts = 0
        batch_size = 20

        while len(generated_for_combo) < needed and attempts < 5:
            remaining = needed - len(generated_for_combo)
            request_count = min(batch_size, remaining + 3)  # Request a few extra to account for rejects

            try:
                batch = generate_batch(mode, band, request_count, list(existing_texts), samples)
            except Exception as e:
                print(f"\n  ERROR calling API: {e}")
                attempts += 1
                time.sleep(2)
                continue

            for q in batch:
                if len(generated_for_combo) >= needed:
                    break

                # Review quality
                if not review_question(q, mode, band, existing_texts):
                    continue

                # Assign ID
                max_idx += 1
                q_id = f"{mode}_{band}_{max_idx:03d}"
                full_q = {
                    "id": q_id,
                    "mode": mode,
                    "difficultyBand": band,
                    "question": q["question"],
                    "tips": q["tips"],
                    "targetDuration": TARGET_DURATIONS[mode][band],
                    "difficultyNote": q["difficultyNote"],
                }

                generated_for_combo.append(full_q)
                existing_texts.add(q["question"].lower().strip())
                all_questions.append(full_q)
                new_questions.append(full_q)

            attempts += 1

            if len(generated_for_combo) < needed:
                # Still need more — loop again
                pass

        print(f"got {len(generated_for_combo)}/{needed}")
        done += 1

        # Small pause to avoid rate limiting
        time.sleep(0.3)

    print(f"\n✓ Generated {len(new_questions)} new questions")
    print(f"✓ Total questions: {len(all_questions)}")

    # Save generated questions to separate file for inspection
    with open(OUTPUT_PATH, "w") as f:
        json.dump(new_questions, f, indent=2)
    print(f"\nNew questions saved to: {OUTPUT_PATH}")

    # Merge into questions.json
    with open(QUESTIONS_PATH, "w") as f:
        json.dump(all_questions, f, indent=2)
    print(f"Merged into: {QUESTIONS_PATH}")

    # Summary
    print("\n--- Final counts ---")
    for mode in sorted(TARGETS.keys()):
        for band in BANDS:
            count = get_count(all_questions, mode, band)
            target = TARGETS[mode]
            status = "✓" if count >= target else "✗"
            print(f"  {status} {mode}/{band}: {count}")


if __name__ == "__main__":
    main()
