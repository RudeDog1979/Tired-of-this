# Business Card Studio — Pro Canvas Editor (Full Spec)

**Date:** 2026-05-31  
**Status:** Approved for implementation — shipping-grade, card editor only  
**North star:** Canva-class mobile business card designer for gig workers — tap the card, edit everything, export print-ready.

---

## 1. Product intent

BuxMuse Pro Business Card Studio must become the **best integrated card designer on mobile** for informal workers: faster than Canva for “I need a card now,” deeper than App Store template pickers for “I want it to look exactly like my brand.”

**Two modes, one document:**

| Mode | Purpose | Entry |
|------|---------|-------|
| **Quick Studio** (keep) | Fast content, toggles, identity presets, template pick, export | Current tabbed editor — unchanged flow |
| **Pro Canvas** (new primary visual editor) | Full WYSIWYG: tap any element, style it, move it, effects | Tap card preview → fullscreen canvas |

Quick Studio and Pro Canvas edit the **same persisted document**. Changes in either mode reflect instantly in the other.

**Interaction model: C**

- **Single tap** → select layer, show transform handles + contextual floating toolbar (font, color, shadow, etc.)
- **Double tap on text** → inline text edit on canvas (keyboard, live reflow)
- **Pinch on selection** → scale layer (respect min/max per type)
- **Drag** → move; **rotate handle** → rotation
- **Tap empty canvas** → deselect; show canvas-level tools (background, add layer, aspect)

---

## 2. Non-breaking contract (must preserve)

These surfaces **must not regress**:

| Surface | Contract |
|---------|----------|
| `ProBusinessCardDesign` | Remains the Codable root stored in `StudioStore.businessCardLibrary` |
| `ProBusinessCardLibrary` / CRUD | `addBusinessCardDesign`, `updateBusinessCardDesign`, duplicate, delete — same API |
| Gallery entry | `ProBusinessCardStudioView` — template gallery, saved designs list |
| Pro gate | Existing Pro upsell / access checks unchanged |
| Export | PDF (print size), PNG, vCard share — same entry points, same print dimensions |
| Simple Studio | `SimpleStudioBusinessCardSheet` and import path untouched |
| Image storage | `SimpleStudioScanImageStore` paths for photos/backgrounds |
| QR generation | `InvoiceDesignerEngine.generateQRImage` + `content.vCardPayload` |
| Photo Lab pipeline | `BusinessCardCIFilterPipeline` / `BusinessCardPhotoLabEngine` reused for image layers |
| Unit tests | `ProBusinessCardModelsTests` extended, not broken; migration tests added |

**Strategy:** extend the document model; migrate legacy designs on first open; render from canvas when present; keep legacy renderer as fallback only until migration coverage is 100%.

---

## 3. Architecture overview

New code lives under `BuxMuse/Features/Studio/BusinessCard/Canvas/` (and subfolders). Existing files remain; Pro Canvas **replaces** the need to patch `ProBusinessCardRenderer` for new features.

```
BusinessCard/
├── ProBusinessCardModels.swift          # extended with canvasDocument
├── ProBusinessCardStudioEditor.swift    # Quick Studio + opens Pro Canvas
├── ProBusinessCardStudioView.swift      # gallery (unchanged entry)
├── ProBusinessCardExport.swift          # renders via CanvasRenderer
├── Canvas/
│   ├── Models/
│   │   ├── CardCanvasDocument.swift     # root canvas state
│   │   ├── CardCanvasLayer.swift        # layer enum + payloads
│   │   ├── CardLayerTransform.swift
│   │   ├── CardTextStyle.swift
│   │   ├── CardImageStyle.swift
│   │   ├── CardShapeStyle.swift
│   │   ├── CardBackgroundStyle.swift
│   │   └── CardEffects.swift            # shadow, 3D preset, blend
│   ├── Migration/
│   │   └── CardCanvasMigrator.swift     # legacy design → canvas
│   ├── Engine/
│   │   ├── CardCanvasRenderer.swift     # SwiftUI render all layers
│   │   ├── CardCanvasHitTester.swift    # tap → layer id
│   │   ├── CardCanvasLayout.swift       # safe zone, snap, bounds
│   │   └── CardTextEffectsRenderer.swift # 3D presets, shadows
│   ├── Editor/
│   │   ├── CardProCanvasView.swift      # fullscreen editor shell
│   │   ├── CardSelectionHandles.swift
│   │   ├── CardFloatingToolbar.swift    # contextual top/bottom bar
│   │   ├── CardLayerPanel.swift         # z-order, lock, hide, duplicate
│   │   ├── CardAddLayerSheet.swift
│   │   ├── CardBackgroundEditor.swift
│   │   ├── CardTextInlineEditor.swift   # double-tap overlay
│   │   └── CardUndoManager.swift
│   └── Tools/
│       ├── CardImageAdjustmentsPanel.swift  # wraps Photo Lab
│       ├── CardShapePicker.swift
│       ├── CardColorPicker.swift
│       ├── CardFontPicker.swift
│       └── Card3DTextPresets.swift
```

