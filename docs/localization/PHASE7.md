# BuxMuse localization — Phase 7 (Money Map territories)

## Scope

- `MoneyMapBuilder` — all territory titles, subtitles, explanations, metric labels, deep links
- `BuxMoneyMapCopy` / `MoneyMapL10n` helpers
- Canvas orb labels via `localizedTitle`

## Workflow

```bash
python3 scripts/localization/build_phase7_translations.py
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase7-translations.json
```

## Verify

Argentina → Home → Money Map → tap **Categorías**, **Flujo de caja**, **Suscripciones** — sheet copy in Spanish.

## Remaining

- Studio Agreement / tax PDF strings (large legal corpus)
- es-419 vs es-ES editorial QA pass
