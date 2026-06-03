# Phase 14 — Why English still appeared (root cause fix)

## Root cause

Static `Text("Home")` respects `environment(\.locale)` and the catalog.

**`Text(variable)` where `variable` is an enum `rawValue` or dynamic English string does not** — SwiftUI treats it as opaque text, so Argentina + device English still showed `"Draft"`, `"Active"`, `"Off"`, etc.

## Fixes

1. **`BuxCatalogLabel`** + `RawRepresentable.catalogLabel(locale:)` — localize any English key at display time.
2. **Wired 40+ screens** that used `.rawValue` in `Text`, `Button`, `Label`, and pickers (invoices, projects, receipts, tax, settings, search).
3. **Dashboard feature strips** — `localizedValue` for strip metrics; dynamic burnout subtitle uses format keys.
4. **Country change** — `AppContainer` now calls `insightsViewModel.recalculate()` and `studioBrain.refreshAll()` so brain copy regenerates in the new locale.
5. **66 catalog keys** for enums, strips, and missing labels (`phase14-translations.json`).

## Verify (Argentina, device English)

1. Settings → Currency & Region → **Argentina** (not only currency).
2. Force-quit and reopen, or pull to refresh home insights.
3. Check: invoice status chips **Borrador/Enviado**, Studio search sections **Clientes/Facturas**, dashboard strips **Desactivado** vs **Off**, tax income **Autónomo**.

## Remaining (lower volume)

- Agreement/PDF long-form legal prose
- Some brain messages only refresh after data change or country switch (now triggered on country change)
- Numeric-only labels (quantities, sliders) stay as numbers
