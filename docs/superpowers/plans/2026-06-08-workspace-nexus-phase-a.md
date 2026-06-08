# Workspace Nexus — Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship **Nexus Core** — virtual-desktop workspaces with per-workspace identity (theme + currency display), auto-routing rules, and a detail editor — without changing existing filter behavior, matrix defaults, or tier limits.

**Architecture:** Extend `Hustle` with optional Nexus fields (backward-compatible `Codable`). Workspace selection acts as a **virtual desktop**: scoped data via existing `HustleWorkspaceFilter`, transient theme via `ThemeManager` (never overwriting global Appearance prefs). Auto-routing runs in `BuxMuseBrain.saveExpenseRecord` on **create-only** when `hustleId == nil`. New `WorkspaceDetailEditorSheet` for identity + rules; `HustleSettingsView` opens it.

**Tech Stack:** Swift 6, SwiftUI, Combine, UserDefaults (`HustleManager`), SwiftData expenses, XCTest, iOS 18+ (iOS 26 primary).

**Out of scope (Phase B+):** Synergy Bridges (splits, dividend transfers, ROI dashboard), per-workspace budgets, `cardLast4` field, income workspace picker, Pro gating changes.

**Blueprint reference:** Workspace Nexus virtual-desktop model (Identity Sandboxes + Auto-Routing only).

---

## Locked product decisions

| Decision | Choice |
|----------|--------|
| Virtual desktop | Matrix **on** + specific workspace selected = scoped environment |
| Mission Control | Matrix **on** + **All Workspaces** (`selectedHustleId == nil`) = aggregated data, **global** Appearance |
| Matrix off | Identical to today; filter disabled; global Appearance only |
| Theme logic | Same as today: `AppTheme.all` presets + `applyBrandThemesAppearance()` fallback |
| Theme persistence | Workspace theme is **transient** — must **not** call `persistThemeSelection` / mutate `accentColorId` |
| `themeName` nil | Inherit global Appearance for that desktop session |
| Currency | `currencyCode` on `Hustle`; **display context** override while desktop active; do **not** call `appSettingsManager.applyCurrency()` |
| Auto-route | **Create-only** (skip when editing existing record) |
| Card rules UI label | **Payment method keywords** (stored in `cardRules`; matches `paymentMethod` substring) |
| Rule priority | First matching **active** hustle in `hustles` array order |
| Existing logic | Do not delete or change `HustleWorkspaceFilter`, matrix defaults, free-tier cap (3), archive keys |

---

## File map

| File | Action | Responsibility |
|------|--------|----------------|
| `BuxMuse/Core/HustleManager.swift` | Modify | Extended `Hustle` model; `routeHustleId(...)` |
| `BuxMuse/Core/Theme/ThemeManager.swift` | Modify | `workspaceThemeOverrideActive`, `applyTransientTheme`, `updateThemeForActiveWorkspace`, `restoreGlobalAppearance` |
| `BuxMuse/Core/DesignSystem/BuxRootTheme.swift` | Modify | Treat workspace override as branded session for accent/chrome |
| `BuxMuse/Core/WorkspaceCurrencyContext.swift` | **Create** | Resolve display `CurrencySetting` for active desktop |
| `BuxMuse/Brain/BuxMuseBrain.swift` | Modify | Auto-route hook in `saveExpenseRecord`; use currency context in display pipeline |
| `BuxMuse/Core/App/AppContainer.swift` | Modify | Combine subscribers + cold-launch desktop restore |
| `BuxMuse/Features/Settings/Views/WorkspaceDetailEditorSheet.swift` | **Create** | Name, color, theme, currency, rule lists |
| `BuxMuse/Features/Settings/Views/HustleSettingsView.swift` | Modify | Gear/detail → sheet; matrix toggle → theme restore |
| `BuxMuse/Core/DesignSystem/HustleSelectorBar.swift` | Modify | Optional currency subtitle on active desktop |
| `BuxMuseTests/WorkspaceNexusTests.swift` | **Create** | Model decode, routing, theme state unit tests |
| `BuxMuseTests/SideHustleMatrixTests.swift` | Verify | Must still pass unchanged |
| `BuxMuse.xcodeproj/project.pbxproj` | Modify | Add new Swift files to targets |
| `Localizable.xcstrings` / catalog | Modify | New editor strings |

**iOS reference paths (repo):** `iOS/Tired of this/BuxMuse/...`

---

## Virtual desktop state machine