**Invoice reuse (future):** `Canvas/Models` and `Canvas/Editor` shell abstract to `StudioCanvas*` when invoices adopt the same engine. Card-specific types stay prefixed `Card*`.

---

## 4. Document model

### 4.1 Root: `CardCanvasDocument`

```swift
struct CardCanvasDocument: Codable, Equatable, Sendable {
    var version: Int                          // schema version for migration
    var canvasSize: CGSize                  // logical size (from aspect)
    var safeInsetRatio: CGFloat
    var background: CardBackgroundLayer
    var layers: [CardCanvasLayer]           // bottom → top render order
    var templateID: String?                 // seed reference for "reset layout"
}
```

Stored inside `ProBusinessCardDesign`:

```swift
// ProBusinessCardDesign gains:
var canvasDocument: CardCanvasDocument?
var editorPreferences: CardEditorPreferences?  // last zoom, grid on/off
```

When `canvasDocument == nil` on load → run `CardCanvasMigrator.migrate(design)` once, set `canvasDocument`, persist.

### 4.2 Layer: `CardCanvasLayer`

Every visual element is one layer:

```swift
struct CardCanvasLayer: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var kind: CardLayerKind
    var transform: CardLayerTransform      // normalized frame in canvas
    var isLocked: Bool
    var isHidden: Bool
    var opacity: Double
    var effects: CardLayerEffects          // shadow, blend mode
    var payload: CardLayerPayload          // type-specific data
}
```

### 4.3 Layer kinds

| Kind | Purpose | Payload highlights |
|------|---------|-------------------|
| `text` | Any text block | content, fontID, size, color, gradient, align, lineLimit, **contentBinding** (optional link to `content.name`, etc.) |
| `image` | Photo, logo, imported graphic | assetPath or logoRef, crop, mask, adjustments, filter |
| `qr` | Scannable vCard | auto from contact fields, fg/bg colors, optional center logo |
| `shape` | Design elements | shapeType, fill, stroke, cornerRadius |
| `group` | Future: multi-select container | child layer IDs |
| `watermark` | Large background text | text, style, repeat |

**Default template seeds** produce 8–15 layers (background shapes, logo image, name text, tagline, contact group, QR, accent bar, optional watermark).

### 4.4 Transform

Normalized to canvas (0…1), anchor center:

```swift
struct CardLayerTransform: Codable, Equatable, Sendable {
    var centerX, centerY: Double
    var width, height: Double              // relative to canvas width/height
    var rotation: Double                   // degrees
    var scale: Double                      // uniform; pinch updates this
}
```

Pinch/expand handles adjust `width`, `height`, and/or `scale` depending on layer kind (text: font size + box; image: frame; shape: frame).

### 4.5 Text style (full freedom)

```swift
struct CardTextStyle: Codable, Equatable, Sendable {
    var fontID: String
    var fontSize: Double
    var fontWeight: String                 // encoded weight
    var foregroundColorHex: String
    var gradient: CardGradientFill?        // optional override solid
    var alignment: CardTextAlignment
    var lineSpacing: Double
    var letterSpacing: Double
    var isItalic: Bool
    var isUnderline: Bool
    var textEffect: CardTextEffectPreset   // none | longShadow | emboss | outline | neon | letterpress | retro3D
    var outline: CardTextOutline?          // stroke color + width
    var backgroundFill: CardFill?          // highlight pill behind text
}
```

