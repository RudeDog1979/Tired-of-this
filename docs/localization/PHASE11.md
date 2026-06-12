# Phase 11 — Simple Studio, projects, clients, planner

## Scope

Wired **dynamic `Text`** and **overview labels** across high-traffic Studio Simple + Pro surfaces.

### Areas
- **Project detail** — revenue model copy, revisions, budget hours, overview row labels (`BuxCatalogText`)
- **Simple Studio** — My Money job pockets, waiting/owe rows, log time planner
- **Studio hub clients** — LTV, health score, payment days, project time entries
- **Project planner** — health ring, budget hours, milestone dependencies
- **Invoices** — count, late risk, template line
- **Expenses** — merchant hint, barter estimated value
- **Settings** — country/currency flag rows
- **Home widget** — Studio runway card

### Catalog
`build_phase11_translations.py` → `phase11-translations.json` (~50 format keys).

```bash
python3 scripts/localization/build_phase11_translations.py
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase11-translations.json
```

## Verify (es-419 country)
Studio → Simple **My money** / waiting list; open a **project** overview; **Currency & Region**; create **expense** barter section.

## Remaining
- Picker tags that embed currency codes (cash drawer) — internal tag strings stay English for matching
- Invoice designer hub, agreement scratchpad, tax reference long copy
- `Text("literal")` static labels in AddExpense (catalog keys exist; use environment locale)
