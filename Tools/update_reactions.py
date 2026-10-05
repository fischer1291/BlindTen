#!/usr/bin/env python3
"""Merges Tools/reactions.json into Localizable.xcstrings.

Keys are "reaction.<category>.<n>" (1-based). Existing reaction keys are
replaced; all other catalog entries are left untouched.

    python3 Tools/update_reactions.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "BlindTen" / "Resources" / "Localizable.xcstrings"
SOURCE = Path(__file__).resolve().parent / "reactions.json"

LABELS = {
    "deadOn": "DEAD ON (within 0.05 s)",
    "sharp": "Sharp (within 0.25 s)",
    "close": "Close (within 0.50 s)",
    "meh": "Meh (within 1 s)",
    "off": "Off (within 2 s)",
    "lostInTime": "Lost in time (more than 2 s off)",
    "misfire": "a misfire (stopped before 1 s)",
    "timeout": "a timeout (never stopped)",
}

catalog = json.loads(CATALOG.read_text())
strings = {k: v for k, v in catalog["strings"].items() if not k.startswith("reaction.")}
for category, lines in json.loads(SOURCE.read_text()).items():
    for number, line in enumerate(lines, start=1):
        strings[f"reaction.{category}.{number}"] = {
            "comment": f"Funny one-line reaction shown after {LABELS[category]}.",
            "extractionState": "manual",
            "localizations": {"en": {"stringUnit": {"state": "translated", "value": line}}},
        }
catalog["strings"] = dict(sorted(strings.items()))
CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
print(f"{sum(k.startswith('reaction.') for k in strings)} reaction lines in {CATALOG.name}")