```
                    ┌─────────────────────┐
                    │  sideHustleMatrix   │
                    │     ENABLED?        │
                    └─────────┬───────────┘
                              │
              NO ─────────────┼──────────── YES
              │               │               │
              ▼               │               ▼
     ┌────────────────┐      │      ┌────────────────┐
     │ SINGLE DESKTOP │      │      │ selectedHustleId │
     │ (today)        │      │      │     == nil ?     │
     │ global theme   │      │      └───────┬────────┘
     └────────────────┘      │              │
                              │     YES ─────┼───── NO
                              │      │       │       │
                              │      ▼       │       ▼
                              │ ┌──────────┐ │ ┌──────────────┐
                              │ │ MISSION  │ │ │ VIRTUAL      │
                              │ │ CONTROL  │ │ │ DESKTOP      │
                              │ │ global   │ │ │ hustle theme │
                              │ │ theme    │ │ │ + currency   │
                              │ └──────────┘ │ └──────────────┘
```

---

### Task 1: Extend `Hustle` model (backward compatible)

**Files:**
- Modify: `BuxMuse/Core/HustleManager.swift`
- Test: `BuxMuseTests/WorkspaceNexusTests.swift`

- [ ] **Step 1: Write failing decode test**

```swift
func testHustleDecodesLegacyJSONWithoutNexusFields() throws {
    let json = #"{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","name":"LLC","colorHex":"#5A55F5","isActive":true}"#
    let hustle = try JSONDecoder().decode(Hustle.self, from: Data(json.utf8))
    XCTAssertNil(hustle.themeName)
    XCTAssertNil(hustle.currencyCode)
    XCTAssertNil(hustle.cardRules)
    XCTAssertNil(hustle.merchantRules)
}

func testHustleEncodesRoundTripWithNexusFields() throws {
    let hustle = Hustle(
        name: "LLC",
        themeName: "midnightOcean",
        currencyCode: "EUR",
        cardRules: ["visa"],
        merchantRules: ["aws", "adobe"]
    )
    let data = try JSONEncoder().encode(hustle)
    let decoded = try JSONDecoder().decode(Hustle.self, from: data)
    XCTAssertEqual(decoded.themeName, "midnightOcean")
    XCTAssertEqual(decoded.currencyCode, "EUR")
    XCTAssertEqual(decoded.cardRules, ["visa"])
    XCTAssertEqual(decoded.merchantRules, ["aws", "adobe"])
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `xcodebuild test -project BuxMuse.xcodeproj -scheme BuxMuse -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:BuxMuseTests/WorkspaceNexusTests 2>&1 | tail -30`

- [ ] **Step 3: Add optional Nexus properties to `Hustle`**

Add to existing struct (do not remove any field):

```swift
public var themeName: String?       // AppTheme.id e.g. "midnightOcean"
public var currencyCode: String?    // CurrencySetting.id e.g. "EUR"
public var cardRules: [String]?     // Payment method keywords
public var merchantRules: [String]? // Merchant/notes keywords
```

Extend `init` with defaults `nil`. Synthesized `Codable` is sufficient.

- [ ] **Step 4: Run test — expect PASS**

- [ ] **Step 5: Verify `BuxMuseArchiveTests` still passes** (Hustle round-trip via archive)

---

### Task 2: Auto-Routing engine

**Files:**
- Modify: `BuxMuse/Core/HustleManager.swift`
- Test: `BuxMuseTests/WorkspaceNexusTests.swift`

- [ ] **Step 1: Write failing routing tests**

```swift
@MainActor
func testRouteHustleIdMatchesMerchantKeyword() {
    let manager = HustleManager.shared
    // setup: clear + add hustle with merchantRules ["amazon"]
    let id = manager.routeHustleId(merchantName: "Amazon Shopping", notes: nil, paymentMethod: nil)
    XCTAssertEqual(id, expectedHustleId)
}

@MainActor
func testRouteHustleIdMatchesPaymentMethodKeyword() {
    // cardRules ["visa"], paymentMethod "Visa"
}

@MainActor
func testRouteHustleIdSkipsInactiveHustle() { }

@MainActor
func testRouteHustleIdReturnsNilWhenNoMatch() { }

@MainActor
func testRouteHustleIdFirstMatchWins() { }
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement `routeHustleId` on `HustleManager`**

