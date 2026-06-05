# BuxMuse — TestFlight handoff & next agent

Last updated: 2026-06-05 (invoice archive Phase A + polish)

## Platform strategy

| Layer | Target | Notes |
|--------|--------|--------|
| **Minimum deployment** | **iOS 18.0** | Xcode `IPHONEOS_DEPLOYMENT_TARGET = 18.0` |
| **Primary development** | **iOS 26** | Ship the latest SwiftUI / system APIs first |
| **Fallback** | **iOS 18–25** | Graceful degradation via `#available(iOS 26, *)` |

**Convention:** prefer native iOS 26 behaviour (glass, tab bar, financial engine, agreement clause library); provide iOS 18 equivalents where needed. Do not gate new work behind 26-only unless a fallback exists or is explicitly deferred.

### iOS 26 fallback pattern (project convention)

- Financial engine: `LocalFinancialIntelligenceEngine` (26+) vs `LocalFinancialIntelligenceEngine18`.
- Glass / native buttons: `#available(iOS 26, *)` in `BuxmationSystem`, `BuxComponents`, `BuxRootTheme`.
- Agreement default clause IDs: library on 26+, hardcoded essential five on 18 in `SettingsStore`.
- Sheet chrome: `.buxRootNavigationChrome()` + `.buxMeshSheetPresentation()` on Simple Studio sheets (Work Clock reference).

---

## Decisions locked for TestFlight

| Topic | Decision | Notes |
|--------|----------|--------|
| **HealthKit** | **Yes — keep in build** | Pro-gated sleep sync stays. Enable **HealthKit** on App ID `com.buxmuse.app` in Developer portal + Xcode Signing & Capabilities. Publish a **privacy policy URL** (required). App Privacy labels: health processed on-device, not collected by BuxMuse servers. **Post-launch:** pre-auth disclaimer sheet (“no account, data stays on device”). |
| **Onboarding** | **Shipped — 5-card wizard** | First launch: `RootView` full-screen cover when `hasCompletedOnboarding == false`. Cards: Welcome, Setup (region/budget), Studio, Backup, Tutorial. Settings → **Replay onboarding guide**. |
| **Default appearance** | **Clean Apple** | `brandThemesEnabled = false`, `landingBackdropEnabled = true`, system accent (blue). Neutral `standardNeutral` theme on launch via `applyBrandThemesAppearance`. |
| **Region / currency** | **Device on first boot** | No saved country → `CountryCatalog.detectedFromDevice()` sets country, currency, and UI language. **Do not** let empty Studio defaults (US/USD) or fresh SwiftData prefs (USD) override detection — fixed in `migrateLegacyFreelanceLocale` + brain hydration. |
| **Bundle ID** | `com.buxmuse.app` | Widget: `com.buxmuse.app.TimerWidget`. New App Store listing; fresh container; permissions re-prompt. |

---

## Recently completed (2026-06-04 → 2026-06-05)

### 1. Simple Studio visual polish & consistency (2026-06-05)

- **Consistent sheet headers:** Scan, Quote job, Log money, Invoice, Business card, and Scan chip editor now use transparent/glass navigation chrome matching Work Clock (`.buxRootNavigationChrome()` + `.buxMeshSheetPresentation()`).
- **Layout alignment:** Simple Studio header leading edge aligned with other tabs (redundant horizontal padding removed).
- **Premium wordmark:** `SimpleStudioHeader` — Pro-style gradient **S** wordmark on Simple Studio dashboard (`StudioTierWordmark.swift`).
- **Quick Actions panel:** Top strip on Simple Studio hub — Invoice, Scan, Quote job, Log money (`SimpleStudioHubView.simpleQuickActions`).

### 2. UI transitions & animations (2026-06-05)

- **FAB animation:** Smoother open/close and fade on Home + Simple Studio FAB menus (spring tuning, staggered delays).
- **Dismissal-to-sheet:** `closeFabAnd` delay pattern on Home FAB — avoids clipping when dismissing menu then presenting a sheet immediately.

### 3. Crash & stability (2026-06-05)

