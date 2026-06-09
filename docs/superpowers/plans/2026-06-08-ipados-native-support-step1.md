# BuxMuse iPadOS Step 1 — BuxPad Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the BuxPad foundation layer — new files only, zero feature/logic deletion, iPhone path untouched.

**Architecture:** All iPad tokens, environment, presentation policy, split scaffold, and navigation brain live in new `Core/Platform/iPad/`, `Core/DesignSystem/iPad/`, and `Brain/Engines/BuxPadNavigationBrain.swift`. Only three shell files get additive wiring.

**Tech Stack:** SwiftUI, iOS 18+, `@MainActor`, Swift Testing (`BuxMuseTests`)

**Approved spec:** `docs/superpowers/specs/2026-06-08-ipados-native-support-design.md`

---

## Immutable Rules (Every Task)

1. **Folder:** Only edit files under `iOS/Tired of this/`.
2. **No deletion:** Do not remove existing code, features, logic, math, or views. Additive changes only.
3. **Logic ban:** Do **not** open or modify:
   - `Brain/BuxMuseBrain.swift` and all `Brain/Engines/*` except **new** `BuxPadNavigationBrain.swift`
   - `Features/**` (any existing file)
   - Tax/financial engines, `StudioStore`, persistence, `TaxManager`, JSON resources
   - `BuxTokens.swift`, `BuxLayout.swift`, `BuxAdaptiveUI.swift`
4. **Allowed shell touches (additive only):** `AppContainer.swift`, `BuxMuseApp.swift`, `RootView.swift`
5. **Xcode:** `BuxMuse/` uses `PBXFileSystemSynchronizedRootGroup` — new files auto-sync; no `pbxproj` edits unless build fails.

---

## File Map (Step 1 Creates)

| File | Responsibility |
|------|----------------|
| `BuxMuse/Core/Platform/iPad/BuxPadLayout.swift` | iPad spacing tokens + margin resolver |
| `BuxMuse/Core/Platform/iPad/BuxAdaptiveEnvironment.swift` | `BuxLayoutMode`, environment keys, idiom gate |
| `BuxMuse/Core/Platform/iPad/BuxContainerMetrics.swift` | Container width/height (replaces UIScreen on pad path) |
| `BuxMuse/Core/Platform/iPad/BuxAdaptivePresentation.swift` | Presentation mode enum + policy resolver |
| `BuxMuse/Core/Platform/iPad/BuxPadSplitScaffold.swift` | Reusable sidebar + detail split |
| `BuxMuse/Core/DesignSystem/iPad/BuxPadChrome.swift` | Pad modifiers + empty detail placeholder |
| `BuxMuse/Brain/Engines/BuxPadNavigationBrain.swift` | Pad-only UI routing state |
| `BuxMuseTests/iPad/BuxPadNavigationBrainTests.swift` | Brain + layout unit tests |

---

### Task 1: BuxPadLayout tokens

**Files:**
- Create: `BuxMuse/Core/Platform/iPad/BuxPadLayout.swift`

- [ ] **Step 1: Create `BuxPadLayout.swift`**

```swift
//
//  BuxPadLayout.swift
//  BuxMuse — iPad-only spacing tokens (8pt grid). iPhone uses BuxTokens/BuxLayout unchanged.
//

import SwiftUI

enum BuxPadLayout {
    static let unit: CGFloat = 8

    // Horizontal margins
    static let marginCompact: CGFloat = 16
    static let marginRegular: CGFloat = 24

    // Readable content column
    static let readableMaxWidth: CGFloat = 720

    // Split columns
    static let splitSidebarMin: CGFloat = 280
    static let splitSidebarIdeal: CGFloat = 320
    static let splitSidebarMax: CGFloat = 380
    static let columnGap: CGFloat = 16

    // Detail pane card inset
    static let detailInsetCompact: CGFloat = 16
    static let detailInsetRegular: CGFloat = 20

    // Toolbar
    static let toolbarSpacing: CGFloat = 12

    static func horizontalMargin(layoutMode: BuxLayoutMode) -> CGFloat {
        layoutMode == .regular ? marginRegular : marginCompact
    }

    static func detailInset(layoutMode: BuxLayoutMode) -> CGFloat {
        layoutMode == .regular ? detailInsetRegular : detailInsetCompact
    }

    /// Proportional sidebar width clamped to min/ideal/max.
    static func splitSidebarWidth(containerWidth: CGFloat, layoutMode: BuxLayoutMode) -> CGFloat {
        guard layoutMode == .regular, containerWidth > 0 else { return splitSidebarIdeal }
        let proposed = containerWidth * 0.32
        return min(splitSidebarMax, max(splitSidebarMin, proposed))
    }
}
```