```swift
public func routeHustleId(merchantName: String, notes: String?, paymentMethod: String?) -> UUID? {
    let cleanMerchant = merchantName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let cleanNotes = (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let cleanPM = (paymentMethod ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    for hustle in hustles where hustle.isActive {
        if let cardRules = hustle.cardRules {
            for suffix in cardRules {
                let clean = suffix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !clean.isEmpty, cleanPM.contains(clean) { return hustle.id }
            }
        }
        if let merchantRules = hustle.merchantRules {
            for keyword in merchantRules {
                let clean = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !clean.isEmpty,
                   cleanMerchant.contains(clean) || cleanNotes.contains(clean) {
                    return hustle.id
                }
            }
        }
    }
    return nil
}
```

Do **not** gate on `sideHustleMatrixEnabled` inside this method — callers gate.

- [ ] **Step 4: Run tests — expect PASS**

---

### Task 3: Transient virtual-desktop themes

**Files:**
- Modify: `BuxMuse/Core/Theme/ThemeManager.swift`
- Modify: `BuxMuse/Core/DesignSystem/BuxRootTheme.swift`
- Test: `BuxMuseTests/WorkspaceNexusTests.swift` (lightweight state tests if needed)

- [ ] **Step 1: Add workspace override state to `ThemeManager`**

```swift
@Published private(set) var workspaceThemeOverrideActive: Bool = false

@MainActor
func applyTransientTheme(_ theme: AppTheme) {
    workspaceThemeOverrideActive = true
    // Set current with animation — do NOT call onThemeChanged
}

@MainActor
func restoreGlobalAppearance() {
    workspaceThemeOverrideActive = false
    let store = SettingsStore.shared
    if store.brandThemesEnabled {
        applyTransientTheme(store.resolvedBrandTheme())
    } else {
        applyTransientTheme(AppTheme.standardNeutral(accent: store.resolvedSystemAccent()))
    }
    workspaceThemeOverrideActive = false  // restore = not a workspace override
}

@MainActor
func updateThemeForActiveWorkspace() {
    let store = SettingsStore.shared
    guard store.sideHustleMatrixEnabled,
          let activeId = HustleManager.shared.selectedHustleId,
          let hustle = HustleManager.shared.hustles.first(where: { $0.id == activeId }),
          let themeId = hustle.themeName,
          let theme = AppTheme.all.first(where: { $0.id == themeId })
            ?? AppTheme.all.first(where: { $0.name == themeId }) else {
        restoreGlobalAppearance()
        return
    }
    applyTransientTheme(theme)
}
```

**Critical:** Extract shared animation logic from `applyTheme` into a private helper; `applyTheme` keeps calling `onThemeChanged` for user Appearance picks only.

- [ ] **Step 2: Update `BuxRootBrandThemeModifier`**

Compute effective branded session:

```swift
let workspaceActive = themeManager.workspaceThemeOverrideActive
let branded = settings.brandThemesEnabled || workspaceActive
```

Pass `branded` into `materialScheme(for:branded:)` and `buxBrandSurfaces`.

- [ ] **Step 3: Update `contrastAccentColor`**

When `workspaceThemeOverrideActive`, use `current.accentColor` (same path as branded themes) instead of forcing system accent.

- [ ] **Step 4: Manual sanity check (no test required)**

Confirm `AppearanceSettingsView` still calls `persistThemeSelection` → `applyTheme` → `onThemeChanged` unchanged.

---

### Task 4: Workspace currency display context

**Files:**
- Create: `BuxMuse/Core/WorkspaceCurrencyContext.swift`
- Modify: `BuxMuse/Brain/BuxMuseBrain.swift`
- Modify: `BuxMuse/Core/DesignSystem/HustleSelectorBar.swift`

- [ ] **Step 1: Create resolver**

```swift
@MainActor
enum WorkspaceCurrencyContext {
    static func activeDisplayCurrency(
        global: CurrencySetting,
        hustleManager: HustleManager = .shared,
        settings: SettingsStore = .shared
    ) -> CurrencySetting {
        guard settings.sideHustleMatrixEnabled,
              let id = hustleManager.selectedHustleId,
              let hustle = hustleManager.hustles.first(where: { $0.id == id }),
              let code = hustle.currencyCode,
              let currency = AppSettingsManager.availableCurrencies.first(where: { $0.id == code })
        else { return global }
        return currency
    }
}
```

- [ ] **Step 2: Wire into `generateExpenseInteractionDisplay` / `buildExpenseInteractionDisplay`**

Replace bare `AppSettingsManager.preferredCurrencyCode` with `WorkspaceCurrencyContext.activeDisplayCurrency(global: ...)` for **header/summary formatting** when building display DTOs. Per-row formatting already uses `r.currencyCode` — leave unchanged.