- **Invoice sheet crash:** Off-screen share/card rendering no longer reads locale from SwiftUI environment inside `ImageRenderer`. `SimpleInvoiceCardView` accepts `locale` as an explicit property; invoice/quote/log-money sheets pass `appSettingsManager.interfaceLocale`.

### 4. 5-card onboarding wizard (2026-06-04)

- **Guided setup:** `OnboardingWizardView` — Welcome, Setup, Studio, Backup, Tutorial.
- **Welcome enhancements:** BuxMuse logo asset, bouncy spring entrance, continuous idle float, slow orbiting tool icons.
- **Setup card:** Inline country/currency pickers + monthly budget with optional Decimal binding (empty field ↔ `0`).
- **Settings replay:** Settings → “Replay onboarding guide”.

### 5. Expense page & receipt scanner (2026-06-04)

- **Add Expense scanner:** “Scan paper receipt” card + toolbar camera in `AddExpenseSheet`; OCR via `StudioReceiptEngine` prefills merchant, amount, date, notes.
- **Home FAB shortcut:** `ExpenseSheetMode.addWithAutoScan` opens Add Expense and auto-triggers scanner.
- **Not yet:** dedicated scan button on Expenses tab toolbar (scanner lives inside Add Expense flow).

### 6. Inputs & system adjustments (2026-06-04)

- **Decimal pad Done:** Keyboard toolbar “Done” on onboarding Setup budget field only.
- **Budget bug fix:** Optional binding on onboarding budget `TextField` (clear field without stuck state).
- **SF Symbols repair:** `arrow.counterclockwise.doc.fill` → `arrow.down.doc.fill` (backup/restore icons).

### 8. Build 2 — privacy, storage, invoice archive (2026-06-05)

- **Health pre-auth:** `HealthKitConsentSheet.swift`, `hasAcknowledgedHealthKitDisclaimer` in `SettingsStore`.
- **Diagnostic export:** `BuxDiagnosticExportEngine.swift` + About → Export diagnostic report (`BuxDiagnosticExportTests`).
- **Storage dashboard:** `BuxStorageAuditEngine.swift` — Data → Storage sizes (receipts/scans, logos, DB, silent backups).
- **Backup reminder on launch:** `AppContainer` calls `BackupNotificationScheduler.reschedule`.
- **Invoice archive Phase A:** `StudioInvoiceArchiveView.swift`, `StudioInvoiceArchiveEngine.swift`, `BuxReceiptZIPExporter.swift` (shared ZIP writer).
  - Entry: **Studio → Tools → Backup invoices** (Pro + Simple hubs).
  - Export: PDF + PNG per invoice, optional receipt/scan photos, `manifest.json`.
  - Delete Option A: tier-scoped only; linked-twin warning.
  - UI polish: centered inline nav title, hero card centered, export FAB (icon-only), select-mode layout stable, sheet export phases (building → success → Share).
  - Data settings: receipt ZIP button **removed**; storage row + pointer to Studio export.
  - es-419 strings for archive UI; **Close → Cerrar** fixed globally in catalog.

---

### 7. TestFlight & launch prep (2026-06-03 → 2026-06-04)

- HealthKit signing, privacy descriptors, bundle ID migration, first-boot region detection.
- **SettingsStore** launch crash fix (init cycle with `HustleManager`; `didSet` guarded until `isLoaded`).
- Swift 6 agreement clause loading, merchant logo cache safety, localization/format-crash fixes.
- Spanish translations pass on Simple Studio sheets + settings chrome.

---

## What’s left to do

### TestFlight / App Store (human — blocking release)

1. **developer.apple.com** — App IDs; HealthKit on main app; profiles for app + widget.
2. **Xcode** — Team signing, Archive → Distribute → TestFlight.
3. **App Store Connect** — New app `com.buxmuse.app`, privacy questionnaire, **Privacy Policy URL**, “What to test” notes.
4. **Privacy policy** — Replace placeholders in `docs/legal/PRIVACY_POLICY.md` (`[your support email]`, company name).
5. **Device QA** — Delete old `com.rodolfo.BuxMuse` install; install Build 1; exercise camera, photos, notifications, Health (Pro), backup share to iCloud Drive, onboarding first-run, Simple Studio sheets, receipt scan → Add Expense.
6. **Verify launch** — Console: `SettingsStore: successfully loaded settings.` Home uses neutral Apple chrome + backdrop rim.

