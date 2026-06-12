# BuxMuse localization — Phase 3 (gaps & plumbing)

Closes the biggest remaining **English holes**: format strings, settings dynamic copy, form section headers.

## Done in this phase

| Item | Detail |
|------|--------|
| Format strings | **139** `%@` / `%lld` keys translated (`phase3-format-translations.json`) |
| Settings brain | Budget mode line, On/Off, notification subtitle use `BuxLocalizedString` + `interfaceLocale` |
| Form sections | `BuxFormSectionLabel` uses `BuxCatalogText` |
| Helpers | `BuxLocalizedString` for non-SwiftUI `String(localized:locale:)` |

## Workflow

```bash
python3 scripts/localization/merge_phase3_formats.py   # regenerate format batch
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase3-format-translations.json
```

## Verify

- **AR** country → Settings → Budgets row subtitle: `Modo: Simple · N perfiles`
- Dashboard active budget card shows Spanish amounts line
- Studio invoice / mileage screens: `%@` labels in Spanish

## Next (Phase 4+)

- Insights, Goals, Subscription hub strings
- Agreement / tax / PDF long-form content
- es-419 vs es-ES editorial pass
