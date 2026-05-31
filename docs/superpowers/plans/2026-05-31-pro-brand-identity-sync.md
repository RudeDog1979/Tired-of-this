# Pro Brand Identity Sync — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pro invoices inherit branding from one primary business card by default, with optional unlink and manual re-sync in Invoice Designer.

**Architecture:** Extend `ProBusinessCardLibrary` with `primaryBrandDesignID`. Map primary card → `InvoiceTemplateConfig` via `ProBrandIdentityMapper`. `ProBrandSyncEngine` writes synced config into `StudioInvoiceSettings.defaultTemplateConfig` on card save / primary change / user action. `InvoiceDesignerEngine` consumes existing defaults path. Per-invoice snapshots unchanged.

**Tech Stack:** Swift, SwiftUI, Swift Testing / XCTest, existing `StudioStore` JSON persistence.

**Spec:** `docs/superpowers/specs/2026-05-31-pro-brand-identity-sync-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `ProBrandIdentityMapper.swift` | Pure mapping card design → `InvoiceTemplateConfig` |
| `ProBrandSyncEngine.swift` | Orchestrates sync into `StudioInvoiceSettings`, stale detection |
| `ProBusinessCardModels.swift` | `primaryBrandDesignID` + `primaryBrandDesign` helper |
| `StudioSEEngines.swift` | Brand sync flags on `StudioInvoiceSettings` |
| `StudioStore.swift` | Primary setter, sync hooks on CRUD |
| `InvoiceDesignerEngine.swift` | Load path unchanged; defaults already synced |
| `InvoiceDesignerHubView.swift` | Branding tab UI |
| Card gallery views | Primary star UI |
| `ProBrandIdentityMapperTests.swift` | Unit tests |

---

### Task 1: Model extensions + decode safety

**Files:**
- Modify: `BuxMuse/Features/Studio/BusinessCard/ProBusinessCardModels.swift`
- Modify: `BuxMuse/Features/Studio/Core/StudioSEEngines.swift`
- Test: `BuxMuseTests/ProBusinessCardModelsTests.swift`

- [ ] **Step 1: Write failing test for library primary decode**

```swift
func testBusinessCardLibraryDecodesWithoutPrimaryBrandID() throws {
    let json = #"{"designs":[],"selectedDesignID":null}"#
    let lib = try JSONDecoder().decode(ProBusinessCardLibrary.self, from: Data(json.utf8))
    XCTAssertNil(lib.primaryBrandDesignID)
}

func testInvoiceSettingsDecodesBrandSyncDefaults() throws {
    let settings = StudioInvoiceSettings()
    XCTAssertTrue(settings.brandSyncFromPrimaryCard)
    XCTAssertNil(settings.brandSyncSourceDesignID)
}
```

- [ ] **Step 2: Run tests**

Run: `xcodebuild test -scheme BuxMuse -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:BuxMuseTests/ProBusinessCardModelsTests 2>&1 | tail -20`

Expected: FAIL — missing properties

- [ ] **Step 3: Add properties**

`ProBusinessCardLibrary`:
```swift
public var primaryBrandDesignID: UUID?

public var primaryBrandDesign: ProBusinessCardDesign? {
    if let id = primaryBrandDesignID {
        return savedDesigns.first { $0.id == id }
    }
    return savedDesigns.first
}
```

Update `CodingKeys`, init, encode, decode with `decodeIfPresent` default `nil`.

`StudioInvoiceSettings`:
```swift
public var brandSyncFromPrimaryCard: Bool = true
public var brandSyncSourceDesignID: UUID? = nil
public var brandSyncSourceUpdatedAt: Date? = nil
```

Same Codable pattern with backward-compatible decode.

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add BuxMuse/Features/Studio/BusinessCard/ProBusinessCardModels.swift \
        BuxMuse/Features/Studio/Core/StudioSEEngines.swift \
        BuxMuseTests/ProBusinessCardModelsTests.swift
git commit -m "feat(studio): add primary brand card and invoice sync settings"
```

---

### Task 2: ProBrandIdentityMapper

**Files:**
- Create: `BuxMuse/Features/Studio/Core/ProBrandIdentityMapper.swift`
- Create: `BuxMuseTests/ProBrandIdentityMapperTests.swift`
- Modify: `BuxMuse.xcodeproj/project.pbxproj` (add files to target)

- [ ] **Step 1: Write failing mapper tests**

