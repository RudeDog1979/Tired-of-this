# Phase 8 — Full-app catalog gap fill

## Goal

Close remaining English UI for **Settings → Country/Region** (`es-419` / `es-ES`) when the device language stays English.

## What shipped

1. **`scripts/localization/extract_phase8.py`** — scans all `BuxMuse/**/*.swift`, seeds missing keys into `Localizable.xcstrings`, writes `phase8-keys.txt`.
2. **`scripts/localization/build_phase8_translations.py`** — 404 refined strings (350 gap keys + categories/pills + phase 8b).
3. **`docs/localization/phase8-translations.json`** — merge with:
   ```bash
   python3 scripts/localization/build_phase8_translations.py
   python3 scripts/localization/merge_phase1_translations.py docs/localization/phase8-translations.json
   ```
4. **Dynamic label plumbing**
   - `StudioGlassHorizontalSectionMenu` chips → `BuxCatalogText` (Home pills, Studio section menus).
   - `TransactionCategory+Localization.swift` — `localizedDisplayName(locale:)` + `ExpenseCategoryRecord.localizedDisplayName`.
   - Category chips, transaction rows, subscription category headers wired to localized names.

## Verify (Argentina / Mexico / Colombia in Settings)

- Home pills: Gastos, Suscripciones, Metas, Insights, Mapa del dinero.
- Add expense category chips in Spanish.
- Studio agreements, invoices, business card editor, backup/security settings.
- Money Map hint and territory sheets (phase 6–7).

## Remaining (phase 9+)

- Swift **interpolation** keys accidentally in catalog (e.g. `\(Int(progress * 100))%`) — replace with `BuxLocalizedString.format` in source, not more catalog entries.
- Legal/PDF agreement corpus (long-form clauses).
- Editorial pass: es-419 vs es-ES tone review on Studio tax copy.