- [ ] **Step 2: Build verify**

Run (from `iOS/Tired of this/`):
```bash
xcodebuild -scheme BuxMuse -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED (or compile error only if folder missing — fix path)

- [ ] **Step 3: Commit** *(only if user requests commit)*

---

### Task 2: BuxAdaptiveEnvironment

**Files:**
- Create: `BuxMuse/Core/Platform/iPad/BuxAdaptiveEnvironment.swift`

- [ ] **Step 1: Create environment types and modifiers**

```swift
//
//  BuxAdaptiveEnvironment.swift
//  BuxMuse — iPad layout mode + idiom gate. Never affects iPhone rendering.
//

import SwiftUI

enum BuxLayoutMode: Equatable {
    case compact
    case regular
}

enum BuxPadIdiom {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

private struct BuxLayoutModeKey: EnvironmentKey {
    static let defaultValue: BuxLayoutMode = .compact
}

private struct BuxContainerWidthEnvKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct BuxContainerHeightEnvKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var buxLayoutMode: BuxLayoutMode {
        get { self[BuxLayoutModeKey.self] }
        set { self[BuxLayoutModeKey.self] = newValue }
    }

    var buxContainerWidth: CGFloat {
        get { self[BuxContainerWidthEnvKey.self] }
        set { self[BuxContainerWidthEnvKey.self] = newValue }
    }

    var buxContainerHeight: CGFloat {
        get { self[BuxContainerHeightEnvKey.self] }
        set { self[BuxContainerHeightEnvKey.self] = newValue }
    }
}

extension BuxLayoutMode {
    init(horizontalSizeClass: UserInterfaceSizeClass?) {
        self = horizontalSizeClass == .regular ? .regular : .compact
    }
}

private struct BuxPadEnvironmentModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .environment(\.buxLayoutMode, BuxLayoutMode(horizontalSizeClass: horizontalSizeClass))
    }
}

extension View {
    /// Apply on iPad shell only. Sets `buxLayoutMode` from size class.
    func buxPadEnvironment() -> some View {
        modifier(BuxPadEnvironmentModifier())
    }
}
```

- [ ] **Step 2: Build verify** — same `xcodebuild` command, BUILD SUCCEEDED

---

### Task 3: BuxContainerMetrics

**Files:**
- Create: `BuxMuse/Core/Platform/iPad/BuxContainerMetrics.swift`

- [ ] **Step 1: Create metrics reporter**

```swift
//
//  BuxContainerMetrics.swift
//  BuxMuse — Reports container size into environment (pad path). No UIScreen.main.
//

import SwiftUI

private struct BuxContainerMetricsReporter: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { publish(geo.size) }
                        .onChange(of: geo.size) { _, newSize in publish(newSize) }
                }
            }
    }

    private func publish(_ size: CGSize) {
        // Preference-free: child views read via GeometryReader in hosts (Step 3).
        // This modifier sets environment on the measured view tree root.
    }
}

/// Reads geometry and injects width/height into SwiftUI environment.
struct BuxContainerMetricsView<Content: View>: View {
    @ViewBuilder var content: (CGFloat, CGFloat) -> Content

    var body: some View {
        GeometryReader { geo in
            content(geo.size.width, geo.size.height)
                .environment(\.buxContainerWidth, geo.size.width)
                .environment(\.buxContainerHeight, geo.size.height)
        }
    }
}

