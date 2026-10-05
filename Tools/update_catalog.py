#!/usr/bin/env python3
"""Merges editable text lists into Localizable.xcstrings.

- Tools/reactions.json   -> reaction.<category>.<n>   (reaction lines)
- Tools/house_rules.json -> houseRule.default.<n>     (built-in house-rule cards)

Numbers are 1-based. Generated keys are replaced; every other catalog
entry is left untouched.

    python3 Tools/update_catalog.py
"""
import json
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
CATALOG = TOOLS.parent / "BlindTen" / "Resources" / "Localizable.xcstrings"

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


def entry(comment, value):
    return {
        "comment": comment,
        "extractionState": "manual",
        "localizations": {"en": {"stringUnit": {"state": "translated", "value": value}}},
    }


catalog = json.loads(CATALOG.read_text())
strings = {
    k: v for k, v in catalog["strings"].items()
    if not k.startswith("reaction.") and not k.startswith("houseRule.default.")
}

for category, lines in json.loads((TOOLS / "reactions.json").read_text()).items():
    for number, line in enumerate(lines, start=1):
        strings[f"reaction.{category}.{number}"] = entry(
            f"Funny one-line reaction shown after {LABELS[category]}.", line
        )

for number, rule in enumerate(json.loads((TOOLS / "house_rules.json").read_text()), start=1):
    strings[f"houseRule.default.{number}"] = entry(
        "Built-in house-rule card the round loser may draw. Keep it neutral and alcohol-free.", rule
    )

catalog["strings"] = dict(sorted(strings.items()))
CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
reactions = sum(k.startswith("reaction.") for k in strings)
rules = sum(k.startswith("houseRule.default.") for k in strings)
print(f"{reactions} reaction lines and {rules} house rules in {CATALOG.name}")
