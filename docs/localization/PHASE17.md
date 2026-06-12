# Phase 17 — Expenses, Subscription Hub, Insights

LATAM Spanish (`es-419`) for the full expenses tab, subscription hub, and dashboard/Money Map insight strips.

## Code

- **Expenses:** `ExpenseTabView` / `ExpenseDetailView` use `.buxInterfaceLocale()`; intelligence titles via `BuxCatalogLabel`; `ExpenseDetailViewModel` passes `interfaceLocale` to brain; prediction string localized in `BuxMuseBrain`.
- **Engines:** `ExpenseIntelligenceEngine`, `EmotionalTaggingEngine`, `BillingCycleAIEngine` (Netflix/Spotify/alternatives, `appendUserDeclaredSubscriptions(locale:)`).
- **Subscription Hub:** locale on financial engine refresh (existing); hub VM copy already uses `BuxLocalizedString`.
- **Insights:** `InsightsViewModel` passes `appSettingsManager.interfaceLocale` into `FeatureInsightStripEngine.buildStrips`; strip titles/CTAs localized at build time.

## Catalog

```bash
python3 scripts/localization/build_phase17_expenses_subscriptions_insights.py
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase17-expenses-subscriptions-insights.json
```

## Verify

Argentina in Settings → Country; device English. Check Expenses tab, Subscription Hub sheet, Insights pills + detail.