extension View {
    /// Wrap pad root content to publish container metrics.
    func buxPadReportsContainerMetrics() -> some View {
        BuxContainerMetricsView { width, height in
            self
                .environment(\.buxContainerWidth, width)
                .environment(\.buxContainerHeight, height)
        }
    }
}
```

- [ ] **Step 2: Build verify**

---

### Task 4: BuxAdaptivePresentation

**Files:**
- Create: `BuxMuse/Core/Platform/iPad/BuxAdaptivePresentation.swift`

- [ ] **Step 1: Create presentation policy**

```swift
//
//  BuxAdaptivePresentation.swift
//  BuxMuse — iPad presentation mode resolver. UI routing only — no business logic.
//

import SwiftUI

enum BuxPadPresentationSurface: Equatable {
    case splitColumn
    case sheetLarge
    case sheetMedium
    case popover
    case fullScreenCover
    case rootOverlay
}

enum BuxPadPresentationTrigger: Equatable {
    case expenseDetail
    case addExpense
    case subscriptionHub
    case goalDetail
    case insightDetail
    case studioTool
    case categoryPicker
    case notePicker
    case share
    case onboarding
}

enum BuxAdaptivePresentation {
    static func surface(
        for trigger: BuxPadPresentationTrigger,
        layoutMode: BuxLayoutMode,
        isPad: Bool
    ) -> BuxPadPresentationSurface {
        guard isPad else {
            // iPhone policy unchanged — callers keep existing presentation.
            switch trigger {
            case .expenseDetail: return .fullScreenCover
            case .subscriptionHub, .goalDetail, .insightDetail: return .rootOverlay
            case .categoryPicker, .notePicker: return .sheetMedium
            case .share: return .sheetLarge
            default: return .sheetLarge
            }
        }

        switch (trigger, layoutMode) {
        case (.expenseDetail, .regular): return .splitColumn
        case (.expenseDetail, .compact): return .sheetLarge
        case (.subscriptionHub, .regular): return .splitColumn
        case (.subscriptionHub, .compact): return .sheetLarge
        case (.goalDetail, .regular), (.insightDetail, .regular): return .splitColumn
        case (.goalDetail, .compact), (.insightDetail, .compact): return .sheetLarge
        case (.studioTool, .regular): return .splitColumn
        case (.studioTool, .compact): return .sheetLarge
        case (.categoryPicker, .regular), (.notePicker, .regular): return .sheetLarge
        case (.categoryPicker, .compact), (.notePicker, .compact): return .sheetMedium
        case (.share, _): return .popover
        case (.onboarding, _): return .fullScreenCover
        case (.addExpense, _): return .sheetLarge
        }
    }
}
```

- [ ] **Step 2: Build verify**

---

### Task 5: BuxPadSplitScaffold

**Files:**
- Create: `BuxMuse/Core/Platform/iPad/BuxPadSplitScaffold.swift`

- [ ] **Step 1: Create split scaffold (Invoice Designer pattern generalized)**

```swift
//
//  BuxPadSplitScaffold.swift
//  BuxMuse — Sidebar + detail split for regular width; stacked for compact.
//

import SwiftUI