- [ ] **Step 3: Optional subtitle in `HustleSelectorBar`**

When active desktop has `currencyCode`, show compact badge next to "Viewing: …".

---

### Task 5: Auto-route in save pipeline

**Files:**
- Modify: `BuxMuse/Brain/BuxMuseBrain.swift`
- Test: `BuxMuseTests/WorkspaceNexusTests.swift`

- [ ] **Step 1: Write failing integration test**

Use `LocalFinancialIntelligenceEngine18` + in-memory or brain save pattern:

```swift
func testSaveExpenseRecordAutoRoutesOnCreateWhenUnassigned() throws {
    settings.sideHustleMatrixEnabled = true
    // hustle with merchantRules ["aws"]
    let record = ExpenseRecord(/* hustleId: nil, merchantName: "AWS Cloud", ... */)
    let saved = try brain.saveExpenseRecord(record)
    XCTAssertEqual(saved.hustleId, hustleId)
}

func testSaveExpenseRecordDoesNotReRouteOnEdit() throws {
    // existing record with hustleId nil, edit merchant — hustleId stays nil if no explicit re-save policy
    // OR: pass record with createdAt in past / use editingId path — document create-only via checking if fetch existed
}
```

**Create-only rule:** Auto-route only when record is new:

```swift
let isNewRecord = (try? persistence.fetchExpenseRecord(id: working.id)) == nil
```

- [ ] **Step 2: Insert hook in `saveExpenseRecord`**

Immediately **before** `persistence.upsertExpenseRecord(working, ...)`:

```swift
if isNewRecord,
   working.hustleId == nil,
   SettingsStore.shared.sideHustleMatrixEnabled {
    working.hustleId = HustleManager.shared.routeHustleId(
        merchantName: working.merchantName,
        notes: working.notes,
        paymentMethod: working.paymentMethod
    )
}
```

Do not modify intelligence analysis block above.

- [ ] **Step 3: Run tests — expect PASS**

- [ ] **Step 4: Run `SideHustleMatrixTests` — expect PASS**

---

### Task 6: AppContainer wiring (desktop lifecycle)

**Files:**
- Modify: `BuxMuse/Core/App/AppContainer.swift`

- [ ] **Step 1: Add Combine subscribers in `init` after `wirePersistenceSideEffects()`**

```swift
HustleManager.shared.$selectedHustleId
    .receive(on: RunLoop.main)
    .sink { [weak self] _ in
        self?.themeManager.updateThemeForActiveWorkspace()
    }
    .store(in: &cancellables)

SettingsStore.shared.$sideHustleMatrixEnabled
    .receive(on: RunLoop.main)
    .sink { [weak self] _ in
        self?.themeManager.updateThemeForActiveWorkspace()
    }
    .store(in: &cancellables)

HustleManager.shared.$hustles
    .receive(on: RunLoop.main)
    .sink { [weak self] _ in
        // Editor saved themeName without pill change
        self?.themeManager.updateThemeForActiveWorkspace()
    }
    .store(in: &cancellables)
```

- [ ] **Step 2: Cold-launch restore**

At end of `init`, after `hydrateFromPersistence`:

```swift
themeManager.updateThemeForActiveWorkspace()
```

Ensures persisted `selectedHustleId` applies desktop theme on boot.

- [ ] **Step 3: Verify `onThemeChanged` → `persistTheme` never fires on workspace switch**

Set breakpoint or log: only Appearance picker should persist.

---

### Task 7: `WorkspaceDetailEditorSheet`

