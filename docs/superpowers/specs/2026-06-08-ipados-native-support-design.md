# BuxMuse iPadOS Native Support — Design Spec

**Date:** 2026-06-08  
**Status:** Approved — Step 1 implementation authorized  
**Target:** 100% native iPadOS — full HIG compliance, M-series desktop-class performance. Non-negotiable.

---

## 0. Hard Rules (Non-Negotiable)

### 0.1 Folder Scope — Only This Tree

All design, planning, and implementation work happens **exclusively** inside:

```
/Users/rodolfo/App Development/iOS/Tired of this/
```

| Allowed | Forbidden |
|---------|-----------|
| `BuxMuse/**` (app source, resources, xcodeproj) | Any path outside `iOS/Tired of this/` |
| `docs/**` inside `Tired of this/` (specs/plans only) | `scripts/`, parent `App Development/`, other platforms |
| `BuxMuse.xcodeproj` project file edits for new targets/files | Widget/timer extension logic changes (unless iPad layout required) |

**No exceptions.** No cross-folder imports, no shared libs outside this tree, no permission requests to touch other folders.

### 0.2 Do Not Touch Existing iPhone Implementation

The current iPhone UI, navigation, sheets, overlays, and feature views are **frozen**.

- **Do not refactor** `DashboardView`, `ExpenseTabView`, `StudioHubView`, feature sheets, or existing DesignSystem files for iPad behavior.
- **Do not change** tax engines, financial math, persistence, localization JSON, or `buxmuse_tax_compute.json`.
- **Do not remove** any feature, logic, or math.

iPad native support is delivered by **new BuxPad files only**, wired at the shell:

| Touch point | Allowed change |
|-------------|----------------|
| `BuxMuseApp.swift` | Add `WindowGroup`s, inject `BuxPadNavigationBrain` |
| `AppContainer.swift` | Construct + expose pad brain |
| `RootView.swift` | Route to `BuxPadShell` on iPad; iPhone path unchanged |
| `ContentView.swift` | **No changes** |
| Existing feature `*.swift` | **No changes** — iPad consumes them inside new pad wrappers/scaffolds |

New iPad UI lives in dedicated paths:

```
BuxMuse/Core/Platform/iPad/     — layout, shell, presentation, keyboard, metrics
BuxMuse/Core/DesignSystem/iPad/ — pad chrome, spacing, hover
BuxMuse/Brain/Engines/          — BuxPadNavigationBrain.swift (new file only)
BuxMuse/Features/iPad/          — per-tab pad hosts that compose existing views
```

### 0.3 No Logic Deletion — Minimal Touch

- **Never delete** existing code, features, engines, math, or view logic.
- **Banned:** Opening or editing logic files unless strictly required to wire the pad layer.
- **Allowed logic touch:** Only `BuxPadNavigationBrain.swift` (new) + additive lines in `AppContainer`, `BuxMuseApp`, `RootView`.
- All other brains, stores, tax kernels, financial engines, and `Features/**` remain **frozen** until a pad host requires composition (Step 3).

### 0.4 Fully Native — No Compromises

- iPad is **not** a scaled iPhone. Every step in this plan is **required**, not optional.
- No phased shortcuts, no “good enough for now,” no deferring keyboard/pointer/multitasking/external display.
- Compact width (Slide Over, 1/3 Split View) keeps full functionality; regular width gets **purpose-built** multi-column layouts.
- M-series optimization is a **delivery requirement**, not a polish pass.

---

## 1. Current State

| Area | Today |
|------|-------|
| Target | Universal (`TARGETED_DEVICE_FAMILY = 1,2`), iOS 18+, iPad orientations enabled |
| Shell | Single `WindowGroup` → `RootView` → `TabView` |
| Adaptivity | 360pt width gate → 16pt vs 20pt margins only |
| iPad code | **One screen:** `InvoiceDesignerHubView` (`horizontalSizeClass` split) |
| Problem | Stretched phone UI; `UIScreen.main` in 5 files; root overlays; inconsistent padding |

**Verdict:** Universal binary, zero native iPad shell. Invoice Designer is the split-panel reference to generalize into new BuxPad scaffolds — without editing that file until Step 3b routes through the scaffold.

---

## 2. Success Criteria (All Required)

1. **Layout:** `NavigationSplitView` / multi-column in regular width; usable at every Split View ratio.
2. **Navigation:** Sidebar (regular), tab bar (compact). Meaningful empty detail states.
3. **Padding:** `BuxPadLayout` tokens only inside pad layer — consistent 8pt grid app-wide on iPad.
4. **Presentation:** No phone-modal patterns at regular width — split columns, popovers, inspectors.
5. **Input:** Cmd shortcuts, hover, context menus, drag-and-drop, Tab focus, arrow navigation — all primary flows.
6. **Multitasking:** Stage Manager, multi-window, state preserved across resize.
7. **Performance:** Container-width driven sizing; M-series 120Hz; brain snapshot debounce on resize.
8. **Brains:** `BuxPadNavigationBrain` owns pad routing/presentation — not `ContentView`, not feature views.
9. **iPhone:** Pixel-identical — pad code path never runs on iPhone.

