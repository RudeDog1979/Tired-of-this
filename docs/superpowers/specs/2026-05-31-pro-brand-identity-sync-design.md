# Pro Brand Identity Sync — Design Spec

**Date:** 2026-05-31  
**Status:** Approved for implementation  
**Scope:** Pro Studio only — business card → invoice brand inheritance  
**Out of scope:** Simple Studio, multi-business profiles, canvas geometry on A4, invoice → card reverse sync

---

## 1. Problem

Pro users design a business card, then create PDF invoices that look unrelated (different colors, typography, header mood). That breaks the “professional brand” promise and makes Pro feel fragmented.

**Goal:** One primary business card drives default invoice branding. Users can save unlimited cards; exactly **one** is the **Primary brand card** for invoices. Override in Invoice Designer when they want something different.

---

## 2. Product rules

| Rule | Behavior |
|------|----------|
| Tier gate | Only when `SettingsStore.studioMode == .pro` |
| Primary card | One `primaryBrandDesignID` in the card library; user sets via star action in gallery |
| Default for new invoices | New Pro invoices seed `InvoiceTemplateConfig` from primary card (unless user previously unlinked) |
| Existing sent invoices | Unchanged — `InvoiceDesignerSnapshot` on each invoice stays frozen |
| Edit primary card | Updates global invoice defaults + live preview for **draft** invoices without snapshot |
| Unlink | User opts out of auto-sync; invoice branding becomes independent until “Sync from card” |
| Simple Studio | No reads, no UI, no migration |

**Multi-business:** Not supported at launch. One app = one business identity. Document as future work if users need separate brands.

---

## 3. Data model

### 3.1 `ProBusinessCardLibrary` (extend)

```swift
public var primaryBrandDesignID: UUID?  // NEW — card used for invoice brand sync
```

- Decode: missing key → `nil` (runtime falls back to first saved non-draft design).
- When primary is deleted, reassign to first remaining saved design.
- `selectedDesignID` stays as “last opened in editor” — separate concern.

### 3.2 `StudioInvoiceSettings` (extend)

```swift
public var brandSyncFromPrimaryCard: Bool  // default true
public var brandSyncSourceDesignID: UUID? // last applied primary id (for stale banner)
public var brandSyncSourceUpdatedAt: Date? // design.updatedAt when last synced
```

- `brandSyncFromPrimaryCard == false` → user unlinked; new invoices use `defaultTemplateConfig` as-is until sync.
- On successful sync, update `defaultTemplateConfig` + source metadata.

### 3.3 No separate `ProBrandIdentity` blob (V1)

Brand is **derived** from `ProBusinessCardDesign` via `ProBrandIdentityMapper` → `InvoiceTemplateConfig`. Avoids drift between card state and a duplicate identity store.

---

## 4. Mapping: card design → invoice config

New file: `ProBrandIdentityMapper.swift`

### 4.1 Palette

| Card field | Invoice field |
|------------|---------------|
| `palette.accentHex` | `primaryColorHex` |
| `palette.foregroundHex` or muted accent | `secondaryColorHex` |
| Logo: `StudioProfile.logoData` first; else card photo if `options.showsPhoto` | Header logo via existing `profile.logoData` path (optional: copy photo to profile on sync — **no**, keep profile logo authoritative; card photo only if profile has no logo and sync copies path reference in render context later — **V1: profile logo only** to avoid side effects) |

**V1 logo rule:** Invoice header uses `StudioProfile.logoData` only. Card sync does not mutate profile. If user wants logo on invoice, they set it in profile or we add “Use card logo” toggle in Branding tab (stretch — skip V1 unless trivial).

### 4.2 Typography

| `style.fontPairing` | `InvoiceTypographyStyle` |
|---------------------|--------------------------|
| `.modern` | `.systemSans` |
| `.classic` | `.systemSerif` |
| `.bold` | `.systemSans` |

### 4.3 Template style (family heuristic)

| Card template families | `InvoiceTemplateStyle` |
|------------------------|------------------------|
| `boldTrade`, `neonEdge`, `gradientPro`, `twoToneSplit`, `glassFrost`, `stampBadge` | `.modern` |
| `minimalMono`, `lineMinimal`, `swissGrid`, `geometricGrid`, `diagonalBands`, `cornerBlocks`, `splitVertical`, `arcSweep`, `hexAccent`, `circleFrame` | `.minimalist` |
| `classic`, `editorial`, `letterpress`, `monogram`, `logoMark`, `watermark`, `qrFirst`, `editorial` | `.executive` |
| Unknown / legacy | `.modern` |

