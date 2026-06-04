# BuxMuse — TestFlight (Build 1) and next agent handoff

Last updated: 2026-06-03

## Decisions locked for Build 1 (TestFlight today)

| Topic | Decision | Notes |
|--------|----------|--------|
| **HealthKit** | **Yes — keep in build** | Pro-gated sleep sync stays. Enable **HealthKit** on App ID `com.buxmuse.app` in Developer portal + Xcode Signing & Capabilities. Publish a **privacy policy URL** (required). App Privacy labels: health processed on-device, not collected by BuxMuse servers. **Build 2:** pre-auth disclaimer sheet (“no account, data stays on device”). |
| **Onboarding** | **Skip for Build 1** | No first-run carousel this upload. **Build 2:** 4 static skippable screens (welcome, add expense, backup, optional Health). |
| **Default appearance** | **Clean Apple** | `brandThemesEnabled = false`, `landingBackdropEnabled = true`, system accent (blue). Neutral `standardNeutral` theme on launch via `applyBrandThemesAppearance`. |
| **Bundle ID** | `com.buxmuse.app` | Widget: `com.buxmuse.app.TimerWidget`. New App Store listing; fresh container; permissions re-prompt. |

## What this commit includes (no features removed)

- Bundle ID migration (`com.buxmuse.app` + test/widget IDs).
- **SettingsStore** launch crash fix (init cycle with `HustleManager`; `didSet` guarded until `isLoaded`).
- Swift 6 agreement clause loading + iOS 26 / 18 fallback IDs.
- Merchant logo cache safety, budget period, localization, expense/recurring UX, data purge, format-crash fixes (from prior session work in same tree).
- **Default UI:** brand themes off, landing backdrop on for new installs (`seedDefaults`).

All major surfaces remain: expenses, goals, insights, Studio Simple/Pro, backup/restore, notifications, Face ID lock, Creative Energy + Health (Pro), widgets/Live Activities, etc.

## TestFlight checklist (human — not in repo)

1. **developer.apple.com** — Register App IDs; enable HealthKit on main app; profiles for app + widget.
2. **Xcode** — Team signing, Archive → Distribute → TestFlight.
3. **App Store Connect** — New app `com.buxmuse.app`, privacy questionnaire, **Privacy Policy URL**, “What to test” notes.
4. **Device** — Delete old `com.rodolfo.BuxMuse` install; install Build 1; trust developer if sideloading; exercise camera, photos, notifications, Health (Pro), backup share to iCloud Drive.
5. **Verify launch** — Console: `SettingsStore: successfully loaded settings.` Home uses neutral Apple chrome + backdrop rim (brand themes off).

## Build 2 backlog (next agent)

1. Health pre-authorization sheet + persistent privacy copy under toggle.
2. Opt-in diagnostic export (no PII) via Share sheet.
3. Onboarding: 4 cards + “Don’t show again” + Settings → replay.
4. Receipt ZIP export + storage dashboard (MB breakdown).
5. Optional scheduled `.buxmuse` export reminder (manual iCloud Drive share already works).

## iOS 26 fallback pattern (project convention)

- Financial engine: `LocalFinancialIntelligenceEngine` (26+) vs `LocalFinancialIntelligenceEngine18`.
- Glass / native buttons: `#available(iOS 26, *)` in `BuxmationSystem`, `BuxComponents`, `BuxRootTheme`.
- Agreement default clause IDs: library on 26+, hardcoded essential five on 18 in `SettingsStore`.

## Key paths

- Settings / appearance: `BuxMuse/Features/Settings/Core/SettingsStore.swift`, `AppearanceSettingsView.swift`
- App boot: `BuxMuse/Core/App/AppContainer.swift`, `BuxMuseApp.swift`
- Backup: `BuxMuse/Features/Settings/Views/BackupRestoreSettingsView.swift`
- Health UI: `BuxMuse/Features/Settings/Views/BurnoutGuardSettingsView.swift`

## If appearance looks wrong on a test device

Delete app and reinstall (cached `settings_store_v1.json` from an earlier build may still have `brandThemesEnabled: true`). New installs use `seedDefaults` clean Apple settings.
