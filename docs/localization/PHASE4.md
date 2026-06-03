# BuxMuse localization — Phase 4 (Insights, Goals, Subscription Hub)

## Scope

- `Features/Insights/**` — insight titles, descriptions, detail sheet
- `Features/Goals/**` — goal detail UI
- `Features/SubscriptionHub/**`
- Dashboard intelligence panels (top insights + feature strips)

## Plumbing

| Component | Role |
|-----------|------|
| `BuxInterfaceLocale.currentInterfaceLocale` | Reads persisted country (same as Settings) |
| `BuxInsightCopy` / `FinancialInsight.localizedTitle` | Catalog lookup at display time |
| Insight engines | Dynamic lines use `BuxLocalizedString.format` at generation |

## Workflow

```bash
python3 scripts/localization/extract_phase4.py
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase4-translations.json
```

## UI wiring (done)

- `SubscriptionHubSectionHeader` → `BuxCatalogText` (all hub + goal section headers)
- `BuxDetailOverlayScaffold.localizeTitle` — catalog titles vs merchant names
- Subscription Hub views: burn rate, timeline, risks, opportunities, category, overview formats
- `GoalDetailView`: operations, formats (`Target`, `Health Score`, `Delay Risk`, `Status`, `Fix`, etc.)
- Merged catalog keys: `Edit Goal`, `Metric Details`, `Save Money`, `saved` (`phase4-missing.json`)

## Verify

Country **Argentina** → Home **Top insights** + **Subscription Hub** + **Goal Details** should show Spanish titles/descriptions.

Still English (Phase 5+): engine `fullExplanation` / `suggestedActions`, subscription cancellation copy, scenario names from brain.
