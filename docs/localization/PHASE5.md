# BuxMuse localization — Phase 5 (Insight prose + Home dashboard)

## Scope

- Insight deep-dive: `fullExplanation`, `dataBehind`, `suggestedActions`
- Home dashboard: budget card, goals pill, intelligence panels
- Goals input sheets (summary labels)
- First engine batch: `PaymentSourceInsightsEngine`, `FeatureInsightsEngines` (workspace + cash)

## Plumbing

| API | Role |
|-----|------|
| `BuxInsightCopy.copy` | Catalog lookup for full sentences |
| `FinancialInsight.localizedFullExplanation` | Display (pass-through if already localized at generation) |
| `FinancialInsight.localizedSuggestedAction` | Static action strings |
| Engines | `BuxLocalizedString.format` / `.string` at generation for prose templates |

## Workflow

```bash
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase5-translations.json
```

## Phase 5b (done)

- All insight engines localize `fullExplanation`, `dataBehind`, and `suggestedActions` at generation
- `docs/localization/phase5b-translations.json` — **61** prose + Money Map keys
- Money Map dashboard panel, canvas footer, full map hero

## Remaining (Phase 7+)

- Agreement / tax / PDF content
- Editorial pass es-419 vs es-ES
- Money Map territory titles/explanations from `MoneyMapBuilder` (dynamic)

## Verify

Argentina → open **Top insights** → tap insight → Explanation + suggested actions in Spanish; budget card on Home in Spanish.
