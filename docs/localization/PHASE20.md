# Phase 20 — Full-app interface locale sweep

## Root cause

`BuxCatalogText.text()` used `LocalizedStringKey`, which follows **device language**, not Settings → Country. That is why pills, “Recent transactions”, hero labels, and most section headers stayed English with Argentina selected.

## Engine fix

- `BuxCatalogText.text(_:)` now returns **`BuxCatalogDynamicText`** (reads `appSettingsManager.interfaceLocale`).
- `buxCatalogNavigationTitle` uses explicit catalog lookup.
- Automated sweep: **`scripts/localization/replace_text_literals.py`** — `Text("…")` → `BuxCatalogDynamicText` across Features, Components, DesignSystem (~467 replacements).

## Catalog

- **Custom** → **Personalizado** (was “Costumbre”).
- Added **Envelope**, theme names, accent colors, budgeting/settings chrome (`phase20-full-app-chrome.json`, 92 keys merged).

## Themes / profile

- `AppTheme.localizedName(locale:)`
- `BuxSystemAccent.localizedDisplayName(locale:)`
- Appearance summary in Settings uses interface locale.

## Merge

```bash
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase20-full-app-chrome.json
```

## Verify

Settings → Argentina (or any LATAM country), **device language English**:

- Dashboard pills: Gastos, Suscripciones, Metas, Perspectivas, Mapa del dinero
- Recent transactions, monthly summary, budget card, FAB
- Presupuestos: Sencillo / Sobres / **Personalizado**
- Perfil → Apariencia: theme + accent names in Spanish

Merchant names, goal names, and user-entered text must stay unchanged.