```swift
import XCTest
@testable import BuxMuse

final class ProBrandIdentityMapperTests: XCTestCase {

    func testBoldTradeMapsToModernTemplate() {
        var design = ProBusinessCardDesign(title: "T", template: .boldTrade)
        design.applyTemplateDefaults()
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.style, .modern)
        XCTAssertEqual(config.primaryColorHex.uppercased(), design.palette.accentHex.uppercased())
    }

    func testMinimalMonoMapsToMinimalist() {
        var design = ProBusinessCardDesign(title: "T", template: .minimalMono)
        design.applyTemplateDefaults()
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.style, .minimalist)
    }

    func testClassicFontPairingMapsToSerif() {
        var design = ProBusinessCardDesign(title: "T", template: .classic)
        design.applyTemplateDefaults()
        design.style.fontPairing = .classic
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.typography, .systemSerif)
    }

    func testBoldFontPairingMapsToSans() {
        var design = ProBusinessCardDesign(title: "T", template: .boldTrade)
        design.applyTemplateDefaults()
        design.style.fontPairing = .bold
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.typography, .systemSans)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement mapper**

```swift
enum ProBrandIdentityMapper {

    static func templateConfig(
        from design: ProBusinessCardDesign,
        logoPosition: InvoiceLogoPosition
    ) -> InvoiceTemplateConfig {
        InvoiceTemplateConfig(
            style: invoiceStyle(for: design.template),
            primaryColorHex: design.palette.accentHex,
            secondaryColorHex: secondaryHex(from: design.palette),
            typography: typography(from: design.style.fontPairing),
            cornerStyle: cornerStyle(for: design.template),
            density: density(for: design.template),
            logoPosition: logoPosition
        )
    }

    private static func secondaryHex(from palette: ProBusinessCardPalette) -> String {
        palette.foregroundHex
    }

    private static func typography(from pairing: ProBusinessCardFontPairing) -> InvoiceTypographyStyle {
        switch pairing {
        case .modern, .bold: return .systemSans
        case .classic: return .systemSerif
        }
    }

    private static func invoiceStyle(for template: ProBusinessCardTemplate) -> InvoiceTemplateStyle {
        switch template {
        case .boldTrade, .neonEdge, .gradientPro, .twoToneSplit, .glassFrost, .stampBadge:
            return .modern
        case .minimalMono, .lineMinimal, .swissGrid, .geometricGrid, .diagonalBands,
             .cornerBlocks, .splitVertical, .arcSweep, .hexAccent, .circleFrame:
            return .minimalist
        case .classic, .editorial, .letterpress, .monogram, .logoMark, .watermark, .qrFirst:
            return .executive
        case .photoForward:
            return .modern
        }
    }

    private static func cornerStyle(for template: ProBusinessCardTemplate) -> InvoiceCornerStyle {
        switch invoiceStyle(for: template) {
        case .minimalist: return .sharp
        case .modern, .executive: return .soft
        }
    }