---

## 3. Architecture Decision

**Platform layer + iPad feature hosts + pad brain** — all new files, minimal shell wiring.

```
BuxMuseApp
├── WindowGroup                          — iPhone + iPad primary
├── WindowGroup("Expense", for: UUID)    — Step 5
├── WindowGroup("Studio Invoice", for: UUID)
└── WindowGroup(id: "presentation")    — Step 7 external display

RootView
├── iPhone  → existing coreTabView (untouched)
└── iPad    → BuxPadShell
                ├── compact  → BuxPadCompactShell (tab bar, wraps existing tab roots)
                └── regular  → BuxPadRegularShell (sidebarAdaptable + split scaffolds)
                    ├── BuxPadHomeHost      → composes DashboardView in readable column
                    ├── BuxPadExpenseHost   → split: list | detail
                    ├── BuxPadStudioHost    → split: hub | tool
                    └── BuxPadSettingsHost  → NavigationSplitView

Brain/Engines/BuxPadNavigationBrain.swift
Core/Platform/iPad/BuxPadLayout.swift
Core/Platform/iPad/BuxPadShell.swift
Core/Platform/iPad/BuxAdaptivePresentation.swift
Core/Platform/iPad/BuxPadSplitScaffold.swift
Core/Platform/iPad/BuxContainerMetrics.swift
Core/Platform/iPad/BuxKeyboardCommands.swift
Core/DesignSystem/iPad/BuxPadChrome.swift
Features/iPad/BuxPad*Host.swift (per tab)
```

Existing views are **composed inside** pad hosts — not modified.

---

## 4. BuxPad Spacing — Single Source of Truth

All iPad padding flows through `BuxPadLayout`. Pad hosts and scaffolds apply modifiers; **no new literals in existing feature files.**

| Token | Compact | Regular | Use |
|-------|---------|---------|-----|
| `marginHorizontal` | 16 | 24 | Screen edges |
| `marginReadable` | — | max 720pt centered | Dashboard, forms |
| `splitSidebarMin` | — | 280 | Lists |
| `splitSidebarIdeal` | — | 320 | Invoice Designer baseline |
| `splitSidebarMax` | — | 380 | 13" Pro |
| `columnGap` | — | 16 | Split columns |
| `detailInset` | 16 | 20 | Detail cards |
| `toolbarSpacing` | — | 12 | Primary/secondary groups |

`BuxPadChrome` exposes view modifiers: `.buxPadRootChrome()`, `.buxPadDetailChrome()`, `.buxPadSplitChrome()`.

---

## 5. iPad Presentation Policy

Owned by `BuxAdaptivePresentation` + `BuxPadNavigationBrain`:

| Flow | iPad compact | iPad regular |
|------|--------------|--------------|
| Expense detail | sheet (.large) | split detail column |
| Add expense | sheet (.large) | sheet (.large) |
| Subscription hub | sheet | split inspector column |
| Goal / Insight detail | sheet | split detail column |
| Studio tool | navigation push | split detail column |
| Category / note picker | .large detent | .large / popover anchored |
| Share | popover | popover |
| Onboarding / persona | fullScreenCover | fullScreenCover |

---

## 6. UIScreen Elimination (Inside Pad Layer Only)

Pad hosts and `BuxContainerMetrics` replace `UIScreen.main.bounds` for iPad layout. Existing files with UIScreen reads are **not edited** — pad hosts pass container metrics via environment so pad-wrapped content sizes correctly:

| Existing file (frozen) | Pad mitigation |
|------------------------|----------------|
| `DashboardView` | `BuxPadHomeHost` applies scale override env |
| Business Card views | `BuxPadBusinessCardHost` + `BuxContainerMetrics` |
| `InvoiceDesignerHubView` | `BuxPadInvoiceDesignerHost` wraps with `BuxPadSplitScaffold` (Step 3b) |

---

## 7. Phased Delivery (Strict Gates)

> Step N does not start until Step N−1 exit checklist is complete.

---

### STEP 1 — BuxPad Foundation (new files only)

**Create:**
- `Core/Platform/iPad/BuxAdaptiveEnvironment.swift`
- `Core/Platform/iPad/BuxPadLayout.swift`
- `Core/Platform/iPad/BuxAdaptivePresentation.swift`
- `Core/Platform/iPad/BuxPadSplitScaffold.swift`
- `Core/Platform/iPad/BuxContainerMetrics.swift`
- `Core/DesignSystem/iPad/BuxPadChrome.swift`
- `Brain/Engines/BuxPadNavigationBrain.swift`

**Minimal wire (3 files):** `AppContainer.swift`, `BuxMuseApp.swift`, `RootView.swift` — iPad branch only.

**Exit:**
- [ ] iPhone path identical (pad code never executes on iPhone)
- [ ] `BuxPadNavigationBrain` testable in `BuxMuseTests`
- [ ] All pad modifiers use `BuxPadLayout` tokens
- [ ] Xcode project includes new files (pbxproj inside allowed tree)

