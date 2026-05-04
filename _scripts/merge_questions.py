#!/usr/bin/env python3
"""Merges all _scripts/new_questions_*.json files into questions.json."""
import json, re
from pathlib import Path

QUESTIONS_PATH = Path(__file__).parent.parent / "Parlance/Resources/questions.json"
SCRIPTS_DIR = Path(__file__).parent

TARGET_DURATIONS = {
    "interview": {"1-2":60,"3-4":90,"5-6":90,"7-8":120,"9-10":120},
    "pitch":     {"1-2":60,"3-4":90,"5-6":90,"7-8":120,"9-10":120},
    "keynote":   {"1-2":60,"3-4":90,"5-6":90,"7-8":120,"9-10":120},
    "casual":    {"1-2":60,"3-4":90,"5-6":90,"7-8":120,"9-10":120},
    "debate":        {"1-2":45,"3-4":60,"5-6":75,"7-8":90,"9-10":120},
    "explanation":   {"1-2":45,"3-4":60,"5-6":75,"7-8":90,"9-10":120},
    "negotiation":   {"1-2":45,"3-4":60,"5-6":75,"7-8":90,"9-10":120},
    "storytelling":  {"1-2":45,"3-4":60,"5-6":75,"7-8":90,"9-10":120},
    "impromptu":     {"1-2":30,"3-4":45,"5-6":60,"7-8":75,"9-10":90},
    "networking":    {"1-2":30,"3-4":45,"5-6":60,"7-8":75,"9-10":90},
}

with open(QUESTIONS_PATH) as f:
    data = json.load(f)

total_added = 0
for input_file in sorted(SCRIPTS_DIR.glob("new_questions_*.json")):
    mode = input_file.stem.replace("new_questions_", "")
    print(f"\nMerging {input_file.name}...")
    with open(input_file) as f:
        new_qs = json.load(f)

    # Build existing set per band
    existing = {}
    for band in ["1-2","3-4","5-6","7-8","9-10"]:
        existing[band] = {q["question"].lower().strip() for q in data
                          if q["mode"]==mode and q["difficultyBand"]==band}

    max_idx = {}
    for band in ["1-2","3-4","5-6","7-8","9-10"]:
        indices = [int(re.search(r'_(\d+)$',q["id"]).group(1))
                   for q in data if q["mode"]==mode and q["difficultyBand"]==band]
        max_idx[band] = max(indices, default=0)

    mode_added = 0
    for q in new_qs:
        band = q["difficultyBand"]
        text = q["question"].lower().strip()
        if text in existing[band]:
            print(f"  SKIP duplicate: {q['question'][:60]}")
            continue
        max_idx[band] += 1
        data.append({
            "id": f"{mode}_{band}_{max_idx[band]:03d}",
            "mode": mode,
            "difficultyBand": band,
            "question": q["question"],
            "tips": q["tips"],
            "targetDuration": TARGET_DURATIONS[mode][band],
            "difficultyNote": q["difficultyNote"],
        })
        existing[band].add(text)
        mode_added += 1

    print(f"  Added {mode_added} questions")
    total_added += mode_added

with open(QUESTIONS_PATH, "w") as f:
    json.dump(data, f, indent=2)

print(f"\nTotal added: {total_added}")
print(f"Total questions: {len(data)}")

# Print final counts
print("\n--- Final counts ---")
from collections import defaultdict
counts = defaultdict(lambda: defaultdict(int))
for q in data:
    counts[q["mode"]][q["difficultyBand"]] += 1
for mode in sorted(counts):
    for band in ["1-2","3-4","5-6","7-8","9-10"]:
        print(f"  {mode}/{band}: {counts[mode][band]}")