    private static func density(for template: ProBusinessCardTemplate) -> InvoiceDensity {
        invoiceStyle(for: template) == .minimalist ? .compact : .comfortable
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add BuxMuse/Features/Studio/Core/ProBrandIdentityMapper.swift \
        BuxMuseTests/ProBrandIdentityMapperTests.swift \
        BuxMuse.xcodeproj/project.pbxproj
git commit -m "feat(studio): map business card design to invoice template config"
```

---

### Task 3: ProBrandSyncEngine + StudioStore hooks

**Files:**
- Create: `BuxMuse/Features/Studio/Core/ProBrandSyncEngine.swift`
- Modify: `BuxMuse/Features/Studio/Core/StudioStore.swift`
- Test: extend `BuxMuseTests/ProBrandIdentityMapperTests.swift`

- [ ] **Step 1: Write failing sync test**

Use in-memory or test helper to build `StudioStore` state, or test engine in isolation:

```swift
func testSyncWritesDefaultTemplateConfigWhenEnabled() {
    var settings = StudioInvoiceSettings()
    settings.brandSyncFromPrimaryCard = true
    var design = ProBusinessCardDesign(title: "Main", template: .classic)
    design.applyTemplateDefaults()
    var library = ProBusinessCardLibrary(designs: [design], selectedDesignID: design.id, primaryBrandDesignID: design.id)

    let changed = ProBrandSyncEngine.syncInvoiceDefaults(
        invoiceSettings: &settings,
        library: library,
        logoPosition: settings.logoPosition,
        force: false
    )
    XCTAssertTrue(changed)
    XCTAssertEqual(settings.brandSyncSourceDesignID, design.id)
    XCTAssertNotNil(settings.defaultTemplateConfig)
    XCTAssertEqual(settings.defaultTemplateConfig?.style, .executive)
}

func testSyncSkippedWhenUnlinked() {
    var settings = StudioInvoiceSettings()
    settings.brandSyncFromPrimaryCard = false
    var design = ProBusinessCardDesign(title: "Main", template: .classic)
    design.applyTemplateDefaults()
    let library = ProBusinessCardLibrary(designs: [design], primaryBrandDesignID: design.id)

    let changed = ProBrandSyncEngine.syncInvoiceDefaults(
        invoiceSettings: &settings,
        library: library,
        logoPosition: .topLeft,
        force: false
    )
    XCTAssertFalse(changed)
}
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement sync engine**

```swift
enum ProBrandSyncEngine {

    @discardableResult
    static func syncInvoiceDefaults(
        invoiceSettings: inout StudioInvoiceSettings,
        library: ProBusinessCardLibrary,
        logoPosition: InvoiceLogoPosition,
        force: Bool
    ) -> Bool {
        guard force || invoiceSettings.brandSyncFromPrimaryCard else { return false }
        guard let design = library.primaryBrandDesign else { return false }

        let mapped = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: logoPosition)
        invoiceSettings.defaultTemplateConfig = mapped
        invoiceSettings.brandSyncSourceDesignID = design.id
        invoiceSettings.brandSyncSourceUpdatedAt = design.updatedAt
        if force {
            invoiceSettings.brandSyncFromPrimaryCard = true
        }
        return true
    }

    static func isStale(invoiceSettings: StudioInvoiceSettings, design: ProBusinessCardDesign) -> Bool {
        guard invoiceSettings.brandSyncSourceDesignID == design.id,
              let syncedAt = invoiceSettings.brandSyncSourceUpdatedAt else { return true }
        return design.updatedAt > syncedAt
    }
}
```

- [ ] **Step 4: Wire StudioStore**

Add methods:

```swift
public func setPrimaryBrandDesign(id: UUID) {
    guard businessCardLibrary.designs.contains(where: { $0.id == id && !$0.isDraft }) else { return }
    businessCardLibrary.primaryBrandDesignID = id
    ProBrandSyncEngine.syncInvoiceDefaults(
        invoiceSettings: &invoiceSettings,
        library: businessCardLibrary,
        logoPosition: invoiceSettings.logoPosition,
        force: false
    )
    save()
}

public func syncInvoiceBrandFromPrimaryCard(force: Bool = true) {
    ProBrandSyncEngine.syncInvoiceDefaults(
        invoiceSettings: &invoiceSettings,
        library: businessCardLibrary,
        logoPosition: invoiceSettings.logoPosition,
        force: force
    )
    save()
}

public func unlinkInvoiceBrandFromCard() {
    invoiceSettings.brandSyncFromPrimaryCard = false
    save()
}
```

In `updateBusinessCardDesign(_:)` after update, if `design.id == businessCardLibrary.primaryBrandDesignID`:
```swift
_ = ProBrandSyncEngine.syncInvoiceDefaults(
    invoiceSettings: &invoiceSettings,
    library: businessCardLibrary,
    logoPosition: invoiceSettings.logoPosition,
    force: false
)
```

In `deleteBusinessCardDesigns`, when primary deleted:
```swift
if idSet.contains(businessCardLibrary.primaryBrandDesignID ?? UUID()) {
    businessCardLibrary.primaryBrandDesignID = businessCardLibrary.savedDesigns.first?.id
    syncInvoiceBrandFromPrimaryCard(force: false)
}
```

In `seedBusinessCardLibraryIfNeeded`, set primary to first starter:
```swift
businessCardLibrary.primaryBrandDesignID = businessCardLibrary.savedDesigns.first?.id
syncInvoiceBrandFromPrimaryCard(force: false)
```

- [ ] **Step 5: Run tests — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add BuxMuse/Features/Studio/Core/ProBrandSyncEngine.swift \
        BuxMuse/Features/Studio/Core/StudioStore.swift \
        BuxMuseTests/ProBrandIdentityMapperTests.swift \
        BuxMuse.xcodeproj/project.pbxproj
git commit -m "feat(studio): sync invoice defaults from primary business card"
```

---

### Task 4: Primary star UI in card gallery

**Files:**
- Modify: `BuxMuse/Features/Studio/BusinessCard/ProBusinessCardStudioView.swift`
- Find and modify: `BusinessCardYourDesignsLibraryView` (or designs grid cell component)

- [ ] **Step 1: Add star button on saved design tiles**

On each non-draft tile in designs grid / library:
- Filled star when `design.id == library.primaryBrandDesignID`
- Outline star otherwise
- Tap calls `studioStore.setPrimaryBrandDesign(id: design.id)`
- Accessibility label: “Primary for invoices”

Show caption “Invoice brand” under primary tile only.

- [ ] **Step 2: Manual QA**

1. Open Business Card Studio → saved designs
2. Star design B → design A loses star
3. Relaunch app → primary persists

- [ ] **Step 3: Commit**

```bash
git add BuxMuse/Features/Studio/BusinessCard/ProBusinessCardStudioView.swift
git commit -m "feat(studio): mark primary business card for invoice branding"
```

(Add library view path if separate file.)

---

### Task 5: Invoice Designer Branding tab

**Files:**
- Modify: `BuxMuse/Features/Studio/Views/InvoiceDesignerHubView.swift`
- Modify: `BuxMuse/Features/Studio/Views/StudioInvoiceViews.swift` (pass store actions if needed)

- [ ] **Step 1: Add brand sync banner above template style picker**

When Pro mode and primary card exists:

```swift
private var brandSyncBanner: some View {
    Group {
        if settingsStore.studioMode == .pro,
           let primary = store.businessCardLibrary.primaryBrandDesign {
            VStack(alignment: .leading, spacing: 8) {
                if store.invoiceSettings.brandSyncFromPrimaryCard {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: primary.palette.accentHex)).frame(width: 12, height: 12)
                        Text("Matching \"\(primary.title)\"")
                            .font(.subheadline.weight(.semibold))
                    }
                    if ProBrandSyncEngine.isStale(invoiceSettings: store.invoiceSettings, design: primary) {
                        Text("Card updated — sync to refresh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Custom invoice branding")
                        .font(.subheadline.weight(.semibold))
                }
                HStack {
                    BuxButton(title: "Sync from card", systemImage: "arrow.triangle.2.circlepath", role: .secondary) {
                        store.syncInvoiceBrandFromPrimaryCard(force: true)
                        engine.templateConfig = store.invoiceSettings.defaultTemplateConfig ?? engine.templateConfig
                    }
                    if store.invoiceSettings.brandSyncFromPrimaryCard {
                        BuxButton(title: "Customize only", systemImage: "pencil", role: .secondary) {
                            store.unlinkInvoiceBrandFromCard()
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}
```

Insert at top of `brandingControls`.

When user edits colors manually while synced, optionally auto-unlink on first manual change (simplest: unlink on any `templateConfig` mutation in branding tab — use `onChange` of style/colors). **Recommendation:** auto-unlink when user changes any branding control while synced.

- [ ] **Step 2: Wire engine refresh after sync**

Ensure `StudioInvoiceEditorView` passes updated `defaultTemplateConfig` into engine on sync (banner callback above).

- [ ] **Step 3: Manual QA**

1. Set primary card with red accent
2. New invoice → Branding shows red + “Matching …”
3. Customize only → change color → card edit does not revert invoice
4. Sync from card → colors match card again

- [ ] **Step 4: Commit**

```bash
git add BuxMuse/Features/Studio/Views/InvoiceDesignerHubView.swift
git commit -m "feat(studio): invoice designer brand sync banner and controls"
```

---

### Task 6: Pro gate + regression pass

**Files:**
- Verify: Simple Studio paths untouched

- [ ] **Step 1: Confirm Simple invoice sheet has no new imports**

- [ ] **Step 2: Run full unit tests**

Run: `xcodebuild test -scheme BuxMuse -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:BuxMuseTests 2>&1 | tail -30`

Expected: All tests PASS

- [ ] **Step 3: Commit any fixes**

```bash
git commit -m "test(studio): pro brand identity sync regression fixes"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| `primaryBrandDesignID` | Task 1, 3, 4 |
| Brand sync settings | Task 1, 3 |
| Mapper palette/typography/template | Task 2 |
| Sync triggers on save/primary | Task 3 |
| Gallery star UI | Task 4 |
| Invoice Designer banner | Task 5 |
| Simple Studio untouched | Task 6 |
| Unit tests | Tasks 1–3 |
| Snapshot immutability | Existing behavior — no task needed |

## Estimated effort

~4–6 hours focused implementation + QA for a familiar contributor.
