#!/usr/bin/env python3
"""Checks AppStore/metadata.md against App Store Connect character limits."""
import re
from pathlib import Path

LIMITS = {
    "Name (max 30)": 30,
    "Subtitle (max 30)": 30,
    "Promotional text (max 170)": 170,
    "Description (max 4000)": 4000,
    "Keywords (max 100, comma separated, no spaces after commas)": 100,
}

text = (Path(__file__).resolve().parent.parent / "AppStore" / "metadata.md").read_text()
ok = True
for heading, limit in LIMITS.items():
    match = re.search(rf"## {re.escape(heading)}\n\n```\n(.*?)\n```", text, re.S)
    if not match:
        print(f"MISSING  {heading}")
        ok = False
        continue
    length = len(match.group(1))
    status = "ok" if length <= limit else "TOO LONG"
    ok = ok and length <= limit
    print(f"{status:8} {length:4}/{limit}  {heading.split(' (')[0]}")
raise SystemExit(0 if ok else 1)
