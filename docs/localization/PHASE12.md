# Phase 12 — Invoice designer, agreements, tax & settings polish

## Scope

Wire **remaining interpolated `Text`** to `BuxLocalizedString.format` using keys already in Phase 11 plus new Phase 12 catalog entries.

## Areas

- `InvoiceDesignerHubView` — project picker, qty line, branding match, tax rate row, live preview label
- `InvoiceTemplateViews` — Issued/Due dates on executive template (PDF)
- `AgreementScratchpadEditorView` — fill from job/project, signed date
- `StudioTaxReferenceView` — region banner, preset review sheet
- Settings: region picker subtitle, studio settings, budget, dual cash drawer, burnout, backup progress
- Expenses: cash picker display labels, subscription reminder copy
- Simple Studio: insights counts, people rows, search result count
- `HustleSelectorBar`, `ProStudioSearchView`, mileage allowance strings

## Merge

```bash
python3 scripts/localization/build_phase12_translations.py
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase12-translations.json
```

## Verify

Argentina (or any `es-419` country) in Settings → Region, device language English:

- Studio → invoice designer picker lines and tax rows
- Agreement editor “Completar desde…” / “Firmado · …”
- Tax reference banner and preset review title
- Expenses cash picker shows “Efectivo (ARS)” with English tags unchanged
