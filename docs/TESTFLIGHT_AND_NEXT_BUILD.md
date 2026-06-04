# BuxMuse — TestFlight (Build 1) and next agent handoff

Last updated: 2026-06-03

## Decisions locked for Build 1 (TestFlight today)

| Topic | Decision | Notes |
|--------|----------|--------|
| **HealthKit** | **Yes — keep in build** | Pro-gated sleep sync stays. Enable **HealthKit** on App ID `com.buxmuse.app` in Developer portal + Xcode Signing & Capabilities. Publish a **privacy policy URL** (required). App Privacy labels: health processed on-device, not collected by BuxMuse servers. **Build 2:** pre-auth disclaimer sheet (“no account, data stays on device”). |
| **Onboarding** | **Skip for Build 1** | No first-run carousel this upload. **Build 2:** 4 static skippable screens (welcome, add expense, backup, optional Health). |
| **Default appearance** | **Clean Apple** | `brandThemesEnabled = false`, `landingBackdropEnabled = true`, system accent (blue). Neutral `standardNeutral` theme on launch via `applyBrandThemesAppearance`. |
| **Region / currency** | **Device on first boot** | No saved country → `CountryCatalog.detectedFromDevice()` sets country, currency, and UI language. **Do not** let empty Studio defaults (US/USD) or fresh SwiftData prefs (USD) override detection — fixed in `migrateLegacyFreelanceLocale` + brain hydration. |
| **Bundle ID** | `com.buxmuse.app` | Widget: `com.buxmuse.app.TimerWidget`. New App Store listing; fresh container; permissions re-prompt. |

## What this commit includes (no features removed)

- Bundle ID migration (`com.buxmuse.app` + test/widget IDs).
- **SettingsStore** launch crash fix (init cycle with `HustleManager`; `didSet` guarded until `isLoaded`).
- Swift 6 agreement clause loading + iOS 26 / 18 fallback IDs.
- Merchant logo cache safety, budget period, localization, expense/recurring UX, data purge, format-crash fixes (from prior session work in same tree).
- **Default UI:** brand themes off, landing backdrop on for new installs (`seedDefaults`).

All major surfaces remain: expenses, goals, insights, Studio Simple/Pro, backup/restore, notifications, Face ID lock, Creative Energy + Health (Pro), widgets/Live Activities, etc.

## Signing & privacy docs (in repo)

- Portal checklist: `docs/DEVELOPER_PORTAL_SETUP.md`
- App Store Connect privacy answers: `docs/APP_STORE_CONNECT_PRIVACY.md`
- Hostable privacy policy draft: `docs/legal/PRIVACY_POLICY.md` (replace contact/company placeholders)
- Entitlements: `BuxMuse.entitlements` (HealthKit), `BuxMuse/PrivacyInfo.xcprivacy`

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

## Build 3+ backlog (next agent) — imports & receipt OCR

### FinanceKit — Wallet transaction import (optional, privacy-first)

- **Use:** `FinanceKitUI` **Transaction Picker** (iOS 18+) — user selects specific Wallet transactions; app maps to expenses (not full bank sync).
- **Do not use for v1** if entitlement/App Store Finance-category rules are not ready.
- **Fit for BuxMuse:** “Import from Wallet…” on Add Expense or Expenses tab; copy: only selected rows leave Wallet; on-device only.
- **Requirements:** `FinanceStore.isDataAvailable(.financialData)`; real device + linked Wallet data; UK users need eligible Wallet/open-banking sources (not every bank).
- **Heavier alternative:** full FinanceKit access + entitlement request — only if product needs ongoing sync (budget-app style).
- **Reference:** [Meet FinanceKit (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/2023/), [FinanceKit overview](https://developer.apple.com/financekit/).

### Receipt scanner on **Expenses** (high user value)

**Today:** `StudioReceiptEngine` + `StudioReceiptScannerView` live under **Home FAB → scan receipt** (Studio write-off flow). **Vision** OCR + local heuristics already extract **merchant, amount, date, VAT** (`BuxMuse/Features/Studio/Core/StudioEngines.swift`, `StudioReceiptViews.swift`). **Add Expense** (`AddExpenseSheet` / `AddExpenseViewModel`) has merchant, amount, date, notes — **not wired** to scanner.

**Proposed UX**

1. Add Expense / Expenses tab → **Scan receipt** (camera or photo library, same as Studio).
2. OCR → **review sheet** (editable merchant, amount, date; confidence hints).
3. **Save** → prefill Add Expense; optional attach receipt image for later (schema TBD).
4. **Line items → notes (optional v2):** parse non-total lines into a tidy bullet list in `notes` (“what I bought”) for grocery/shopping receipts; user can edit before save.

**Effort (rough, no code committed)**

| Tier | Scope | Effort | Quality |
|------|--------|--------|---------|
| **A — MVP** | Reuse `StudioReceiptEngine` + document camera; open Add Expense with prefilled fields; no line items | **~1–2 days** | Good for clear receipts; same heuristics as Studio (total = max amount, merchant = first line) |
| **B — Solid** | Review screen, UK/EU date & currency (`£`, `dd/MM/yyyy`), merchant cleanup (skip “Thank you”), link to `MerchantBrain` | **~3–5 days** | Feels reliable for common UK/US receipts |
| **C — Amazing** | Line-item extraction → formatted notes; receipt image stored on expense; redo scan; category guess | **~1–2 weeks** | Still on-device; accuracy varies on crumpled/long receipts |

**Hard parts (set expectations)**

- **Total vs subtotal** — heuristic “largest number” fails when tip/tax lines exist → need keywords (TOTAL, AMOUNT DUE, GBP).
- **Merchant** — often logo not text; may need top-of-receipt block or largest text line, not always line 1.
- **Line items** — noisy OCR; filter footer/payment lines; cap length in notes.
- **No receipt photo on expense entity today** — attaching image needs persistence/model work (Studio already saves `StudioReceipt.localImagePath`).

**Recommendation:** Ship **Tier A** in Build 3 right after TestFlight stabilizes; **Tier B** before marketing “scan groceries”; **FinanceKit picker** in parallel only if entitlement path is approved.

## iOS 26 fallback pattern (project convention)

- Financial engine: `LocalFinancialIntelligenceEngine` (26+) vs `LocalFinancialIntelligenceEngine18`.
- Glass / native buttons: `#available(iOS 26, *)` in `BuxmationSystem`, `BuxComponents`, `BuxRootTheme`.
- Agreement default clause IDs: library on 26+, hardcoded essential five on 18 in `SettingsStore`.

## Key paths

- Settings / appearance: `BuxMuse/Features/Settings/Core/SettingsStore.swift`, `AppearanceSettingsView.swift`
- App boot: `BuxMuse/Core/App/AppContainer.swift`, `BuxMuseApp.swift`
- Backup: `BuxMuse/Features/Settings/Views/BackupRestoreSettingsView.swift`
- Health UI: `BuxMuse/Features/Settings/Views/BurnoutGuardSettingsView.swift`
- Receipt OCR (reuse): `BuxMuse/Features/Studio/Core/StudioEngines.swift` (`StudioReceiptEngine`), `StudioReceiptViews.swift`
- Add expense (wire target): `BuxMuse/Features/ExpenseInput/AddExpenseSheet.swift`, `AddExpenseViewModel.swift`

## If appearance looks wrong on a test device

Delete app and reinstall (cached `settings_store_v1.json` from an earlier build may still have `brandThemesEnabled: true`). New installs use `seedDefaults` clean Apple settings.