---

### STEP 2 — BuxPad Shell + Navigation

**Create:**
- `Core/Platform/iPad/BuxPadShell.swift`
- `Core/Platform/iPad/BuxPadCompactShell.swift`
- `Core/Platform/iPad/BuxPadRegularShell.swift`

**Minimal wire:** `RootView.swift` — `UIDevice.current.userInterfaceIdiom == .pad` → `BuxPadShell`.

**Deliver:**
- `.sidebarAdaptable` in regular width
- Overlay hubs routed through `BuxAdaptivePresentation`
- Empty detail placeholders via `BuxPadChrome`

**Exit:**
- [ ] Sidebar at full iPad width
- [ ] Tab bar at 1/3 Split View
- [ ] Resize preserves selection state
- [ ] iPhone untouched

---

### STEP 3 — iPad Feature Hosts (compose existing views)

**Create in `Features/iPad/`:**
- `BuxPadHomeHost.swift`
- `BuxPadExpenseHost.swift`
- `BuxPadStudioHost.swift`
- `BuxPadSimpleStudioHost.swift`
- `BuxPadSettingsHost.swift`
- `BuxPadTaxEnvelopeHost.swift`
- `BuxPadTaxStudioHost.swift`
- `BuxPadBusinessCardHost.swift`
- `BuxPadSubscriptionHubHost.swift`
- `BuxPadInvoiceDesignerHost.swift`

Order: Settings → Studio Pro → Expenses → Dashboard → Simple Studio → Tax → Business Card → Subscription Hub.

**Exit (each host):**
- [ ] 1/3, 1/2, 2/3 Split View functional
- [ ] Slide Over functional
- [ ] Padding audit passes against `BuxPadLayout`
- [ ] Zero edits to composed feature view sources

---

### STEP 4 — iPad Interactions (required)

**Create:** `Core/Platform/iPad/BuxKeyboardCommands.swift`

| Action | Shortcut |
|--------|----------|
| New expense | ⌘N |
| Search | ⌘F |
| Save | ⌘S |
| Settings | ⌘, |
| Close | ⌘W |
| Undo | ⌘Z |
| Redo | ⌘⇧Z |

Plus: hover on custom rows, context menus, drag-and-drop (expenses, invoices, receipts), `@FocusState` in pad form wrappers, Scribble verified, arrow-key list navigation.

**Exit:** Full iPad HIG interaction checklist passes.

---

### STEP 5 — Multitasking & Multi-Window (required)

- Additional `WindowGroup`s in `BuxMuseApp.swift`
- `NSUserActivity` state restoration
- Per-scene `BuxPadNavigationBrain` instances
- No content reload on `horizontalSizeClass` change

**Exit:** Stage Manager + two simultaneous windows with independent navigation.

---

### STEP 6 — M-Series Performance (required)

- Container-width metrics only on pad path
- Brain snapshot debounce on column transitions
- Business Card / share render at window-scene scale
- Instruments validation: iPad Pro M-series @ 120Hz, no dropped frames on resize

**Exit:** < 16ms brain refresh; 120Hz sustained during split drag.

---

### STEP 7 — External Display (required)

- `WindowGroup(id: "presentation")` for invoice preview + money map
- Connect/disconnect handlers in `BuxPadNavigationBrain`
- Complementary content on external display; controls stay on iPad

**Exit:** Graceful disconnect without data loss.

---

## 8. Files Explicitly Frozen

- All `Features/**` except new `Features/iPad/**`
- All `Brain/**` except new `BuxPadNavigationBrain.swift`
- All `Core/DesignSystem/**` except new `Core/DesignSystem/iPad/**`
- `BuxTokens.swift`, `BuxLayout.swift`, `BuxAdaptiveUI.swift` — **no edits** (pad tokens live in `BuxPadLayout`)
- Tax compute, financial engines, localization, `ContentView.swift`
- `scripts/**` — **no access**

---

## 9. Testing Matrix (All P0)

| Configuration | Required |
|---------------|----------|
| iPad Pro 13" landscape | ✓ |
| iPad Mini portrait | ✓ |
| Split View 1/3, 1/2, 2/3 | ✓ |
| Slide Over | ✓ |
| Stage Manager resize | ✓ |
| Magic Keyboard + trackpad | ✓ |
| Apple Pencil Scribble | ✓ |
| External display | ✓ |
| iPhone regression (15 Pro) | ✓ |

---

## 10. Risk Register

| Risk | Mitigation |
|------|------------|
| Composing frozen views limits layout | Pad hosts own chrome/metrics; environment overrides |
| Duplicate UI maintenance | Single `BuxPadShell` + hosts; feature views shared |
| pbxproj file additions | All new files registered in `BuxMuse.xcodeproj` only |
| Scope creep outside folder | Hard rule §0.1 — reject any out-of-tree change |

---

## 11. Implementation

**Step 1 plan (active):** `docs/superpowers/plans/2026-06-08-ipados-native-support-step1.md`

Step 2 does not start until Step 1 exit checklist passes.