### Bug-fix / polish candidates (code — ask before changing)

| Item | Status | Notes |
|------|--------|--------|
| **CoreMotion onboarding parallax** | ⚠️ Verify | Listed in 2026-06-04 commit message; **not present** in current `OnboardingWizardView.swift`. CoreMotion exists for Money Map (`MoneyMapMotion.swift`) only. Confirm with device test or implement if intended. |
| **Decimal pad Done — app-wide** | Partial | Only onboarding Setup budget field has keyboard Done. Many `.decimalPad` fields elsewhere (Budget settings, goals, Studio sheets, Add Expense) still lack a dismiss toolbar. |
| **Budget settings deletion** | Partial | Optional binding fix is on **onboarding** budget only; `BudgetSettingsView` still binds `Decimal` directly — may still misbehave when clearing the field. |
| **Expenses tab scan entry** | Partial | Scanner is in Add Expense + Home FAB auto-scan; no camera/scan icon on `ExpenseTabView` toolbar. |
| **Receipt OCR quality (Tier B+)** | Backlog | Review sheet, UK/EU date/currency heuristics, merchant cleanup, receipt image on expense entity — see Build 3 section. |
| **Appearance cache** | Known | Reinstall if old `settings_store_v1.json` has `brandThemesEnabled: true`. |

### Build 2 backlog — feature audit (2026-06-05)

| Feature | Status | Where today |
|---------|--------|-------------|
| **Scheduled backup reminder** | ✅ **Implemented** | `BackupNotificationScheduler.swift` — re-scheduled on app launch (`AppContainer`) + Settings/onboarding toggles. |
| **Health pre-auth sheet** | ✅ **Implemented** | `HealthKitConsentSheet.swift` + `BurnoutGuardSettingsView` — in-app disclaimer before system Health dialog; persistent on-device privacy footnote. |
| **Diagnostic export (no PII)** | ✅ **Implemented** | `BuxDiagnosticExportEngine.swift` + About → Export diagnostic report (counts/flags only; user-controlled Share sheet). |
| **Receipt ZIP + storage dashboard** | ✅ **Implemented** (storage only) | `BuxStorageAuditEngine.swift` — Data → Storage sizes. Receipt ZIP **removed** from Data; export lives in Studio → Tools → **Backup invoices**. |
| **Invoice archive (Phase A)** | ✅ **Implemented** | `StudioInvoiceArchiveView.swift`, `StudioInvoiceArchiveEngine.swift` — Simple + Pro lists, PDF+PNG ZIP, optional receipt photos, tier-scoped delete with linked-twin warning. |

**Invoice backup — Phase A (shipped):**

- Entry: **Studio → Tools → Backup invoices** (Pro hub tools section + Simple hub tools section).
- Export: each invoice as **PDF + PNG** in a ZIP + `manifest.json`; user toggle for **receipt/scan photos**.
- Delete: **Option A** — removes selected tier only; warns when a linked twin exists in the other tier.
- Data settings: storage row kept; points users to Studio for export.

**Phase B (deferred):** full `.buxmuse` restore with binary attachments (receipts, scans, agreements).

**Backup reminder — implementation notes (already shipped):**

- `BackupNotificationScheduler.reschedule(frequency:)` schedules identifier `buxmuse.backup.reminder`.
- Shares `SettingsStore.autoBackupFrequency` with `LocalBackupCoordinator` (silent JSON writes to `ApplicationSupport/BuxMuseBackups/` when `allowLocalBackups` is on).
- Reminders are re-scheduled on cold app launch via `AppContainer` (Plan D).
- Duplicate UX: `DataSettingsView` “Sandbox backup” frequency picker vs `BackupRestoreSettingsView` “Backup reminders” — same setting, different labels. May confuse testers.

