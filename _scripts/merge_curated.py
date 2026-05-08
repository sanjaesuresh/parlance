"""Merge reviewer rewrites and curated new prompts into the main question bank.

Reads:
  ParlanceApp/Features/Resources/questions.json (main bank)
  _scripts/review_*.json                         (rewrites from reviewers)
  _scripts/curated_*.json                        (new prompts from curators)

Writes:
  ParlanceApp/Features/Resources/questions.json (in place)
  _scripts/merge_report.txt                      (summary)

Conservative: validates schema + ID uniqueness before writing. Aborts on conflict.
"""
import json
import os
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN = ROOT / "ParlanceApp/Features/Resources/questions.json"
SCRIPTS = ROOT / "_scripts"
REPORT = SCRIPTS / "merge_report.txt"

REQUIRED_FIELDS = {"id", "mode", "difficultyBand", "question", "tips", "targetDuration", "difficultyNote"}
VALID_MODES = {"interview", "pitch", "keynote", "casual", "debate", "storytelling", "explanation", "negotiation", "impromptu", "networking"}
VALID_BANDS = {"1-2", "3-4", "5-6", "7-8", "9-10"}
DURATION_BY = {
    ("casual", "1-2"): 60, ("casual", "3-4"): 90, ("casual", "5-6"): 90, ("casual", "7-8"): 120, ("casual", "9-10"): 120,
    ("debate", "1-2"): 45, ("debate", "3-4"): 60, ("debate", "5-6"): 75, ("debate", "7-8"): 90, ("debate", "9-10"): 120,
    ("explanation", "1-2"): 45, ("explanation", "3-4"): 60, ("explanation", "5-6"): 75, ("explanation", "7-8"): 90, ("explanation", "9-10"): 120,
    ("impromptu", "1-2"): 30, ("impromptu", "3-4"): 45, ("impromptu", "5-6"): 60, ("impromptu", "7-8"): 75, ("impromptu", "9-10"): 90,
    ("interview", "1-2"): 60, ("interview", "3-4"): 90, ("interview", "5-6"): 90, ("interview", "7-8"): 120, ("interview", "9-10"): 120,
    ("keynote", "1-2"): 60, ("keynote", "3-4"): 90, ("keynote", "5-6"): 90, ("keynote", "7-8"): 120, ("keynote", "9-10"): 120,
    ("negotiation", "1-2"): 45, ("negotiation", "3-4"): 60, ("negotiation", "5-6"): 75, ("negotiation", "7-8"): 90, ("negotiation", "9-10"): 120,
    ("networking", "1-2"): 30, ("networking", "3-4"): 45, ("networking", "5-6"): 60, ("networking", "7-8"): 75, ("networking", "9-10"): 90,
    ("pitch", "1-2"): 60, ("pitch", "3-4"): 90, ("pitch", "5-6"): 90, ("pitch", "7-8"): 120, ("pitch", "9-10"): 120,
    ("storytelling", "1-2"): 45, ("storytelling", "3-4"): 60, ("storytelling", "5-6"): 75, ("storytelling", "7-8"): 90, ("storytelling", "9-10"): 120,
}


def load_main():
    with open(MAIN) as f:
        return json.load(f)


def apply_reviews(bank, dry_run=False):
    """Apply all _scripts/review_*.json rewrites to bank in place. Returns (applied_count, missing_ids, errors)."""
    by_id = {q["id"]: q for q in bank}
    applied = 0
    missing = []
    errors = []
    for path in sorted(SCRIPTS.glob("review_*.json")):
        with open(path) as f:
            try:
                edits = json.load(f)
            except Exception as e:
                errors.append(f"{path.name}: invalid JSON: {e}")
                continue
        for edit in edits:
            qid = edit.get("id")
            if not qid:
                errors.append(f"{path.name}: edit missing id: {edit}")
                continue
            target = by_id.get(qid)
            if not target:
                missing.append((path.name, qid))
                continue
            new_q = edit.get("suggested_rewrite")
            if new_q and new_q.strip():
                target["question"] = new_q.strip()
                applied += 1
            new_tips = edit.get("new_tips")
            if new_tips and isinstance(new_tips, list) and len(new_tips) >= 1:
                target["tips"] = [t.strip() for t in new_tips if t and t.strip()][:3]
    return applied, missing, errors


