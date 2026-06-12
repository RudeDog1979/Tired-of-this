# BuxMuse localization — Phase 2 (Studio + Bux Canvas)

Studio hub, Simple Studio, Business Card Studio, and **Bux Canvas** editor chrome.

## Scope

| Area | Paths |
|------|--------|
| Studio hub | `Features/Studio/Views/**` |
| Simple Studio | `Features/Studio/Simple/Views/**` |
| Business Card / Canvas | `Features/Studio/BusinessCard/**` |
| Project planner (shell) | `Features/Studio/Planner/**` |

## Workflow

```bash
python3 scripts/localization/extract_phase2.py
# edit docs/localization/phase2-translations.json
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase2-translations.json
```

Same merge script as Phase 1; glossary unchanged (`.baoyu-skills/baoyu-translate/EXTEND.md`).

## Status

- **630** Studio / Bux Canvas strings merged (`phase2-translations-full.json`)
- **4** keys intentionally untranslated (`Aa`, `To`, `Up`, `mi` — UI symbols)

## Verify

Country **Argentina** → open **Studio** tab and **Bux Canvas** from Card Studio. Chrome (Exit, Safe zone, Reset zoom, Elements) should follow Spanish where translated.

```bash
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase2-translations-full.json
```
