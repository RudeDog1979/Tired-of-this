#!/usr/bin/env python3
"""Extract Phase 4 strings: Insights, Goals, Subscription Hub."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUXMUSE = ROOT / "BuxMuse"

DIRS = [
    BUXMUSE / "Features/Insights",
    BUXMUSE / "Features/Goals",
    BUXMUSE / "Features/SubscriptionHub",
    BUXMUSE / "Features/Dashboard/Views/DashboardIntelligencePanels.swift",
    BUXMUSE / "Features/Dashboard/Views/MoneyMapNodeDetailSheet.swift",
]

PATTERNS = [
    re.compile(r'title:\s*"([^"]+)"'),
    re.compile(r'description:\s*"([^"]+)"'),
    re.compile(r'subtitle:\s*"([^"]+)"'),
    re.compile(r'Text\(\s*"([^"]+)"'),
    re.compile(r'navigationTitle\(\s*"([^"]+)"'),
    re.compile(r'BuxDetailSectionHeader\(title:\s*"([^"]+)"'),
    re.compile(r'BuxDetailOverlayScaffold\(title:\s*"([^"]+)"'),
]

SKIP = {"On", "Off", "OK", "PRO", "Studio", "BuxMuse", "Bux Canvas"}


def skip(s: str) -> bool:
    if len(s) < 2 or s in SKIP:
        return True
    if "\\(" in s or "$(" in s:
        return True
    if "%" in s and "@" not in s and "lld" not in s:
        return False  # allow format keys
    if "%@" in s or "%lld" in s:
        return False
    if s.startswith("$") or s == "/month":
        return False
    return False


def collect() -> list[str]:
    keys: set[str] = set()
    files: list[Path] = []
    for d in DIRS:
        if d.is_file():
            files.append(d)
        else:
            files.extend(d.rglob("*.swift"))
    for path in files:
        text = path.read_text(encoding="utf-8", errors="ignore")
        for pat in PATTERNS:
            for m in pat.finditer(text):
                v = m.group(1).strip()
                if not skip(v):
                    keys.add(v)
    # Known insight format templates (not in source as literals)
    keys.update([
        "%lld expenses this month have no workspace.",
        "Possible double charge for %@.",
        "%@ increased their price.",
        "You haven't logged in to %@ recently.",
        "Reach your %@ goal sooner.",
        "You paid more at %@.",
        "A refund from %@ has cleared.",
        "%@ Overspend",
        "You spent more on %@ this month.",
        "Excellent job limiting your %@ budget.",
        "%@ Optimization",
        "You're on track to achieve '%@'.",
        "Timeline risk detected for '%@'.",
        "%lld tagged expenses used credit or store credit this period.",
        "Enable payment tagging in Settings",
        "Enable in Studio → Cash & Barter",
        "Enable Studio first",
        "Log non-cash exchanges",
        "Separate gigs or departments",
        "Hours & revision guardrails",
    ])
    return sorted(keys)


def main() -> None:
    keys = collect()
    out = ROOT / "docs/localization/phase4-keys.txt"
    out.write_text("\n".join(keys) + "\n", encoding="utf-8")
    print(f"Wrote {len(keys)} keys to {out}")


if __name__ == "__main__":
    main()
