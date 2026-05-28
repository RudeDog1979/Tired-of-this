#!/usr/bin/env python3
"""
Daily buxmuse_news.json generator — one Gemini call, all language locales.

Setup:
  export GIST_TOKEN="github_pat_..."
  export GEMINI_API_KEY="..."

Run:
  python3 scripts/update_buxmuse_news.py

Architecture:
  • Gemini generates ~21 LOCALE blocks (ES, PT, FR, IN, …) — NOT 200 countries.
  • buxmuse_country_map.json maps every ISO country → locale (generated separately).
  • iOS app: country flag + locale content from buxmuse_news.json.

Regenerate country map after editing language groups:
  python3 scripts/generate_country_map.py
"""

from __future__ import annotations

import json
import os
import random
import traceback
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

GIST_TOKEN = os.environ.get("GIST_TOKEN")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
GIST_ID = "ed398f2397ca1a86ec6a53a1d72fb86a"

ROOT = Path(__file__).resolve().parents[1]
LOCALE_MAP_PATH = ROOT / "BuxMuse" / "Resources" / "buxmuse_country_map.json"

if not GIST_TOKEN or not GEMINI_API_KEY:
    print("❌ Fatal: Missing GIST_TOKEN or GEMINI_API_KEY environment variables.")
    raise SystemExit(1)

# ── Locale keys = keys in buxmuse_news.json "regions" object ──
# Must stay in sync with generate_country_map.py CONTENT_LOCALES
CONTENT_LOCALES = [
    "ES", "PL", "FR", "DE", "PT", "IT", "NL", "SE", "NO", "DK", "FI",
    "RU", "UA", "TR", "JP", "KR", "CN", "AE", "IN", "US", "DEFAULT",
]

LOCALE_LANGUAGE = {
    "ES": "Spanish",
    "PL": "Polish",
    "FR": "French",
    "DE": "German",
    "PT": "Portuguese (Brazil & Portugal voice)",
    "IT": "Italian",
    "NL": "Dutch",
    "SE": "Swedish",
    "NO": "Norwegian",
    "DK": "Danish",
    "FI": "Finnish",
    "RU": "Russian",
    "UA": "Ukrainian",
    "TR": "Turkish",
    "JP": "Japanese",
    "KR": "Korean",
    "CN": "Chinese (Simplified)",
    "AE": "Arabic (Modern Standard)",
    "IN": "Hindi",
    "US": "English (United States)",
    "DEFAULT": "English (International / UK Commonwealth)",
}

topics = [
    "identifying and eliminating hidden digital subscriptions",
    "reducing energy consumption and lowering utility bills",
    "the math behind grocery bulk buying vs unit pricing",
    "tricks to overcome impulse buying and psychological spending traps",
    "travel hacking, booking timing, and avoiding sneaky airline fees",
    "tactics for negotiating internet, phone, and insurance bills",
    "maximizing daily cashback and avoiding credit card interest traps",
    "using the 30-day rule to stop unnecessary retail purchases",
    "second-hand market flipping and buying refurbished electronics",
    "optimizing daily food expenses without sacrificing quality",
]
chosen_topic = random.choice(topics)


def locale_rules_block() -> str:
    lines = [
        "CRITICAL LANGUAGE RULES — YOU MUST OBEY ALL OF THESE:",
        "1. Each key below is a CONTENT LOCALE, not a single country.",
        "2. Write ALL text for that locale ONLY in the language shown.",
        "3. Never use English inside non-English locales (except brand names).",
        "4. Portuguese (PT) must serve Brazil AND Portugal — neutral wording.",
        "5. Arabic (AE) must serve all Arabic-speaking countries — Modern Standard Arabic.",
        "6. DEFAULT = British/international English; US = American English.",
        "",
        "LOCALE → REQUIRED LANGUAGE:",
    ]
    for key in CONTENT_LOCALES:
        lines.append(f"  • {key} = {LOCALE_LANGUAGE[key]}")
    return "\n".join(lines)


