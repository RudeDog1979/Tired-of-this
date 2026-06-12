# Phase 15 — Massive Spanish UI pass (menus, chips, dynamic strings)

## Problem

Most keys already had `es-419` in `Localizable.xcstrings`, but the UI still showed English because:

1. `Text(someString)` does not consult the string catalog (only literals / `LocalizedStringKey`).
2. Sheets and pushed flows sometimes missed `\.locale` from Settings → Country.
3. Brains stored English keys in display models without resolving locale at build time.

## Fixes

### Infrastructure (`BuxCatalogText.swift`, `BuxRootTheme.swift`)

- `BuxCatalogDynamicText` — catalog lookup via `AppSettingsManager.interfaceLocale`.
- `buxCatalogNavigationTitle(_:)` — `navigationTitle` for `String` catalog keys.
- `buxInterfaceLocale()` — propagates interface locale (used on `RootView`, `buxThemedSheetContent`, Studio/Settings stacks).

### Design system & hubs

- `BuxQuickActionButton`, `BuxSheetScaffold`, `HustleSelectorBar`, Studio hub `navRow`, dashboard FAB submenu.
- `SettingsRow` trailing text; Settings drill-ins; Studio `NavigationStack` + profile menu.

### Brains (locale at generation)

- `StudioBrain` — alerts, business type subtitle, deduction copy.
- `BuxMuseBrain` — expense timeline section titles and transaction counts.

### Views

- Expenses list sections, Pro Search filters/results, Tax Studio metrics/timeline/coach, Simple Studio tiles, tips popup, spending cards.

### Catalog

- `docs/localization/phase15-translations.json` — 50 keys (timeline, tabs, alerts, filters, business types).
- Merge: `python3 scripts/localization/merge_phase1_translations.py docs/localization/phase15-translations.json`

## Verify

1. Settings → Country → Argentina (device language can stay English).
2. Studio hub: **Facturas**, **Clientes**, quick actions in Spanish.
3. Home category chips: **Gastos**, **Metas**, etc.
4. Expenses: **Hoy**, **Esta semana** section headers.
5. Settings rows and drill-in titles in Spanish.

Build: `xcodebuild -scheme BuxMuse -destination 'platform=iOS Simulator,...' build` — succeeded after Phase 15.
