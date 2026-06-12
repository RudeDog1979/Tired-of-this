# BuxMuse localization — Phase 0

Phase 0 adds infrastructure only. **No app logic changes.**

## Languages

| Code | Role |
|------|------|
| `en` | Source (development region) |
| `es` | Generic Spanish fallback |
| `es-419` | Latin America Spanish |
| `es-ES` | Spain Spanish |

## Fallback order (iOS)

- Device `es-MX`, `es-AR`, etc. → `es-419` → `es` → `en`
- Device `es-ES` → `es-ES` → `es` → `en`
- Device `es` only → `es` → `en`

## String catalogs

| File | Purpose |
|------|---------|
| `BuxMuse/Localizable.xcstrings` | UI strings (auto-extract on build when literals match keys) |
| `BuxMuse-InfoPlist.xcstrings` | Privacy / permission descriptions |

## Glossary & translation

- Project glossary: `.baoyu-skills/baoyu-translate/EXTEND.md`
- Translator skill: **baoyu-translate** ([skills.sh](https://skills.sh/jimliu/baoyu-skills/baoyu-translate), ~17K installs)
- iOS workflow skill: **ios-localization** ([skills.sh](https://skills.sh/dpearson2699/swift-ios-skills/ios-localization))

Installed under `.agents/skills/` for this repo (Cursor picks them up).

## Rules (do not break logic)

1. **Never** translate stored IDs, enum raw values, or JSON keys.
2. **Never** branch feature logic on language.
3. User-entered text stays as typed.
4. Brand names stay: **BuxMuse**, **Bux Canvas**, **Studio** (unless marketing decides otherwise).
5. UI tone: **tú** (informal), not usted.

## Verify Phase 0

1. Run BuxMuse on the simulator (iPhone language can stay English).
2. **Settings → Currency & Region** → country **Argentina** or **Mexico**.
3. Tab bar should show **Inicio**, **Gastos**, **Studio**, **Ajustes**.

App UI language follows **selected country**, not the device language. See `BuxInterfaceLocale.swift`.

## Phases

| Phase | Doc | Scope |
|-------|-----|--------|
| 1 | [PHASE1.md](PHASE1.md) | Home, Expenses, Settings shell |
| 2 | [PHASE2.md](PHASE2.md) | Studio + Bux Canvas |
| 3 | [PHASE3.md](PHASE3.md) | Format strings, settings dynamic copy |
| 4 | [PHASE4.md](PHASE4.md) | Insights, Goals, Subscription Hub |
| 5 | [PHASE5.md](PHASE5.md) | Insight prose (all engines), Money Map shell |
| 6 | [PHASE6.md](PHASE6.md) | Burnout, cash drawer, territory detail sheets |
| 7 | [PHASE7.md](PHASE7.md) | Money Map builder + territory copy |