**3D / art text:** implemented as **presets** (stacked shadows, gradient fills, inner stroke) — not real-time 3D meshes. Export-identical in PDF/PNG. Preset catalog: 12 launch styles.

### 4.6 Image style

Reuses existing `ProBusinessCardPhotoAdjustments` fields + extensions:

- brightness, contrast, saturation, sharpness, warmth, vignette
- filterName (from Photo Lab presets)
- cornerRadius, mask (circle, roundedRect, none)
- border (color, width)
- flip horizontal/vertical

### 4.7 Shape style

| Shape | Controls |
|-------|----------|
| rectangle | fill, stroke, corner radius |
| circle / ellipse | fill, stroke |
| line | stroke color, width, dash |
| triangle, star, badge, accentBar | fill, stroke |
| custom SF Symbol | symbol name, scale, color |

Shapes support gradient fills and opacity. Template accent stripes (Classic, Neon Edge) become shape layers users can move/resize/delete.

### 4.8 Background layer

Separate from `layers[]` — always bottom:

- solid / linear gradient / radial gradient
- pattern (dots, lines, grid)
- photo (path + opacity + blur + overlay tint)
- adjustments (saturation, brightness on photo bg)

---

## 5. Pro Canvas UX (fullscreen)

### 5.1 Layout

```
┌──────────────────────────────────────────────┐
│ Cancel    Card Title              Done ✓     │
├──────────────────────────────────────────────┤
│  [Floating toolbar — contextual, scrollable] │
├──────────────────────────────────────────────┤
│                                              │
│              CARD CANVAS                     │
│         (pinch zoom canvas optional)         │
│    selected layer: handles + rotation        │
│                                              │
├──────────────────────────────────────────────┤
│  [Bottom rail: Add · Layers · BG · FX · ··]  │
└──────────────────────────────────────────────┘
```

### 5.2 Floating toolbar by selection

**Text selected:** Font · Size · Color · Align · **Style FX** · Shadow · Opacity · Duplicate · Delete

**Style FX sheet:** 3D presets grid, outline, background highlight

**Image selected:** Crop · Mask · Adjust · Filters · Flip · Border · Shadow · Opacity

**Shape selected:** Fill · Stroke · Radius · Opacity · Duplicate

**QR selected:** Size · Colors · Corner radius · Refresh from contact

**Background (no selection / tap bg):** Type picker · Colors · Photo · Blur · Overlay

**Canvas (empty tap):** Add text · Add image · Add shape · Template · Aspect · Safe zone toggle

### 5.3 Bottom rail (deep tools)

| Tab | Contents |
|-----|----------|
| **Add** | Text box, Image (camera/library), Shape catalog, QR toggle, Logo from profile |
| **Layers** | Reorder (drag), lock, hide, duplicate, delete, rename |
| **Background** | Full background editor |
| **Adjust** | Image/background adjustments (Photo Lab UI embedded) |
| **Export** | PDF, PNG, Share vCard (same as Quick Studio) |

### 5.4 Gestures

| Gesture | Action |
|---------|--------|
| Tap layer | Select |
| Double-tap text | Inline edit |
| Drag layer | Move (snap to guides if enabled) |
| Pinch on handles | Scale |
| Rotate handle | Rotate |
| Two-finger canvas pinch | Zoom canvas view (not layer) |
| Long-press layer | Context menu: duplicate, lock, delete, bring front/back |

### 5.5 Undo / redo

`CardUndoManager` — stack of `CardCanvasDocument` snapshots (max 50). Coalesced drag operations. Persist not required across sessions for v1.

---

## 6. Quick Studio integration (keep fast mode)

Quick Studio tabs remain:

- **Design** — template, identity, fonts, colors (changes sync to bound canvas layers)
- **Photo** — visibility toggles, placement (updates image layer transform), Photo Lab entry
- **Text** — form fields; bound text layers update content live
- **Export** — unchanged

