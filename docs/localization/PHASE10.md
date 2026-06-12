# Phase 10 — Studio hub, projects, locale refresh

## What shipped

### Studio Freelance Hub (`StudioHubSections.swift`)
- All interpolated dashboard copy uses `BuxLocalizedString.format` + `BuxCatalogText` for static labels.
- Metrics: effective tax %, burn/mo, invoice counts, next due, LTV/health, projects, receipts, empty states.

### Studio projects (`StudioProjectViews.swift`)
- Billing line, ended date, scope hours, revisions, effective hourly rate, lap labels.

### Settings region (`RegionCurrencySettingsView.swift`)
- App language chips and country/currency confirmation message.

### Goal locale refresh
- `GoalsEngine.invalidateLocalizedCaches(andRecalculate:)` on **Country/Region** change (`AppContainer`).
- `GoalsViewModel.refreshSelectedDetailIfNeeded()` + `objectWillChange` sink to refresh open goal sheet.

### Catalog
- `build_phase10_translations.py` → merge `phase10-translations.json` (metric + format keys).

## Verify
Settings → Argentina → **Studio** hub cards in Spanish; open a **project** detail; change country with a goal sheet open — copy should refresh after recalc.

## Remaining
- ~50 files still use `Text("…\(…)")` (Simple Studio, invoices, expenses sheets).
- `overviewRow` long English strings in project detail (fixed-fee copy).
- Legal agreement PDF corpus.