---

### Build 2 — implemented (2026-06-05)

- **Plan A:** `HealthKitConsentSheet`, `hasAcknowledgedHealthKitDisclaimer` in `SettingsStore`.
- **Plan B:** `BuxDiagnosticExportEngine` + About → Export diagnostic report.
- **Plan C:** Storage dashboard in Data settings (receipt ZIP moved to Studio invoice archive).
- **Plan D:** `BackupNotificationScheduler.reschedule` on app boot.

**Invoice archive — UI rules (do not regress):**

- Do **not** custom-size or gradient-wrap SF Symbols; use `Label` or default system rendering.
- Export action = **FAB** (icon-only); selection actions in nav bar.
- Create ZIP disabled when nothing to export (select mode + zero selected + receipt photos off).
- Export sheet phases: **building** (min ~1.4s pulse) → **complete** (checkmark + copy) → **Share** row.
- Simple invoice delete: `SimpleStudioStore.deleteInvoice(id:)` unlinks entries only; does not delete Pro twin.

**Known test debt:**

- `BuxMuseArchiveTests` references `AutoBackupFrequency.daily` — enum may not exist; fails test target compile.
- `StudioInvoiceArchiveEngineTests` added; run after fixing archive tests.

---

### Build 2 — draft plans (superseded — kept for reference)

#### Plan A — Health pre-authorization sheet

**Goal:** Show an in-app disclaimer *before* the system HealthKit permission dialog when Pro user enables “Sync sleep from HealthKit”.

**Current behaviour:** `BurnoutGuardSettingsView.healthKitBinding` → immediate `BurnoutEngine.requestHealthKitAuthorization()`.

**Proposed UX:**

1. User flips HealthKit toggle ON.
2. Present **`HealthKitConsentSheet`** (modal): plain-language bullets — reads sleep analysis only, on-device, never uploaded, can disable anytime, link to privacy policy.
3. Primary: **“Continue to Apple Health”** → call existing `BurnoutEngine.requestHealthKitAuthorization()`.
4. Secondary: **“Not now”** → leave toggle off.
5. Under the toggle (persistent): short privacy footnote + “Open Health settings” link when denied.

**Settings to add (optional):** `hasAcknowledgedHealthKitDisclaimer: Bool` — skip sheet on re-enable after first ack.

**Files:** `BurnoutGuardSettingsView.swift`, new `HealthKitConsentSheet.swift`, `SettingsStore.swift`, `Localizable.xcstrings`, `docs/legal/PRIVACY_POLICY.md` (anchor link).

**Acceptance:** System Health dialog never appears without user confirming in-app sheet first; denied state still shows Settings guidance.

**Effort:** ~0.5–1 day.

---

#### Plan B — Opt-in diagnostic export (no PII)

**Goal:** Support/troubleshooting bundle the user explicitly shares — **no expenses, names, receipts, or Health samples**.

**Current behaviour:** Debug overlay toggles in `AboutSettingsView`; `DataSettingsView.generateJSONDump()` exports real user data — **not** suitable as diagnostics.

**Proposed UX:**

1. Settings → About → **“Export diagnostic report”** (separate from JSON data export).
2. Builds a `.json` or `.txt` file with: app version/build, iOS version, device model (generic), locale/currency, feature flags, Studio mode, storage summary counts (record counts only), last error logs if any, notification auth status, HealthKit auth status (authorized/denied, not values), SwiftData store name, cache sizes (bytes only).
3. Share via `UIActivityViewController` / `ShareLink`.
4. Confirmation alert: “This report contains no personal financial data.”

**Engine:** new `BuxDiagnosticExportEngine.swift` — single builder, unit-tested deny-list for keys.

**Files:** `AboutSettingsView.swift`, new engine + tests in `BuxMuseTests/`.

**Out of scope:** Automatic upload, crash log integration with third parties.

**Effort:** ~1–2 days.

---

#### Plan C — Receipt ZIP export + storage dashboard

