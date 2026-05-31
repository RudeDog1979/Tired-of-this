//
//  BusinessCardFullscreenCanvasView.swift
//  BuxMuse
//
//  Full-screen layer canvas — drag, pinch, rotate. Positions persist.
//

import SwiftUI

struct BusinessCardFullscreenCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var design: ProBusinessCardDesign
    let logoData: Data?
    let onSave: () -> Void

    @State private var selectedLayer: ProBusinessCardCanvasLayerKind = .name
    @State private var showSafeZone = true
    @State private var snapGuides = true

    @State private var dragOriginPhoto: ProBusinessCardCanvasLayer?
    @State private var dragOriginLogo: ProBusinessCardCanvasLayer?
    @State private var dragOriginName: ProBusinessCardCanvasLayer?
    @State private var dragOriginQR: ProBusinessCardCanvasLayer?
    @State private var dragOriginWatermark: ProBusinessCardWatermark?
    @State private var pinchOriginScale: Double = 1
    @State private var rotateOrigin: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                canvasWorkspace
                bottomBar
            }
        }
        .onAppear {
            ProBusinessCardCanvasSeeder.ensureLayers(on: &design)
            if let first = ProBusinessCardCanvasLayerKind.allCases.first(where: { $0.isActive(in: design) }) {
                selectedLayer = first
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
            Spacer()
            Text("Move layers")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button("Done") { onSave(); dismiss() }
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.35))
    }

    private var canvasWorkspace: some View {
        GeometryReader { geo in
            let cardSize = design.aspect.previewSize
            let fit = min((geo.size.width - 40) / cardSize.width, (geo.size.height - 40) / cardSize.height, 1.35)
            let fittedW = cardSize.width * fit
            let fittedH = cardSize.height * fit

            ZStack {
                if snapGuides {
                    snapGuideOverlay(width: fittedW, height: fittedH)
                }

                ZStack {
                    ProBusinessCardRenderer(
                        context: renderContext,
                        showSafeZone: showSafeZone,
                        selectedLayer: selectedLayer
                    )

                    layerHandles(cardSize: cardSize)
                }
                .frame(width: cardSize.width, height: cardSize.height)
                .scaleEffect(fit)
                .frame(width: fittedW, height: fittedH)
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func layerHandles(cardSize: CGSize) -> some View {
        let backLayers = ProBusinessCardCanvasLayerKind.allCases.filter { $0 != selectedLayer && $0.isActive(in: design) }
        ForEach(backLayers) { layer in
            if let spec = handleSpec(for: layer, cardSize: cardSize) {
                manipulableHandle(layer: layer, spec: spec, cardSize: cardSize, isSelected: false)
            }
        }
        if selectedLayer.isActive(in: design), let spec = handleSpec(for: selectedLayer, cardSize: cardSize) {
            manipulableHandle(layer: selectedLayer, spec: spec, cardSize: cardSize, isSelected: true)
                .zIndex(100)
        }
    }

    private struct LayerHandleSpec {
        let center: CGPoint
        let size: CGSize
        let isCircle: Bool
    }

    private func handleSpec(for layer: ProBusinessCardCanvasLayerKind, cardSize: CGSize) -> LayerHandleSpec? {
        switch layer {
        case .photo:
            guard let canvas = design.style.photoCanvas else { return nil }
            let d = cardSize.height * design.style.photoScale.pointRatio * canvas.scale
            return LayerHandleSpec(
                center: canvasPoint(canvas, cardSize: cardSize),
                size: CGSize(width: d, height: d),
                isCircle: !design.style.photoPlacement.isStrip
            )
        case .logo:
            guard let canvas = design.style.logoCanvas else { return nil }
            let s = min(cardSize.width, cardSize.height) * design.style.logoScale.pointRatio * canvas.scale
            return LayerHandleSpec(
                center: canvasPoint(canvas, cardSize: cardSize),
                size: CGSize(width: s, height: s),
                isCircle: false
            )
        case .name:
            guard let canvas = design.style.nameCanvas else { return nil }
            let w = cardSize.width * 0.72 * canvas.scale
            let h = max(28, cardSize.height * 0.11) * canvas.scale
            return LayerHandleSpec(
                center: canvasPoint(canvas, cardSize: cardSize),
                size: CGSize(width: w, height: h),
                isCircle: false
            )
        case .qr:
            guard let canvas = design.style.qrCanvas else { return nil }
            let s = min(56, cardSize.height * 0.22) * canvas.scale
            return LayerHandleSpec(
                center: canvasPoint(canvas, cardSize: cardSize),
                size: CGSize(width: s, height: s),
                isCircle: false
            )
        case .watermark:
            return LayerHandleSpec(
                center: CGPoint(
                    x: design.style.watermark.normalizedX * cardSize.width,
                    y: design.style.watermark.normalizedY * cardSize.height
                ),
                size: CGSize(width: cardSize.width * 0.55, height: cardSize.height * 0.22),
                isCircle: false
            )
        }
    }

    private func manipulableHandle(
        layer: ProBusinessCardCanvasLayerKind,
        spec: LayerHandleSpec,
        cardSize: CGSize,
        isSelected: Bool
    ) -> some View {
        let radius = spec.isCircle ? spec.size.width / 2 : 8.0
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        isSelected ? themeManager.current.accentColor : Color.white.opacity(0.35),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .frame(width: spec.size.width, height: spec.size.height)
            .position(spec.center)
            .gesture(isSelected ? combinedGesture(for: layer, cardSize: cardSize) : nil)
            .onTapGesture { selectLayer(layer) }
    }

    private func selectLayer(_ layer: ProBusinessCardCanvasLayerKind) {
        ProBusinessCardCanvasLayerKind.enable(layer, in: &design)
        ProBusinessCardCanvasSeeder.ensureLayer(layer, on: &design)
        selectedLayer = layer
    }

    private func combinedGesture(for layer: ProBusinessCardCanvasLayerKind, cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in handleDrag(layer: layer, translation: value.translation, cardSize: cardSize) }
            .onEnded { _ in resetGestureOrigins() }
            .simultaneously(with:
                MagnificationGesture()
                    .onChanged { m in handlePinch(layer: layer, magnification: m) }
                    .onEnded { _ in resetPinchOrigin(layer: layer) }
            )
            .simultaneously(with:
                RotationGesture()
                    .onChanged { r in handleRotate(layer: layer, radians: r.radians) }
                    .onEnded { _ in resetRotateOrigin(layer: layer) }
            )
    }

    private func handleDrag(layer: ProBusinessCardCanvasLayerKind, translation: CGSize, cardSize: CGSize) {
        switch layer {
        case .photo:
            if dragOriginPhoto == nil { dragOriginPhoto = design.style.photoCanvas }
            guard let o = dragOriginPhoto else { return }
            design.style.photoCanvas = movedCanvas(from: o, translation: translation, cardSize: cardSize)
        case .logo:
            if dragOriginLogo == nil { dragOriginLogo = design.style.logoCanvas }
            guard let o = dragOriginLogo else { return }
            design.style.logoCanvas = movedCanvas(from: o, translation: translation, cardSize: cardSize)
        case .name:
            if dragOriginName == nil { dragOriginName = design.style.nameCanvas }
            guard let o = dragOriginName else { return }
            design.style.nameCanvas = movedCanvas(from: o, translation: translation, cardSize: cardSize)
        case .qr:
            if dragOriginQR == nil { dragOriginQR = design.style.qrCanvas }
            guard let o = dragOriginQR else { return }
            design.style.qrCanvas = movedCanvas(from: o, translation: translation, cardSize: cardSize)
        case .watermark:
            if dragOriginWatermark == nil { dragOriginWatermark = design.style.watermark }
            guard let o = dragOriginWatermark else { return }
            design.style.watermark.normalizedX = clamp01(o.normalizedX + Double(translation.width / cardSize.width))
            design.style.watermark.normalizedY = clamp01(o.normalizedY + Double(translation.height / cardSize.height))
        }
    }

    private func movedCanvas(from origin: ProBusinessCardCanvasLayer, translation: CGSize, cardSize: CGSize) -> ProBusinessCardCanvasLayer {
        ProBusinessCardCanvasLayer(
            normalizedX: clamp01(origin.normalizedX + Double(translation.width / cardSize.width)),
            normalizedY: clamp01(origin.normalizedY + Double(translation.height / cardSize.height)),
            scale: origin.scale,
            rotation: origin.rotation
        )
    }

    private func handlePinch(layer: ProBusinessCardCanvasLayerKind, magnification: CGFloat) {
        switch layer {
        case .photo:
            if pinchOriginScale == 1, let s = design.style.photoCanvas?.scale { pinchOriginScale = s }
            updateCanvasLayer(.photo, scale: min(2.8, max(0.35, pinchOriginScale * Double(magnification))))
        case .logo:
            if pinchOriginScale == 1, let s = design.style.logoCanvas?.scale { pinchOriginScale = s }
            updateCanvasLayer(.logo, scale: min(2.8, max(0.35, pinchOriginScale * Double(magnification))))
        case .name:
            if pinchOriginScale == 1, let s = design.style.nameCanvas?.scale { pinchOriginScale = s }
            updateCanvasLayer(.name, scale: min(2.8, max(0.35, pinchOriginScale * Double(magnification))))
        case .qr:
            if pinchOriginScale == 1, let s = design.style.qrCanvas?.scale { pinchOriginScale = s }
            updateCanvasLayer(.qr, scale: min(2.8, max(0.35, pinchOriginScale * Double(magnification))))
        case .watermark:
            if pinchOriginScale == 1 { pinchOriginScale = design.style.watermark.scale }
            design.style.watermark.scale = min(2.8, max(0.35, pinchOriginScale * Double(magnification)))
        }
    }

    private func handleRotate(layer: ProBusinessCardCanvasLayerKind, radians: Double) {
        let degrees = radians * 180 / .pi
        switch layer {
        case .photo:
            if rotateOrigin == 0 { rotateOrigin = design.style.photoCanvas?.rotation ?? 0 }
            updateCanvasLayer(.photo, rotation: rotateOrigin + degrees)
        case .logo:
            if rotateOrigin == 0 { rotateOrigin = design.style.logoCanvas?.rotation ?? 0 }
            updateCanvasLayer(.logo, rotation: rotateOrigin + degrees)
        case .name:
            if rotateOrigin == 0 { rotateOrigin = design.style.nameCanvas?.rotation ?? 0 }
            updateCanvasLayer(.name, rotation: rotateOrigin + degrees)
        case .qr:
            if rotateOrigin == 0 { rotateOrigin = design.style.qrCanvas?.rotation ?? 0 }
            updateCanvasLayer(.qr, rotation: rotateOrigin + degrees)
        case .watermark:
            if rotateOrigin == 0 { rotateOrigin = design.style.watermark.rotation }
            design.style.watermark.rotation = rotateOrigin + degrees
        }
    }

    private func updateCanvasLayer(_ kind: ProBusinessCardCanvasLayerKind, scale: Double? = nil, rotation: Double? = nil) {
        switch kind {
        case .photo:
            guard var c = design.style.photoCanvas else { return }
            if let scale { c.scale = scale }
            if let rotation { c.rotation = rotation }
            design.style.photoCanvas = c
        case .logo:
            guard var c = design.style.logoCanvas else { return }
            if let scale { c.scale = scale }
            if let rotation { c.rotation = rotation }
            design.style.logoCanvas = c
        case .name:
            guard var c = design.style.nameCanvas else { return }
            if let scale { c.scale = scale }
            if let rotation { c.rotation = rotation }
            design.style.nameCanvas = c
        case .qr:
            guard var c = design.style.qrCanvas else { return }
            if let scale { c.scale = scale }
            if let rotation { c.rotation = rotation }
            design.style.qrCanvas = c
        case .watermark:
            break
        }
    }

    private func resetGestureOrigins() {
        dragOriginPhoto = nil
        dragOriginLogo = nil
        dragOriginName = nil
        dragOriginQR = nil
        dragOriginWatermark = nil
    }

    private func resetPinchOrigin(layer: ProBusinessCardCanvasLayerKind) {
        pinchOriginScale = currentScale(for: layer)
    }

    private func resetRotateOrigin(layer: ProBusinessCardCanvasLayerKind) {
        rotateOrigin = currentRotation(for: layer)
    }

    private func currentScale(for layer: ProBusinessCardCanvasLayerKind) -> Double {
        switch layer {
        case .photo: return design.style.photoCanvas?.scale ?? 1
        case .logo: return design.style.logoCanvas?.scale ?? 1
        case .name: return design.style.nameCanvas?.scale ?? 1
        case .qr: return design.style.qrCanvas?.scale ?? 1
        case .watermark: return design.style.watermark.scale
        }
    }

    private func currentRotation(for layer: ProBusinessCardCanvasLayerKind) -> Double {
        switch layer {
        case .photo: return design.style.photoCanvas?.rotation ?? 0
        case .logo: return design.style.logoCanvas?.rotation ?? 0
        case .name: return design.style.nameCanvas?.rotation ?? 0
        case .qr: return design.style.qrCanvas?.rotation ?? 0
        case .watermark: return design.style.watermark.rotation
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProBusinessCardCanvasLayerKind.allCases) { layer in
                        layerChip(layer)
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack {
                Toggle("Safe zone", isOn: $showSafeZone).tint(themeManager.current.accentColor)
                Toggle("Snap guides", isOn: $snapGuides).tint(themeManager.current.accentColor)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))

            Text("Tap any layer · drag · pinch · twist")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(16)
        .background(.black.opacity(0.45))
    }

    private func layerChip(_ layer: ProBusinessCardCanvasLayerKind) -> some View {
        let active = layer.isActive(in: design)
        let selected = selectedLayer == layer
        return Button {
            selectLayer(layer)
        } label: {
            Text(layer.title)
                .font(.system(size: 13, weight: selected ? .bold : .semibold))
                .foregroundStyle(selected ? .white : .white.opacity(active ? 0.9 : 0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selected ? themeManager.current.accentColor : Color.white.opacity(active ? 0.14 : 0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(selected ? 0 : 0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func snapGuideOverlay(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: height)
            Rectangle().fill(Color.white.opacity(0.15)).frame(width: width, height: 1)
        }
    }

    private var renderContext: ProBusinessCardRenderContext {
        ProBusinessCardRenderFactory.makeContext(design: design, logoData: logoData)
    }

    private func canvasPoint(_ layer: ProBusinessCardCanvasLayer, cardSize: CGSize) -> CGPoint {
        CGPoint(x: layer.normalizedX * cardSize.width, y: layer.normalizedY * cardSize.height)
    }

    private func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }
}

enum ProBusinessCardCanvasSeeder {
    static func ensureLayers(on design: inout ProBusinessCardDesign) {
        if design.options.showsPhoto, design.style.photoScale != .off {
            ensureLayer(.photo, on: &design)
        }
        if design.options.showsLogo {
            ensureLayer(.logo, on: &design)
        }
    }

    static func ensureLayer(_ kind: ProBusinessCardCanvasLayerKind, on design: inout ProBusinessCardDesign) {
        let cardSize = design.aspect.previewSize
        let inset = cardSize.height * design.aspect.safeInsetRatio
        let engine = ProBusinessCardLayoutEngine(
            cardSize: cardSize,
            safeInset: inset,
            photoScale: design.style.photoScale,
            placement: design.style.photoPlacement,
            showsPhoto: design.options.showsPhoto
        )
        let content = engine.contentRect()

        switch kind {
        case .photo:
            guard design.style.photoCanvas == nil, design.options.showsPhoto, design.style.photoScale != .off else { return }
            let frame = engine.photoFrame()
            design.style.photoCanvas = ProBusinessCardCanvasLayer(
                normalizedX: Double(frame.midX / cardSize.width),
                normalizedY: Double(frame.midY / cardSize.height),
                scale: 1,
                rotation: design.style.photoTransform.rotation
            )
        case .logo:
            guard design.style.logoCanvas == nil, design.options.showsLogo else { return }
            let logoSize = min(cardSize.height, cardSize.width) * design.style.logoScale.pointRatio
            design.style.logoCanvas = ProBusinessCardCanvasLayer(
                normalizedX: Double((inset + logoSize / 2) / cardSize.width),
                normalizedY: Double((inset + logoSize / 2) / cardSize.height),
                scale: 1,
                rotation: 0
            )
        case .name:
            guard design.style.nameCanvas == nil else { return }
            design.style.nameCanvas = ProBusinessCardCanvasLayer(
                normalizedX: Double(content.midX / cardSize.width),
                normalizedY: Double((content.minY + content.height * 0.18) / cardSize.height),
                scale: 1,
                rotation: 0
            )
        case .qr:
            guard design.style.qrCanvas == nil, design.options.showsQR else { return }
            design.style.qrCanvas = ProBusinessCardCanvasLayer(
                normalizedX: Double((content.maxX - 28) / cardSize.width),
                normalizedY: Double((content.maxY - 28) / cardSize.height),
                scale: 1,
                rotation: 0
            )
        case .watermark:
            break
        }
    }
}