struct BuxPadSplitScaffold<Sidebar: View, Detail: View>: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @Environment(\.buxContainerWidth) private var containerWidth

    @ViewBuilder var sidebar: () -> Sidebar
    @ViewBuilder var detail: () -> Detail
    var detailPlaceholder: String = "Select an item"

    var body: some View {
        Group {
            if layoutMode == .regular {
                HStack(spacing: BuxPadLayout.columnGap) {
                    sidebar()
                        .frame(width: BuxPadLayout.splitSidebarWidth(
                            containerWidth: containerWidth,
                            layoutMode: layoutMode
                        ))
                    detail()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, BuxPadLayout.horizontalMargin(layoutMode: layoutMode))
            } else {
                VStack(spacing: 0) {
                    sidebar()
                    detail()
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build verify**

---

### Task 6: BuxPadChrome

**Files:**
- Create: `BuxMuse/Core/DesignSystem/iPad/BuxPadChrome.swift`

- [ ] **Step 1: Create chrome modifiers + empty state**

```swift
//
//  BuxPadChrome.swift
//  BuxMuse — iPad scroll chrome, readable column, empty detail placeholder.
//

import SwiftUI

struct BuxPadDetailEmptyState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: BuxPadLayout.unit * 2) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BuxPadLayout.marginRegular)
    }
}

private struct BuxPadRootChromeModifier: ViewModifier {
    @Environment(\.buxLayoutMode) private var layoutMode

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, BuxPadLayout.horizontalMargin(layoutMode: layoutMode))
    }
}

private struct BuxPadReadableColumnModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: BuxPadLayout.readableMaxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func buxPadRootChrome() -> some View {
        modifier(BuxPadRootChromeModifier())
    }

    func buxPadReadableColumn() -> some View {
        modifier(BuxPadReadableColumnModifier())
    }

    func buxPadHoverable() -> some View {
        hoverEffect(.highlight)
    }
}
```

- [ ] **Step 2: Build verify**

---

### Task 7: BuxPadNavigationBrain

**Files:**
- Create: `BuxMuse/Brain/Engines/BuxPadNavigationBrain.swift`

- [ ] **Step 1: Create pad navigation brain (UI state only)**

```swift
//
//  BuxPadNavigationBrain.swift
//  BuxMuse — iPad-only navigation/presentation state. No business data.
//

import SwiftUI
import Combine

@MainActor
final class BuxPadNavigationBrain: ObservableObject {
    @Published var selectedExpenseId: UUID?
    @Published var selectedStudioDestination: String?
    @Published var selectedSettingsPath: String?
    @Published var isInspectorColumnVisible: Bool = true

    @Published var activePresentation: BuxPadPresentationTrigger?
    @Published private(set) var resolvedSurface: BuxPadPresentationSurface = .sheetLarge

    func resolvePresentation(
        trigger: BuxPadPresentationTrigger,
        layoutMode: BuxLayoutMode
    ) {
        activePresentation = trigger
        resolvedSurface = BuxAdaptivePresentation.surface(
            for: trigger,
            layoutMode: layoutMode,
            isPad: BuxPadIdiom.isPad
        )
    }

    func clearPresentation() {
        activePresentation = nil
    }

    func selectExpense(_ id: UUID?) {
        selectedExpenseId = id
        if id != nil {
            resolvePresentation(trigger: .expenseDetail, layoutMode: .regular)
        }
    }

    func clearExpenseSelection() {
        selectedExpenseId = nil
    }
}
```

- [ ] **Step 2: Build verify**

---

### Task 8: BuxPadNavigationBrain tests

**Files:**
- Create: `BuxMuseTests/iPad/BuxPadNavigationBrainTests.swift`

- [ ] **Step 1: Write tests**

```swift
//
//  BuxPadNavigationBrainTests.swift
//

import Testing
@testable import BuxMuse

@MainActor
struct BuxPadNavigationBrainTests {

    @Test func expenseSelection_setsId() {
        let brain = BuxPadNavigationBrain()
        let id = UUID()
        brain.selectExpense(id)
        #expect(brain.selectedExpenseId == id)
    }

    @Test func presentationPolicy_expenseDetail_regular_isSplitColumn() {
        let surface = BuxAdaptivePresentation.surface(
            for: .expenseDetail,
            layoutMode: .regular,
            isPad: true
        )
        #expect(surface == .splitColumn)
    }

    @Test func presentationPolicy_expenseDetail_compact_isSheetLarge() {
        let surface = BuxAdaptivePresentation.surface(
            for: .expenseDetail,
            layoutMode: .compact,
            isPad: true
        )
        #expect(surface == .sheetLarge)
    }

    @Test func padLayout_margins() {
        #expect(BuxPadLayout.horizontalMargin(layoutMode: .compact) == 16)
        #expect(BuxPadLayout.horizontalMargin(layoutMode: .regular) == 24)
    }

    @Test func padLayout_sidebarClamped() {
        let w = BuxPadLayout.splitSidebarWidth(containerWidth: 1200, layoutMode: .regular)
        #expect(w >= BuxPadLayout.splitSidebarMin)
        #expect(w <= BuxPadLayout.splitSidebarMax)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodebuild -scheme BuxMuse -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' test -only-testing:BuxMuseTests/BuxPadNavigationBrainTests 2>&1 | tail -30
```
Expected: All tests PASS

---

### Task 9: Wire AppContainer (additive only)

**Files:**
- Modify: `BuxMuse/Core/App/AppContainer.swift`

- [ ] **Step 1: Add `padNavigationBrain` property + init line**

After `navigationCoordinator` declaration (~line 25), add:
```swift
    public let padNavigationBrain: BuxPadNavigationBrain
```

In `init()`, after `navigationCoordinator = NavigationCoordinator()` (~line 46), add:
```swift
        padNavigationBrain = BuxPadNavigationBrain()
```

**Do not** modify any existing init logic, publishers, or brain wiring.

- [ ] **Step 2: Build verify**

---

### Task 10: Wire BuxMuseApp (additive only)

**Files:**
- Modify: `BuxMuse/BuxMuseApp.swift`

- [ ] **Step 1: Inject pad brain**

After `.environmentObject(container.navigationCoordinator)` (~line 22), add:
```swift
                .environmentObject(container.padNavigationBrain)
```

**Do not** change `WindowGroup`, `.task`, or `.onOpenURL` blocks.

- [ ] **Step 2: Build verify** — iPhone + iPad simulators

```bash
xcodebuild -scheme BuxMuse -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet build
xcodebuild -scheme BuxMuse -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' -quiet build
```

---

### Task 11: Wire RootView (additive iPad branch — no UX change yet)

**Files:**
- Modify: `BuxMuse/Core/App/RootView.swift`

- [ ] **Step 1: Add environment object + pad metrics on iPad only**

Add after existing `@EnvironmentObject` declarations (~line 20):
```swift
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain
```

Replace `var body: some View { coreTabView` with:
```swift
    var body: some View {
        Group {
            if BuxPadIdiom.isPad {
                coreTabView
                    .buxPadEnvironment()
                    .buxPadReportsContainerMetrics()
            } else {
                coreTabView
            }
        }
```

**Critical:** `coreTabView` and all overlays/sheets remain **identical**. iPad still shows current tabs in Step 1 — shell swap is Step 2.

**Do not** delete or reorder any existing modifiers on the outer chain.

- [ ] **Step 2: Build + smoke test**

Run app on iPad Pro 13" sim: tabs work, no layout regression.
Run on iPhone 16 Pro sim: pixel-identical to pre-Step-1.

- [ ] **Step 3: Grep guard — no forbidden edits**

```bash
cd "/Users/rodolfo/App Development/iOS/Tired of this"
git diff --name-only
```
Expected changed files **only**:
- `BuxMuse/Core/Platform/iPad/*.swift` (new)
- `BuxMuse/Core/DesignSystem/iPad/BuxPadChrome.swift` (new)
- `BuxMuse/Brain/Engines/BuxPadNavigationBrain.swift` (new)
- `BuxMuseTests/iPad/BuxPadNavigationBrainTests.swift` (new)
- `BuxMuse/Core/App/AppContainer.swift` (additive)
- `BuxMuse/BuxMuseApp.swift` (additive)
- `BuxMuse/Core/App/RootView.swift` (additive branch)
- `docs/superpowers/plans/2026-06-08-ipados-native-support-step1.md` (this plan)
- `docs/superpowers/specs/2026-06-08-ipados-native-support-design.md` (spec updates)

If any `Features/**`, `Brain/BuxMuseBrain*`, tax, or engine file appears in diff → **revert that file**.

---

## Step 1 Exit Checklist

- [ ] 7 new Swift files compile
- [ ] `BuxPadNavigationBrainTests` all pass
- [ ] iPhone sim build + run — unchanged UX
- [ ] iPad sim build + run — tabs work, `buxLayoutMode` active
- [ ] `git diff` shows no forbidden files
- [ ] Zero lines deleted from existing logic files (only additions)

---

## After Step 1

When exit checklist is complete, implement **Step 2 plan** (`BuxPadShell` + sidebar) — separate document, not started until Step 1 passes.

**Execution options:**
1. **Subagent-Driven** — fresh subagent per task, review between tasks
2. **Inline** — execute tasks in this session with checkpoints
