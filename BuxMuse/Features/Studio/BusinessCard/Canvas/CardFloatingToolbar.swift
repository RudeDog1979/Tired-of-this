//
//  CardFloatingToolbar.swift
//  BuxMuse — Bux Canvas contextual tools (BuxMuse proprietary)
//

import SwiftUI

struct CardFloatingToolbar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let layer: CardCanvasLayer?
    var backgroundSelected: Bool
    @Binding var document: CardCanvasDocument
    var actions: BuxCanvasToolbarActionSet
    var onChange: () -> Void

    private var controlTint: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private func glassMenu<Content: View, Label: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Menu(content: content, label: label)
            .menuStyle(.button)
            .buxNativeButtonStyle(.secondary)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            centeredToolbarRow
            scrollableToolbarRow
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
    }

    private var toolbarContent: some View {
        Group {
            if backgroundSelected {
                backgroundTools
            } else if let layer {
                layerTools(layer)
                toolButton("Duplicate", icon: "plus.square.on.square") {
                    if let newID = document.duplicateLayer(id: layer.id) {
                        document.markCustomized()
                        actions.onLayerDuplicated?(newID)
                        onChange()
                    }
                }
                if !layer.isLocked {
                    toolButton("Delete", icon: "trash", destructive: true) {
                        document.removeLayer(id: layer.id)
                        document.markCustomized()
                        actions.onLayerDeleted?()
                        onChange()
                    }
                }
            } else {
                toolButton("Add text", icon: "textformat") { addText() }
                shapeInsertMenu
                toolButton("Background", icon: "photo.fill.on.rectangle.fill") {
                    actions.onOpenBackgroundEditor?()
                }
            }
        }
    }

    private var glassToolbarRow: some View {
        HStack(spacing: 8) {
            toolbarContent
        }
        .buxNativeGlassButtonRowContainer(spacing: 8)
        .foregroundStyle(controlTint)
    }

    private var centeredToolbarRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            glassToolbarRow
            Spacer(minLength: 0)
        }
    }

    private var scrollableToolbarRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            glassToolbarRow
                .padding(.horizontal, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private var backgroundTools: some View {
        Group {
            glassMenu {
                ForEach(ProBusinessCardBackgroundStyle.allCases) { style in
                    Button(style.title) {
                        document.background.style = style
                        document.markCustomized()
                        onChange()
                    }
                }
            } label: { toolLabel("Style", icon: "square.grid.2x2") }

            colorMenu(current: document.background.solidHex) { hex in
                document.background.solidHex = hex
                document.markCustomized()
                onChange()
            }

            if document.background.style == .photo {
                toolButton("Bux Focal", icon: "arrow.up.left.and.arrow.down.right") {
                    actions.onOpenFocalEditor?(.background)
                }
            }

            toolButton("Bux Adjust", icon: "slider.horizontal.3") {
                actions.onOpenBackgroundEditor?()
            }
        }
    }

    @ViewBuilder
    private func layerTools(_ layer: CardCanvasLayer) -> some View {
        if !layer.isLocked {
            layerOrderMenu(layer)
            rotateMenu(layer)
        }
        switch layer.payload {
        case .text(let payload):
            fontMenu(payload: payload, layerID: layer.id)
            colorMenu(current: payload.style.colorHex) { hex in
                var p = payload
                p.style.colorHex = hex
                updatePayload(layer.id, .text(p))
            }
            alignMenu(payload: payload, layerID: layer.id)
            effectMenu(payload: payload, layerID: layer.id)
            opacityMenu(layer: layer)
            sizeButtons(layerID: layer.id, increase: {
                mutateTextSize(layerID: layer.id, delta: 1)
            }, decrease: {
                mutateTextSize(layerID: layer.id, delta: -1)
            })

        case .image(let payload):
            glassMenu {
                Button("Bux Photo Lab") { actions.onOpenPhotoLab?(layer.id) }
                Button("Bux Focal Crop") { actions.onOpenFocalEditor?(.imageLayer(layer.id)) }
                Divider()
                ForEach(CardImageMask.allCases, id: \.self) { mask in
                    Button(mask.title) {
                        var p = payload
                        p.mask = mask
                        updatePayload(layer.id, .image(p))
                    }
                }
                Divider()
                Button("Flip horizontal") {
                    var p = payload
                    p.flipHorizontal.toggle()
                    updatePayload(layer.id, .image(p))
                }
                Button("Flip vertical") {
                    var p = payload
                    p.flipVertical.toggle()
                    updatePayload(layer.id, .image(p))
                }
            } label: { toolLabel("Bux Photo", icon: "camera.filters") }
            opacityMenu(layer: layer)

        case .shape(let payload):
            glassMenu {
                Menu("Geometric") {
                    ForEach(CardShapeType.geometricShapes) { shape in
                        Button(shape.title) {
                            var p = payload
                            p.shapeType = shape
                            updatePayload(layer.id, .shape(p))
                        }
                    }
                }
                Menu("Basic") {
                    ForEach(CardShapeType.basicShapes) { shape in
                        Button(shape.title) {
                            var p = payload
                            p.shapeType = shape
                            updatePayload(layer.id, .shape(p))
                        }
                    }
                }
                Divider()
                Toggle("Gradient fill", isOn: Binding(
                    get: { payload.useGradient },
                    set: { v in
                        var p = payload
                        p.useGradient = v
                        updatePayload(layer.id, .shape(p))
                    }
                ))
            } label: { toolLabel("Bux Shape", icon: "triangle.fill") }
            colorMenu(current: payload.fillHex) { hex in
                var p = payload
                p.fillHex = hex
                updatePayload(layer.id, .shape(p))
            }
            opacityMenu(layer: layer)

        case .qr:
            toolButton("Refresh QR", icon: "arrow.clockwise") { onChange() }
            opacityMenu(layer: layer)

        case .watermark(let payload):
            colorMenu(current: payload.colorHex) { hex in
                var p = payload
                p.colorHex = hex
                updatePayload(layer.id, .watermark(p))
            }
            opacityMenu(layer: layer)
        }
    }

    private func rotateMenu(_ layer: CardCanvasLayer) -> some View {
        glassMenu {
            ForEach([-90, -45, -15, 15, 45, 90], id: \.self) { delta in
                Button("\(delta > 0 ? "+" : "")\(delta)°") { nudgeRotation(layerID: layer.id, by: Double(delta)) }
            }
            Divider()
            Button("Reset") { setRotation(layerID: layer.id, degrees: 0) }
        } label: { toolLabel("Rotate", icon: "rotate.right") }
    }

    private func layerOrderMenu(_ layer: CardCanvasLayer) -> some View {
        glassMenu {
            Button("Bring to front") { document.bringToFront(id: layer.id); document.markCustomized(); onChange() }
            Button("Forward") { document.bringForward(id: layer.id); document.markCustomized(); onChange() }
            Button("Backward") { document.sendBackward(id: layer.id); document.markCustomized(); onChange() }
            Button("Send to back") { document.sendToBack(id: layer.id); document.markCustomized(); onChange() }
        } label: { toolLabel("Order", icon: "square.3.layers.3d.down.forward") }
    }

    private func nudgeRotation(layerID: UUID, by delta: Double) {
        guard var l = document.layer(id: layerID) else { return }
        l.transform.rotation += delta
        document.updateLayer(l)
        document.markCustomized()
        onChange()
    }

    private func setRotation(layerID: UUID, degrees: Double) {
        guard var l = document.layer(id: layerID) else { return }
        l.transform.rotation = degrees
        document.updateLayer(l)
        document.markCustomized()
        onChange()
    }

    private func fontMenu(payload: CardTextPayload, layerID: UUID) -> some View {
        glassMenu {
            ForEach(ProBusinessCardFontID.allCases) { font in
                Button(font.title) {
                    var p = payload
                    p.style.fontID = font.rawValue
                    updatePayload(layerID, .text(p))
                }
            }
        } label: { toolLabel("Font", icon: "textformat") }
    }

    private func alignMenu(payload: CardTextPayload, layerID: UUID) -> some View {
        glassMenu {
            Button("Left") { updateTextAlign(layerID: layerID, payload: payload, align: "leading") }
            Button("Center") { updateTextAlign(layerID: layerID, payload: payload, align: "center") }
        } label: { toolLabel("Align", icon: "text.alignleft") }
    }

    private func effectMenu(payload: CardTextPayload, layerID: UUID) -> some View {
        glassMenu {
            ForEach(CardTextEffectPreset.allCases) { preset in
                Button(preset.title) {
                    var p = payload
                    p.style.effectPreset = preset
                    updatePayload(layerID, .text(p))
                }
            }
        } label: { toolLabel("Bux FX", icon: "sparkles") }
    }

    private func opacityMenu(layer: CardCanvasLayer) -> some View {
        glassMenu {
            ForEach([1.0, 0.85, 0.7, 0.5, 0.35, 0.2], id: \.self) { value in
                Button("\(Int(value * 100))%") {
                    guard var l = document.layer(id: layer.id) else { return }
                    l.opacity = value
                    document.updateLayer(l)
                    document.markCustomized()
                    onChange()
                }
            }
        } label: { toolLabel("Opacity", icon: "circle.lefthalf.filled") }
    }

    private func colorMenu(current: String, onPick: @escaping (String) -> Void) -> some View {
        glassMenu {
            ForEach(BuxCanvasColorPresets.all, id: \.self) { color in
                Button(color) { onPick(color) }
            }
        } label: { toolLabel("Color", icon: "paintpalette.fill") }
    }

    private func sizeButtons(layerID: UUID, increase: @escaping () -> Void, decrease: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Button(action: decrease) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
            }
            .buxNativeButtonStyle(.secondary)
            Button(action: increase) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
            }
            .buxNativeButtonStyle(.secondary)
        }
        .foregroundStyle(controlTint)
    }

    private func toolButton(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolLabel(title, icon: icon, destructive: destructive) }
            .buxNativeButtonStyle(.secondary)
    }

    private func toolLabel(_ title: String, icon: String, destructive: Bool = false) -> some View {
        Label {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        } icon: {
            Image(systemName: icon)
        }
        .font(.system(size: 11, weight: .bold))
        .labelStyle(.titleAndIcon)
        .foregroundStyle(destructive ? Color.red : controlTint)
    }

    private func updatePayload(_ id: UUID, _ payload: CardLayerPayload) {
        guard var layer = document.layer(id: id) else { return }
        layer.payload = payload
        document.updateLayer(layer)
        document.markCustomized()
        onChange()
    }

    private func updateTextAlign(layerID: UUID, payload: CardTextPayload, align: String) {
        var p = payload
        p.style.alignment = align
        updatePayload(layerID, .text(p))
    }

    private func mutateTextSize(layerID: UUID, delta: Double) {
        guard var l = document.layer(id: layerID), case .text(var p) = l.payload else { return }
        p.style.fontSize = max(6, p.style.fontSize + delta)
        l.payload = .text(p)
        document.updateLayer(l)
        document.markCustomized()
        onChange()
    }

    private func addText() {
        document.layers.append(CardCanvasLayer(
            name: "Text",
            kind: .text,
            transform: CardLayerTransform(centerX: 0.5, centerY: 0.5, width: 0.6, height: 0.1),
            payload: .text(CardTextPayload(text: "New text", style: CardTextStyle()))
        ))
        document.markCustomized()
        onChange()
    }

    private var shapeInsertMenu: some View {
        glassMenu {
            ForEach(CardShapeType.geometricShapes + CardShapeType.basicShapes) { shape in
                Button(shape.title) { addShape(type: shape) }
            }
        } label: { toolLabel("Bux Shapes", icon: "triangle.fill") }
    }

    private func addShape(type: CardShapeType = .rectangle) {
        document.layers.append(CardCanvasLayer(
            name: type.title,
            kind: .shape,
            transform: CardLayerTransform(centerX: 0.5, centerY: 0.5, width: 0.25, height: 0.12),
            payload: .shape(CardShapePayload(shapeType: type, fillHex: "#5A55F5"))
        ))
        document.markCustomized()
        onChange()
    }
}

enum BuxCanvasColorPresets {
    static let all = ["#111827", "#FFFFFF", "#5A55F5", "#00C882", "#FF3366", "#D4AF37", "#0F172A", "#F8FAFC"]
}

extension CardImageMask {
    var title: String {
        switch self {
        case .none: return "Square"
        case .circle: return "Circle"
        case .roundedRect: return "Rounded"
        }
    }
}

// Legacy alias
typealias CardCanvasColorPresets = BuxCanvasColorPresets