**Goal:** Let users see how much disk BuxMuse uses and export receipt/scan images as a ZIP.

**Current storage (on disk, not in `.buxmuse` archive):**

| Bucket | Location | Source |
|--------|----------|--------|
| Pro receipt scans | `Documents/StudioReceipts/*.jpg` | `StudioReceiptViews.persistReceiptImage` |
| Simple Studio scans + card photos | `Application Support/Studio/scans/*.jpg` | `SimpleStudioScanImageStore` |
| Merchant logos | Logo cache dir | `MerchantLogoEngine` / `LightweightLogoCache` |
| SwiftData + settings | App container | `PersistenceController`, `settings_store_v1.json` |
| Silent JSON backups | `Application Support/BuxMuseBackups/` | `LocalBackupCoordinator` |

**Proposed UX:**

1. Settings → Data → new section **“Storage”** with rows: Receipts & scans, Merchant logos, Database, Backups, **Total** — each showing human-readable size (MB/KB).
2. Actions: **“Export receipt images (ZIP)”** — includes Pro `StudioReceipts` + Simple `scans/` JPEGs; manifest JSON inside ZIP with receipt id → filename mapping (no OCR re-run).
3. Optional: **“Clear merchant logo cache”** already exists; add **“Delete exported temp files”** if needed.

**Engine:** new `BuxStorageAuditEngine.swift` — walks known directories, `FileManager` size aggregation, async for large trees.

**Files:** `DataSettingsView.swift` (or new `StorageDashboardView.swift`), engine, ZIP via `ZIPFoundation` or `NSFileCoordinator` + `Archive` (prefer stdlib/minimal dep if already in project — verify before adding package).

**Acceptance:** Sizes match Files app approx; ZIP opens on Mac/iOS; empty buckets show “0 KB”; export disabled when no images.

**Effort:** ~2–3 days.

---

#### Plan D — Backup reminder polish (optional — feature exists)

Only if you want hardening, not net-new capability:

1. Call `BackupNotificationScheduler.reschedule(frequency: SettingsStore.shared.autoBackupFrequency)` from `AppContainer.init` after settings load.
2. Unify copy between `DataSettingsView` “Sandbox backup” and `BackupRestoreSettingsView` “Backup reminders” — or split settings (`backupReminderFrequency` vs `localBackupFrequency`) if silent JSON dumps should be independent of notification cadence.

**Effort:** ~2–4 hours.

---

### Other Build 2 backlog (unchanged)

3. Onboarding: “Don’t show again” persistence polish (wizard already ships; confirm skip/dismiss UX).
4. App-wide decimal-pad Done toolbar (shared modifier — avoid one-off copies).

### Build 3+ backlog — imports & receipt OCR

#### FinanceKit — Wallet transaction import (optional, privacy-first)