**Files:**
- Create: `BuxMuse/Features/Settings/Views/WorkspaceDetailEditorSheet.swift`
- Modify: `BuxMuse/Features/Settings/Views/HustleSettingsView.swift`
- Modify: `BuxMuse.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create sheet struct**

Bindings: `@State private var draft: Hustle`, `onSave: (Hustle) -> Void`.

Sections:

1. **Identity** — name `TextField`, color swatches (reuse `premiumColors` from `HustleSettingsView`)
2. **Visual theme** — grid of `AppTheme.all` + **"Use app default"** row (`themeName = nil`)
3. **Display currency** — picker from `AppSettingsManager.availableCurrencies` + **"Use app default"** (`currencyCode = nil`)
4. **Auto-routing**
   - Payment method keywords (`cardRules`) — list + text field + add/delete
   - Merchant keywords (`merchantRules`) — list + text field + add/delete
   - Footer copy: first match wins; keywords are case-insensitive
5. **Archive toggle** — `isActive` toggle (optional Phase A polish; field exists today)

Save → `HustleManager.shared.updateHustle(draft)` + dismiss.

Use existing form chrome: `BuxThemedCardForm`, `BuxFormSection`, catalog strings.

- [ ] **Step 2: Wire `HustleSettingsView`**

- Add `@State private var editingHustle: Hustle?`
- Row: gear button + `onTapGesture(count: 2)` → set `editingHustle`
- `.sheet(item: $editingHustle)` → `WorkspaceDetailEditorSheet`
- On save: `updateHustle`; call `themeManager.updateThemeForActiveWorkspace()` if editing active desktop
- `.onChange(of: store.sideHustleMatrixEnabled)` → `themeManager.updateThemeForActiveWorkspace()`

- [ ] **Step 3: Add localization keys**

Minimum strings: "Use app default", "Payment method keywords", "Merchant keywords", "Visual theme", "Display currency", "Auto-routing", rule helper text.

---

### Task 8: Project + verification

**Files:**
- Modify: `BuxMuse.xcodeproj/project.pbxproj`
- Modify: `docs/TESTFLIGHT_AND_NEXT_BUILD.md` (optional changelog row)

- [ ] **Step 1: Add new files to BuxMuse + BuxMuseTests targets**

- [ ] **Step 2: Build**

```bash
xcodebuild -project BuxMuse.xcodeproj -scheme BuxMuse -destination 'generic/platform=iOS Simulator' build
```

- [ ] **Step 3: Test**

```bash
xcodebuild test -project BuxMuse.xcodeproj -scheme BuxMuse -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:BuxMuseTests/WorkspaceNexusTests -only-testing:BuxMuseTests/SideHustleMatrixTests -only-testing:BuxMuseTests/BuxMuseArchiveTests 2>&1 | tail -40
```

---

## Manual QA checklist

| # | Steps | Expected |
|---|--------|----------|
| 1 | Fresh install, matrix **off** | App looks identical to today; no selector side effects |
| 2 | Enable matrix, stay on **All Workspaces** | Global theme unchanged; all expenses visible |
| 3 | Edit workspace → set theme **Ocean** → select that workspace | Accent/hero shift to Ocean; **Settings → Appearance** unchanged after |
| 4 | Switch to **All Workspaces** | Theme reverts to global Appearance |
| 5 | Disable matrix | Theme reverts; filter off; `selectedHustleId` cleared |
| 6 | Set merchant rule `amazon`, add expense "Amazon Shopping", workspace picker = none | Saved row has correct `hustleId` |
| 7 | Edit that expense (change notes) | `hustleId` **unchanged** (create-only routing) |
| 8 | Set `currencyCode` EUR on desktop, select it | Expenses hero/summary uses EUR formatting |
| 9 | Kill app, relaunch with workspace still selected | Ocean (or chosen) theme applies on launch |
| 10 | Backup → restore on second device/sim | Hustles include `themeName`, rules; behavior intact |

---

## Phase B preview (do not implement in Phase A)

| Item | Notes |
|------|-------|
| `DualCashDrawerWidget` → route through brain | Bypasses `saveExpenseRecord` today |
| Income workspace picker | `AddExpenseSheet` income branch |
| Per-workspace budgets | `budgetLimit` on `Hustle` |
| Synergy Bridges | `bridgeGroupId`, splits, transfers |
| ROI dashboard | Read-only aggregator |
| `cardLast4` on expense | True card-suffix matching |

---

## Risk register

| Risk | Mitigation |
|------|------------|
| Theme persist corruption | `applyTransientTheme` never calls `onThemeChanged` |
| Clean Apple users see no theme change | `workspaceThemeOverrideActive` enables branded chrome path |
| Legacy UserDefaults hustles crash | All new fields optional; decode test |
| Edit re-tags expenses | Create-only `isNewRecord` guard |
| Editor changes theme without pill change | `$hustles` subscriber |

---

## Definition of done

- [ ] All Phase A tasks checked
- [ ] Build succeeds (iOS Simulator)
- [ ] `WorkspaceNexusTests` + `SideHustleMatrixTests` + `BuxMuseArchiveTests` pass
- [ ] Manual QA table verified
- [ ] No existing `HustleWorkspaceFilter` behavior changed
- [ ] `sideHustleMatrixEnabled` still defaults **off**
