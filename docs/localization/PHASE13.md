# Phase 13 — Final interpolated UI sweep

## Scope

Eliminated remaining `Text("…\(…)")` across BuxMuse and wired adjacent `String(format:)` labels (subscriptions, projects, burnout, dashboard, business card toolbar).

## Areas

- Tax & cashflow overview, country picker, invoice party country rows
- Business Card Studio (gallery, editor, canvas toolbar, photo access)
- Expenses (carousel, summary, merchants, total spend, monthly summary)
- Spending / goal cards, tip popup, tax studio health
- Studio hub stats, work-clock pickers, job quote hours
- Region currency dialog buttons, project timer “log and stop”

## Merge

```bash
python3 scripts/localization/build_phase13_translations.py
python3 scripts/localization/merge_phase1_translations.py docs/localization/phase13-translations.json
```

## Note

Numeric-only displays (quantities `%.1f`, saturation sliders) stay as formatted numbers. Brain-generated copy uses existing `Bux*Copy` helpers at generation time.
