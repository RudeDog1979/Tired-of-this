# Phase 9 — Goal engines, expense intelligence, format strings

## Goal

Spanish for **brain-generated copy** (goals, expense insights, savings opportunities) and remaining **dynamic `Text`** labels that bypassed the string catalog.

## What shipped

### Goal intelligence (localized at generation)
- `GoalsRiskEngine`, `GoalsMomentumEngine`, `GoalsTimelineAI`, `GoalsOpportunityEngine` — all use `BuxLocalizedString` with `locale` (default `BuxInterfaceLocale.currentInterfaceLocale`).
- `BuxGoalCopy.swift` — display helpers for risks/opportunities/scenarios when needed.
- `GoalDetailView` — progress `%`, delay-risk colors vs localized Low/Medium/High.

### Expense & financial brain
- `ExpenseIntelligenceEngine` — recurrence, subscription, refund, category/merchant insights.
- `LocalFinancialIntelligenceEngine` (+ v18) — savings opportunity descriptions.

### UI format strings
- `%lld%%`, `Reliability: %lld%%`, `Fill strength %lld%%`, `Layer visibility %lld%%`, `Merge %@ into…`, burnout battery, Money Map node rings, business card opacity sliders.

### Infra
- `BuxInterfaceLocale` is **public** so feature modules can use it in default parameters.
- **94 keys** in `phase9-translations.json` via `build_phase9_translations.py`.

```bash
python3 scripts/localization/build_phase9_translations.py
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase9-translations.json
```

## Verify

Settings → Argentina → open a **Goal** with risks/momentum/scenarios; add an **expense** and check intelligence panel; Studio **client health** and **color picker** percentages in Spanish.

## Remaining

- Goal cache may stay in prior locale until `precalculateAllGoalsAsync` runs again after country change.
- ~13 orphan catalog keys from bad extract (`\(Int(...)` literals) — safe to ignore or delete.
- Studio project/invoice interpolated strings (hundreds of `Text("…\(…)")` — phase 10 sweep).
- Legal agreement PDF corpus.
