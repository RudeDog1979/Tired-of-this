# Phase 34 — Spending Trends (full-screen analytics + merchant drill-down)

## Scope

All user-facing copy in `Features/SpendingTrends/`:

- Period picker (Week / Month / Year)
- Hero total + comparison strings
- By Category / By Merchant breakdown
- Bar-bucket drill-down empty states
- Merchant detail (totals, transaction history, empty states)

## Rules (Phase 0)

- English keys in `Localizable.xcstrings`; UI resolves via `BuxCatalogDynamicText` / `BuxLocalizedString` + Settings → Country locale.
- Informal **tú**; `es-419` + `es-ES`.
- Do not translate stored merchant names, category IDs, or user-entered transaction text.

## Merge

```bash
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase34-spending-trends-translations.json
```

## Verify

1. Settings → Country → Argentina (device language can stay English).
2. Expenses hero → Monthly Summary → full-screen Spending Trends.
3. Nav title **Análisis de gasto**, segments **Semana / Mes / Año**, toggle **Por categoría / Por comercio**.
4. Tap a merchant → **Total este mes**, **Historial de transacciones**, row counts **N transacciones**.
