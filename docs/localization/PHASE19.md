# Phase 19 — Dashboard chrome (hero, pills, FAB, insight sheet, severity)

## Scope

- Hero quick actions: catalog keys **`Gasto`** / **`Ingreso`** (short labels; `minimumScaleFactor(1.0)` on hero buttons).
- Category pill bar: English `rawValue` IDs unchanged; labels via `BuxCatalogDynamicText` in `StudioGlassHorizontalSectionMenu`.
- FAB submenu + divider: `BuxCatalogDynamicText`.
- Insight detail: `BuxDetailOverlayScaffold` + section headers use Settings locale; severity via `InsightSeverity.localizedDisplayName`.
- Burnout stress copy + `.buxInterfaceLocale()`.

## Engine fix

`BuxCatalogText.text` uses `LocalizedStringKey` (device locale). Dashboard chrome paths now use **`BuxCatalogDynamicText`** with `appSettingsManager.interfaceLocale`.

## Merge

```bash
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase19-dashboard-chrome.json
```

## Verify

Settings → Argentina, device English: hero **Gasto/Ingreso**, pills **Gastos/Suscripciones/…**, FAB Spanish, insight sheet titles/metrics/severity **bajo/medio/alto**, burnout alert Spanish. Merchant/user names unchanged.
