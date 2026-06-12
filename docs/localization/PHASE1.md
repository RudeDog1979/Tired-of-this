# BuxMuse localization — Phase 1 (shell UI)

Phase 1 localizes **Home, Expenses, and Settings** shell copy. No feature-logic changes.

## Scope

| Area | Paths |
|------|--------|
| Settings | `Features/Settings/**` |
| Dashboard (Home) | `Features/Dashboard/**` |
| Expenses | `Features/ExpenseInput/**` |
| Shared chrome | `BuxSectionHeader`, `BuxButton`, settings rows |

## How UI language is chosen

**Settings → Currency & Region → Country** drives `AppSettingsManager.interfaceLocale` (not the iPhone language). See `BuxInterfaceLocale.swift`.

## String catalog plumbing

- SwiftUI literals: `Text("Home")`, `navigationTitle("Settings")` — auto-extracted.
- Dynamic labels (Settings brain, buttons): use **`BuxCatalogText.text(_:)`** so plain `String` keys still resolve in the catalog.

## Workflow

```bash
# 1. Refresh extracted keys
python3 scripts/localization/extract_phase1.py

# 2. Edit or generate translations
#    docs/localization/phase1-translations.json  (es-419 + es-ES per key)

# 3. Merge into Localizable.xcstrings
python3 scripts/localization/merge_phase1_translations.py
```

Glossary: `.baoyu-skills/baoyu-translate/EXTEND.md`

## Verify

1. Set country to **Argentina** (or Mexico) in Settings → Currency & Region.
2. Tab bar: **Inicio**, **Gastos**, **Studio**, **Ajustes**.
3. Settings rows and Expenses empty state should show Spanish where translated.
4. iPhone can stay in English — region drives app UI.

## Status

- **~508** static shell strings merged into `Localizable.xcstrings` (`phase1-translations.json`)
- **Format strings** for dashboard budget card (`Active budget: %@`, `%@ left of %@`, `%lld%% spent`, budgeting-mode paragraph) translated
- `BudgetingMode.localizedDisplayName` so mode names localize inside `%@` sentences
- **~89** keys with Swift interpolation in source still need catalog `%@` keys over time
- Dynamic settings subtitles (user names, counts) stay as composed English for now

## Phase 2

Studio + Bux Canvas — [PHASE2.md](PHASE2.md) (done)

## Phase 3

Format strings & settings plumbing — [PHASE3.md](PHASE3.md) (done)

## Out of scope (Phase 2+)

- Studio Pro / Bux Canvas deep screens
- Interpolated strings (`\(variable)` in literals) — need separate catalog keys with `%@`
- User-entered merchant names, notes, JSON/tax content