- **Use:** `FinanceKitUI` **Transaction Picker** (iOS 18+) — user selects specific Wallet transactions; app maps to expenses (not full bank sync).
- **Do not use for v1** if entitlement/App Store Finance-category rules are not ready.
- **Fit for BuxMuse:** “Import from Wallet…” on Add Expense or Expenses tab; copy: only selected rows leave Wallet; on-device only.
- **Requirements:** `FinanceStore.isDataAvailable(.financialData)`; real device + linked Wallet data; UK users need eligible Wallet/open-banking sources (not every bank).
- **Heavier alternative:** full FinanceKit access + entitlement request — only if product needs ongoing sync (budget-app style).
- **Reference:** [Meet FinanceKit (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/2023/), [FinanceKit overview](https://developer.apple.com/financekit/).

#### Receipt scanner — next tiers

**Today:** `StudioReceiptEngine` + document camera in **Add Expense**, **Home FAB**, and **Studio write-off** flow. Vision OCR + local heuristics extract merchant, amount, date, VAT (`StudioEngines.swift`, `StudioReceiptViews.swift`).

**Proposed UX (remaining)**

1. Optional Expenses tab toolbar → scan → Add Expense prefilled.
2. Dedicated **review sheet** (editable fields, confidence hints) before save.
3. **Save** → optional attach receipt image on expense (schema TBD; Studio already has `StudioReceipt.localImagePath`).
4. **Line items → notes (v2):** parse non-total lines into bullet list in `notes`.

| Tier | Scope | Effort | Quality |
|------|--------|--------|---------|
| **A — MVP** | ✅ Mostly done | — | Add Expense scan + OCR prefill; same heuristics as Studio |
| **B — Solid** | Review screen, UK/EU date & currency, merchant cleanup, `MerchantBrain` link | **~3–5 days** | Reliable for common UK/US receipts |
| **C — Amazing** | Line-item notes, receipt image on expense, redo scan, category guess | **~1–2 weeks** | On-device; accuracy varies |

**Hard parts:** total vs subtotal heuristics; merchant from logo blocks; noisy line-item OCR; no receipt photo on expense entity today.

**Recommendation:** Stabilize **Tier A** on TestFlight; **Tier B** before marketing “scan groceries”; FinanceKit only if entitlement path is approved.

---

## Key paths

| Area | Files |
|------|--------|
| App boot | `BuxMuseApp.swift`, `AppContainer.swift`, `RootView.swift` |
| Onboarding | `OnboardingWizardView.swift`, `SettingsStore.hasCompletedOnboarding` |
| Settings / appearance | `SettingsStore.swift`, `AppearanceSettingsView.swift` |
| Simple Studio hub & sheets | `SimpleStudioHubView.swift`, `SimpleStudio*Sheet.swift`, `SimpleStudioLogTimeView.swift` |
| Simple Studio wordmark | `StudioTierWordmark.swift` (`SimpleStudioHeader`) |
| Share / off-screen render | `SimpleStudioShareHelper.swift`, `SimpleInvoiceCardView` |
| Backup | `BackupRestoreSettingsView.swift`, `BackupNotificationScheduler.swift` |
| Storage / privacy engines | `BuxMuse/Core/Privacy/` (`BuxStorageAuditEngine`, `BuxDiagnosticExportEngine`, `StudioInvoiceArchiveEngine`, `BuxReceiptZIPExporter`) |
| Invoice archive UI | `StudioInvoiceArchiveView.swift`, `StudioHubView.swift`, `SimpleStudioHubView.swift` |
| Health UI | `BurnoutGuardSettingsView.swift`, `HealthKitConsentSheet.swift` |
| Receipt OCR | `StudioEngines.swift` (`StudioReceiptEngine`), `StudioReceiptViews.swift` |
| Add expense + scan | `AddExpenseSheet.swift`, `AddExpenseViewModel.swift`, `ExpenseSheetMode.swift` |
| FAB / animations | `DashboardView.swift` (`closeFabAnd`), `SimpleStudioHubView.swift` (FAB) |

## Signing & privacy docs (in repo)

- Portal checklist: `docs/DEVELOPER_PORTAL_SETUP.md`
- App Store Connect privacy answers: `docs/APP_STORE_CONNECT_PRIVACY.md`
- Hostable privacy policy draft: `docs/legal/PRIVACY_POLICY.md` (replace contact/company placeholders)
- Entitlements: `BuxMuse.entitlements` (HealthKit), `BuxMuse/PrivacyInfo.xcprivacy`

## If appearance looks wrong on a test device

Delete app and reinstall (cached `settings_store_v1.json` from an earlier build may still have `brandThemesEnabled: true`). New installs use `seedDefaults` clean Apple settings.

## Agent rules (this session)

- **Bug-fix / polish only** unless user approves new features.
- **No code or logic changes** without explicit approval.
- **Do not remove** existing features or logic without approval.
- **Phase B next (deferred):** full `.buxmuse` binary restore — receipts, scans, agreements; strong manifest + before/after restore summary (~1–2 weeks). Do **not** start unless user asks.
- **Next code candidates:** fix `BuxMuseArchiveTests` (`AutoBackupFrequency.daily`); device QA invoice archive export/share; unify backup reminder copy in Data vs Backup settings (Plan D polish).