### 4.4 Corners & density

- Dark-background card families → `cornerStyle: .soft`, `density: .comfortable`
- Minimal families → `cornerStyle: .sharp`, `density: .compact`
- Executive → `cornerStyle: .soft`, `density: .comfortable`

### 4.5 Logo position

- Card `textAlignment == .center` → `logoPosition: .topLeft` (invoice convention)
- Else inherit from `StudioInvoiceSettings.logoPosition` or `.topLeft`

---

## 5. Sync triggers

```text
Primary card set/changed     → ProBrandSyncEngine.syncDefaultsIfEnabled()
Primary card saved (update)  → same, if design.id == primaryBrandDesignID
User taps "Sync from card"   → force sync, set brandSyncFromPrimaryCard = true
User taps "Customize only"   → brandSyncFromPrimaryCard = false
New invoice (no snapshot)    → InvoiceDesignerEngine.loadDefaults uses synced defaultTemplateConfig
```

`ProBrandSyncEngine` lives under `BuxMuse/Features/Studio/Core/`, called from `StudioStore.updateBusinessCardDesign`, set-primary action, and Invoice Designer UI.

---

## 6. UI

### 6.1 Business Card gallery / library

- Star affordance on saved design tile: **“Primary for invoices”**
- Only one starred; tapping star on B removes star from A
- Subtitle on primary tile: “Invoice brand”
- First saved design becomes primary automatically if none set

### 6.2 Invoice Designer → Branding tab

When `brandSyncFromPrimaryCard && primary exists`:

- Info banner: “Matching **[Card title]**” with card palette swatch
- If `design.updatedAt > brandSyncSourceUpdatedAt`: subtle “Card updated — tap to refresh”

Actions:

- **Sync from business card** — resets `templateConfig` from mapper
- **Customize invoice only** — sets unlink flag; no further auto-sync until user re-syncs

When unlinked:

- Banner: “Custom invoice branding”
- **Sync from business card** still available

### 6.3 No changes to Simple Studio invoice sheet

---

## 7. Architecture

```text
ProBusinessCardDesign (primary)
        │
        ▼
ProBrandIdentityMapper.makeTemplateConfig(from:)
        │
        ▼
StudioInvoiceSettings.defaultTemplateConfig  (+ metadata)
        │
        ▼
InvoiceDesignerEngine.loadDefaults()  →  new invoices
        │
        ▼
InvoiceDesignerSnapshot (locked per invoice on send)
```

**Files (new):**

- `BuxMuse/Features/Studio/Core/ProBrandIdentityMapper.swift`
- `BuxMuse/Features/Studio/Core/ProBrandSyncEngine.swift`

**Files (modify):**

- `ProBusinessCardModels.swift` — `primaryBrandDesignID`
- `StudioSEEngines.swift` — `StudioInvoiceSettings` fields
- `StudioStore.swift` — primary setters, sync on card update, delete fallback
- `InvoiceDesignerEngine.swift` — prefer brand-synced defaults
- `InvoiceDesignerHubView.swift` — Branding tab banner + actions
- `ProBusinessCardStudioView.swift` / `BusinessCardYourDesignsLibraryView` — primary star UI

---

## 8. Testing

New: `BuxMuseTests/ProBrandIdentityMapperTests.swift`

- Palette maps correctly for sample designs
- Template family mapping for representative templates (boldTrade → modern, minimalMono → minimalist, classic → executive)
- Font pairing mapping
- Primary fallback when ID nil
- Sync does not run when `brandSyncFromPrimaryCard == false`
- Deleting primary reassigns to next saved design

Extend `ProBusinessCardModelsTests` for `primaryBrandDesignID` decode default.

---

## 9. Non-goals (V1)

- Invoice header shapes matching card canvas geometry
- Shared preset picker component extraction (can follow later)
- Profile logo auto-import from card photo
- Multiple businesses / brand profiles per app
- Pushing invoice color changes back to card

---

## 10. Success criteria

1. User sets card A as primary → new Pro invoice preview uses A’s colors and template mood
2. User edits primary card colors → draft invoice defaults update (if sync enabled)
3. User unlinks → edits invoice colors → card save does not overwrite invoice config
4. User re-syncs → invoice branding matches card again
5. Simple Studio behavior unchanged
6. All new unit tests pass