**Sync rules:**

| Quick Studio change | Canvas effect |
|--------------------|---------------|
| Edit name in Text tab | Updates layer with `contentBinding: .name` |
| Toggle QR | Insert/remove QR layer |
| Change template | Offer "Apply layout" (re-seed) or "Keep custom layout" |
| Identity mode | Re-seed photo/logo layout if user confirms |
| Font gallery | Updates global typography + all unstyled text layers |

**Open Pro Canvas:** preview area tap → `CardProCanvasView` fullscreen cover. Buttons: Fullscreen (immersive view only) vs **Edit** (Pro Canvas) — merge into single **Edit card** that opens Pro Canvas.

---

## 7. Templates as seed documents

Each `ProBusinessCardTemplate` maps to a `CardCanvasDocument` factory:

- `CardTemplateSeeder.seed(template:aspect:content:options:logoData:) -> CardCanvasDocument`
- 15 templates × 3 aspects = 45 seed layouts (precomputed ratios, not 45 stored files — generated from rules)

Switching template in Quick Studio:

1. If canvas has user edits (`canvasDocument.isCustomized`) → alert: **Replace layout** / **Keep current**
2. Replace runs seeder, preserves content-bound text and contact data

---

## 8. Rendering & export

- **Screen:** `CardCanvasRenderer` — pure SwiftUI, layer-ordered ZStack
- **Export:** same renderer via `ImageRenderer` at 3× for PNG, print size for PDF (existing `ProBusinessCardExport` delegates to canvas renderer when `canvasDocument != nil`)
- **Text effects:** `CardTextEffectsRenderer` applies presets as modifier stack; must match export pixel-perfect
- **Performance target:** 60fps on iPhone 12+ with ≤20 layers; throttle live adjustments during slider drag

---

## 9. Migration

`CardCanvasMigrator.migrate(from design: ProBusinessCardDesign) -> CardCanvasDocument`:

1. Read aspect → canvas size
2. Run existing `ProBusinessCardLayoutEngine` + template rules to compute frames
3. Emit layers: background, logo, photo, name, tagline, contact lines, QR, watermark, template accent shapes
4. Map existing `photoCanvas`, `logoCanvas`, `nameCanvas`, `qrCanvas`, watermark positions into transforms
5. Set `contentBinding` on text layers linked to `ProBusinessCardContent` fields
6. Mark `version = 1`

Legacy `ProBusinessCardRenderer` retained until all tests pass on migrated output parity (visual snapshot tests optional).

---

## 10. Feature matrix (shipping scope)

### Must ship (v1 Pro Canvas)

- [ ] Full layer document model + persistence
- [ ] Migration from all existing saved designs
- [ ] Pro Canvas fullscreen editor (replaces `BusinessCardFullscreenCanvasView`)
- [ ] Tap select, double-tap text edit, drag, pinch scale, rotate
- [ ] Floating contextual toolbar (text, image, shape, QR, background)
- [ ] Layer panel (reorder, lock, hide, duplicate, delete)
- [ ] All layer types: text, image, QR, shape, watermark
- [ ] Background editor (solid, gradient, pattern, photo + opacity)
- [ ] Text: font picker (16 fonts), size, color, align, opacity, shadow, 12 effect presets, outline
- [ ] Image: crop, mask, full Photo Lab adjustments + filters
- [ ] Shapes: rectangle, circle, line, star, badge, accent bar, SF Symbol
- [ ] QR auto-generate + recolor + resize
- [ ] Snap guides + safe zone overlay
- [ ] Undo / redo
- [ ] Quick Studio ↔ Canvas sync (content bindings)
- [ ] Export PDF / PNG / vCard unchanged quality
- [ ] 15 templates seed correctly on all 4 aspects
- [ ] Unit tests: migration, model encoding, layer hit test, export size
- [ ] No regression on Pro gate, gallery, store CRUD

### Should ship (v1 if time; else v1.1)