def build_prompt() -> str:
    return f"""
You are generating buxmuse_news.json for a global personal finance app.

Today's date context: {datetime.now(timezone.utc).strftime("%Y-%m-%d")}.

CRITICAL CONTENT RULES:
1. "home_tip": Daily Money-Saving Tip. MUST focus on: '{chosen_topic}'.
   Actionable, specific, max 2 sentences. NOT generic advice.
2. "scam": Current financial scam relevant to that language region.
3. "alert": Secondary cyber-security or banking alert.
4. "ticker": Exactly 2 short breaking-news-style finance headlines.

{locale_rules_block()}

OUTPUT: Valid JSON matching the schema. Every locale key is REQUIRED.
Generate fresh, non-repetitive content for each locale today.
""".strip()


def build_region_schema() -> dict:
    return {
        "type": "OBJECT",
        "properties": {
            "home_tip": {
                "type": "STRING",
                "description": "Money-saving tip in the locale's required language.",
            },
            "scam": {
                "type": "OBJECT",
                "properties": {
                    "title": {"type": "STRING"},
                    "desc": {"type": "STRING"},
                },
                "required": ["title", "desc"],
            },
            "alert": {
                "type": "OBJECT",
                "properties": {
                    "title": {"type": "STRING"},
                    "desc": {"type": "STRING"},
                },
                "required": ["title", "desc"],
            },
            "ticker": {
                "type": "ARRAY",
                "items": {"type": "STRING"},
                "description": "Exactly 2 ticker headlines.",
            },
        },
        "required": ["home_tip", "scam", "alert", "ticker"],
    }


def get_gemini_data() -> dict:
    gemini_url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
    )

    region_schema = build_region_schema()
    regions_properties = {key: region_schema for key in CONTENT_LOCALES}

    payload = {
        "contents": [{"parts": [{"text": build_prompt()}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": {
                "type": "OBJECT",
                "properties": {
                    "regions": {
                        "type": "OBJECT",
                        "properties": regions_properties,
                        "required": CONTENT_LOCALES,
                    }
                },
                "required": ["regions"],
            },
        },
    }

    req = urllib.request.Request(
        gemini_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as response:
        res_data = json.loads(response.read().decode("utf-8"))
        text = res_data["candidates"][0]["content"]["parts"][0]["text"]
        return json.loads(text)


def validate_locales(data: dict) -> None:
    regions = data.get("regions", {})
    missing = [k for k in CONTENT_LOCALES if k not in regions]
    if missing:
        raise ValueError(f"Gemini response missing locales: {missing}")
    for key in CONTENT_LOCALES:
        block = regions[key]
        for field in ("home_tip", "scam", "alert", "ticker"):
            if field not in block:
                raise ValueError(f"Locale {key} missing field: {field}")


def update_gist(data: dict) -> None:
    data["updatedAt"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data["version"] = data.get("version", 4)
    if "contentLocales" not in data:
        data["contentLocales"] = CONTENT_LOCALES

    gist_url = f"https://api.github.com/gists/{GIST_ID}"
    gist_payload = {
        "files": {
            "buxmuse_news.json": {
                "content": json.dumps(data, indent=2, ensure_ascii=False),
            }
        }
    }
    gist_req = urllib.request.Request(
        gist_url,
        data=json.dumps(gist_payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {GIST_TOKEN}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        },
        method="PATCH",
    )
    with urllib.request.urlopen(gist_req, timeout=60) as gist_response:
        if gist_response.status != 200:
            raise RuntimeError(f"Gist update failed: HTTP {gist_response.status}")


def main() -> None:
    print(f"🎯 Daily topic: {chosen_topic}")
    print(f"🌍 Locales ({len(CONTENT_LOCALES)}): {', '.join(CONTENT_LOCALES)}")
    if LOCALE_MAP_PATH.exists():
        m = json.loads(LOCALE_MAP_PATH.read_text(encoding="utf-8"))
        print(f"🗺️  Country map: {m['stats']['totalTerritories']} territories → locales")
    print("🤖 Calling Gemini 2.5 Flash…")
    data = get_gemini_data()
    validate_locales(data)
    print("✅ All locales present.")
    update_gist(data)
    print(f"🎉 Gist updated: https://gist.github.com/RudeDog1979/{GIST_ID}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Failed: {e}")
        traceback.print_exc()
        raise SystemExit(1)