def append_curated(bank):
    """Append entries from _scripts/curated_*.json. Validates schema and IDs. Returns (added_count, by_mode_band_count, errors)."""
    existing_ids = {q["id"] for q in bank}
    added = 0
    by_combo = Counter()
    errors = []
    for path in sorted(SCRIPTS.glob("curated_*.json")):
        with open(path) as f:
            try:
                items = json.load(f)
            except Exception as e:
                errors.append(f"{path.name}: invalid JSON: {e}")
                continue
        for entry in items:
            missing = REQUIRED_FIELDS - set(entry.keys())
            if missing:
                errors.append(f"{path.name}/{entry.get('id', '?')}: missing fields {missing}")
                continue
            if entry["mode"] not in VALID_MODES:
                errors.append(f"{path.name}/{entry['id']}: invalid mode {entry['mode']}")
                continue
            if entry["difficultyBand"] not in VALID_BANDS:
                errors.append(f"{path.name}/{entry['id']}: invalid band {entry['difficultyBand']}")
                continue
            expected_dur = DURATION_BY[(entry["mode"], entry["difficultyBand"])]
            if entry["targetDuration"] != expected_dur:
                errors.append(f"{path.name}/{entry['id']}: targetDuration {entry['targetDuration']} != {expected_dur} for {entry['mode']} {entry['difficultyBand']}")
                continue
            if not isinstance(entry["tips"], list) or len(entry["tips"]) != 3:
                errors.append(f"{path.name}/{entry['id']}: tips must be a list of 3")
                continue
            if entry["id"] in existing_ids:
                errors.append(f"{path.name}/{entry['id']}: id collision")
                continue
            existing_ids.add(entry["id"])
            bank.append(entry)
            added += 1
            by_combo[(entry["mode"], entry["difficultyBand"])] += 1
    return added, by_combo, errors


def main():
    args = set(sys.argv[1:])
    dry_run = "--dry-run" in args

    bank = load_main()
    pre_count = len(bank)
    pre_combo = Counter((q["mode"], q["difficultyBand"]) for q in bank)

    applied, missing, review_errors = apply_reviews(bank)
    added, added_combo, append_errors = append_curated(bank)

    post_count = len(bank)
    post_combo = Counter((q["mode"], q["difficultyBand"]) for q in bank)

    lines = []
    lines.append(f"Pre-merge total: {pre_count}")
    lines.append(f"Rewrites applied: {applied}")
    if missing:
        lines.append(f"Rewrites referencing unknown IDs: {len(missing)}")
        for fn, qid in missing[:20]:
            lines.append(f"  {fn} -> {qid}")
    if review_errors:
        lines.append(f"Review errors: {len(review_errors)}")
        for e in review_errors[:20]:
            lines.append(f"  {e}")
    lines.append(f"New prompts appended: {added}")
    if append_errors:
        lines.append(f"Append errors (rejected): {len(append_errors)}")
        for e in append_errors[:30]:
            lines.append(f"  {e}")
    lines.append(f"Post-merge total: {post_count}")
    lines.append("")
    lines.append("Per-mode/band counts after merge:")
    for combo in sorted(post_combo):
        delta = post_combo[combo] - pre_combo.get(combo, 0)
        delta_str = f" (+{delta})" if delta else ""
        lines.append(f"  {combo}: {post_combo[combo]}{delta_str}")

    REPORT.write_text("\n".join(lines))
    print("\n".join(lines))

    if dry_run:
        print("\n[dry-run] Skipping write to main bank.")
        return 0

    has_blocking_errors = bool(review_errors or append_errors)
    if has_blocking_errors and "--force" not in args:
        print("\nBlocking errors found. Re-run with --force to ignore (rejected entries are dropped).")
        return 1

    with open(MAIN, "w") as f:
        json.dump(bank, f, indent=2, ensure_ascii=False)
    print(f"\nWrote {MAIN}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