- [ ] Canvas zoom (two-finger on workspace)
- [ ] Copy / paste style between layers
- [ ] Multi-select (shift-tap) + group move
- [ ] Text gradient fill
- [ ] Background blur + saturation on photo bg
- [ ] Grid overlay toggle

### Explicitly not v1 (honest scope cut)

- True 3D mesh text / SceneKit objects
- Custom vector pen / bezier drawing
- AI background generation
- Front/back two-sided card
- Real-time collaboration
- Custom font upload (system + bundled 16 only)

---

## 11. Implementation phases (build order)

Single release target; phases are **sequencing for development**, not optional drops.

| Phase | Deliverable | Est. |
|-------|-------------|------|
| **P1 — Model & migration** | `CardCanvasDocument`, layer payloads, migrator, encode/decode, tests | 2–3 days |
| **P2 — Renderer** | `CardCanvasRenderer` parity with current cards for all 15 templates | 2–3 days |
| **P3 — Editor shell** | Fullscreen view, selection handles, hit testing, gestures | 2–3 days |
| **P4 — Text system** | Inline edit, floating toolbar, fonts, colors, shadows, 3D presets | 2–3 days |
| **P5 — Image system** | Image layers, crop, mask, Photo Lab embed | 1–2 days |
| **P6 — Shapes & background** | Shape catalog, background editor, template accents as shapes | 1–2 days |
| **P7 — Layers panel & undo** | Z-order, duplicate, lock, undo stack | 1–2 days |
| **P8 — Quick Studio sync** | Bindings, template replace alert, editor entry points | 1–2 days |
| **P9 — Export & polish** | PDF/PNG via canvas, performance, edge cases, QA checklist | 2–3 days |

**Total:** ~15–22 dev days for shipping-grade v1.

---

## 12. Testing & shipping criteria

### Automated

- Migration tests: starter designs, imported simple cards, designs with canvas overrides
- Round-trip Codable for `ProBusinessCardDesign` with `canvasDocument`
- Export dimensions match `ProBusinessCardAspect.printSize`
- QR payload encodes vCard correctly
- Layer hit test returns topmost visible unlocked layer

### Manual QA

- [ ] Fresh install → create card → Pro Canvas → add text/shape/image → export PDF → print preview
- [ ] Migrate existing saved design → layers match previous visual
- [ ] Quick Studio text change → bound layer updates in Pro Canvas
- [ ] Double-tap text → edit → Done → export matches
- [ ] All 15 templates apply on landscape, portrait, square
- [ ] Identity modes re-seed correctly with confirmation
- [ ] Offline: no network required for full edit + export
- [ ] Memory: no leak after 20 undo steps + Photo Lab on 12MP photo

### Performance gates

- Canvas open < 300ms
- Slider adjustments ≥ 30fps
- Export < 2s on device

---

## 13. Invoice handoff (after card v1 ships)

Extract when card canvas is stable:

1. Rename/shared-ify `CardLayerTransform` → `StudioLayerTransform`
2. Invoice document: `InvoiceCanvasDocument` with layers: header, client block, line items table, totals, footer, payment QR
3. Reuse: `FloatingToolbar`, `SelectionHandles`, `UndoManager`, `ColorPicker`, `Export pipeline`
4. Invoice-specific: computed line item layer (data-bound, not free text)

**No invoice work starts until card v1 QA checklist is green.**

---

## 14. Success definition

The user can:

1. Open a saved card in **Quick Studio**, fill contact info in 30 seconds
2. Tap **Edit card** → Pro Canvas fullscreen
3. Tap name → change font, color, apply “Neon 3D” preset, drag anywhere
4. Add accent shape, logo, photo with filters, QR that scans correctly
5. Undo mistakes, reorder layers, lock background
6. Export PDF at correct print size
7. Reopen later — everything persisted, no layout corruption

**That is shipping-grade v1.** Anything less is not done.

---

## 15. Approval

- **Interaction model:** C (tap select / double-tap edit text) — **approved**
- **Architecture:** Layer document + migrator, Quick Studio preserved — **approved**
- **Scope:** Full feature matrix §10 “Must ship” — **approved for implementation**

Next step after spec approval: implementation plan (`writing-plans` skill) → build P1–P9.
