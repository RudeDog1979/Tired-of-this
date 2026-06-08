//
//  BuxPhotoStudioView.swift
//  BuxMuse
//
//  Unified Apple Photos-style editor — crop, filters, light, frame masks.
//

import SwiftUI

private enum BuxPhotoStudioTab: String, CaseIterable, Identifiable {
    case adjust, filters, light
    var id: String { rawValue }
    var catalogKey: String {
        switch self {
        case .adjust: return "Crop"
        case .filters: return "Filters"
        case .light: return "Light"
        }
    }
    var icon: String {
        switch self {
        case .adjust: return "crop.rotate"
        case .filters: return "camera.filters"
        case .light: return "sun.max"
        }
    }
}

struct BuxPhotoStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let design: ProBusinessCardDesign
    let logoData: Data?
    let session: BuxPhotoStudioSession
    let onApply: (BuxPhotoStudioResult) -> Void

    @State private var selectedTarget: BuxPhotoStudioTarget
    @State private var activeTab: BuxPhotoStudioTab = .adjust
    @State private var scale: CGFloat = 1
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1
    @State private var showGuides = true
    @State private var cropSize: CGFloat = 280
    @State private var mask: CardImageMask
    @State private var adjustments: ProBusinessCardPhotoAdjustments
    @State private var renderedPreview: UIImage?
    @State private var isRendering = false
    @State private var sourceImage: UIImage

    init(
        design: ProBusinessCardDesign,
        logoData: Data?,
        session: BuxPhotoStudioSession,
        onApply: @escaping (BuxPhotoStudioResult) -> Void
    ) {
        self.design = design
        self.logoData = logoData
        self.session = session
        self.onApply = onApply
        _selectedTarget = State(initialValue: session.selectedTarget)
        _mask = State(initialValue: session.initialMask)
        _adjustments = State(initialValue: session.initialAdjustments)
        _sourceImage = State(initialValue: session.image)
        _scale = State(initialValue: max(1, CGFloat(session.initialTransform.zoom)))
        _lastScale = State(initialValue: max(1, CGFloat(session.initialTransform.zoom)))
        _rotation = State(initialValue: session.initialTransform.rotation)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let viewport = min(geo.size.width - 48, geo.size.height * 0.38, 380)
                VStack(spacing: 12) {
                    liveCardPreview
                    targetPicker
                    tabBar
                    editorContent(viewport: viewport)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear { cropSize = viewport }
            }
            .background(Color.black.opacity(0.94).ignoresSafeArea())
            .foregroundStyle(.white)
            .buxCatalogNavigationTitle("Bux Photo Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BusinessCardL10n.line("Cancel", locale: appSettingsManager.interfaceLocale)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(BusinessCardL10n.line("Done", locale: appSettingsManager.interfaceLocale)) { applyEdits() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: adjustments) { _, _ in Task { await renderPreview() } }
        .onAppear {
            let base = max(cropSize, 280)
            offset = CGSize(
                width: CGFloat(session.initialTransform.offsetX) * base * 2,
                height: CGFloat(session.initialTransform.offsetY) * base * 2
            )
            lastOffset = offset
        }
    }

    private var liveCardPreview: some View {
        let previewDesign = previewDesignSnapshot
        let context = ProBusinessCardRenderFactory.makeContext(design: previewDesign, logoData: logoData)
        let fit = min(1, 130 / max(context.size.height, 1))
        return VStack(spacing: 4) {
            BuxCatalogDynamicText(key: "Live preview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))
            ProBusinessCardRenderer(context: context)
                .scaleEffect(fit)
                .frame(width: max(1, context.size.width * fit), height: max(1, context.size.height * fit))
                .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
        }
    }

    @ViewBuilder
    private var targetPicker: some View {
        if session.targets.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.targets, id: \.self) { target in
                        Button {
                            selectedTarget = target
                        } label: {
                            Label(target.catalogTitle(locale: appSettingsManager.interfaceLocale), systemImage: target.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTarget == target ? themeManager.current.accentColor : Color.white.opacity(0.12))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(BuxPhotoStudioTab.allCases) { tab in
                Button {
                    activeTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(BusinessCardL10n.line(tab.catalogKey, locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(activeTab == tab ? .white : Color.white.opacity(0.45))
                    .background(activeTab == tab ? Color.white.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func editorContent(viewport: CGFloat) -> some View {
        switch activeTab {
        case .adjust:
            adjustPanel(viewport: viewport)
        case .filters:
            filtersPanel
        case .light:
            lightPanel
        }
    }

    private func adjustPanel(viewport: CGFloat) -> some View {
        VStack(spacing: 12) {
            ZStack {
                cropViewport(size: viewport)
                if showGuides { alignmentGuides(size: viewport) }
            }
            .frame(width: viewport + 36, height: viewport + 36)
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if selectedTarget.supportsFrameMask {
                maskPicker
            }

            Toggle(BusinessCardL10n.line("Alignment guides", locale: appSettingsManager.interfaceLocale), isOn: $showGuides)
                .font(.system(size: 13, weight: .medium))
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                sliderRow(iconLeft: "minus.magnifyingglass", iconRight: "plus.magnifyingglass", value: $scale, range: 1...4) {
                    lastScale = scale
                }
                sliderRow(iconLeft: "rotate.left", iconRight: "rotate.right", value: Binding(
                    get: { rotation },
                    set: { rotation = $0 }
                ), range: -180...180)
                BuxCatalogDynamicText(key: "Drag to move · pinch or slide to zoom · rotate to straighten")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 20)
        }
    }

    private var maskPicker: some View {
        HStack(spacing: 8) {
            BuxCatalogDynamicText(key: "Frame")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))
            ForEach([CardImageMask.circle, .roundedRect, .none], id: \.self) { option in
                Button {
                    mask = option
                } label: {
                    Text(option.catalogTitle(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(mask == option ? themeManager.current.accentColor : Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private var filtersPanel: some View {
        VStack(spacing: 14) {
            ZStack {
                if let img = renderedPreview {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if isRendering { ProgressView().tint(.white) }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BusinessCardCIFilterPipeline.presets, id: \.ciName) { preset in
                        Button(BusinessCardCIFilterPipeline.catalogName(for: preset.name, locale: appSettingsManager.interfaceLocale)) {
                            adjustments.filterName = preset.ciName
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(adjustments.filterName == preset.ciName ? themeManager.current.accentColor : Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var lightPanel: some View {
        ScrollView {
            VStack(spacing: 12) {
                lightSlider(BusinessCardL10n.line("Exposure", locale: appSettingsManager.interfaceLocale), value: $adjustments.exposure, range: -1...1)
                lightSlider(BusinessCardL10n.line("Brilliance", locale: appSettingsManager.interfaceLocale), value: $adjustments.brilliance, range: -1...1)
                lightSlider(BusinessCardL10n.line("Brightness", locale: appSettingsManager.interfaceLocale), value: $adjustments.brightness, range: -0.5...0.5)
                lightSlider(BusinessCardL10n.line("Contrast", locale: appSettingsManager.interfaceLocale), value: $adjustments.contrast, range: 0.5...1.8)
                lightSlider(BusinessCardL10n.line("Saturation", locale: appSettingsManager.interfaceLocale), value: $adjustments.saturation, range: 0...2)
                lightSlider(BusinessCardL10n.line("Sharpness", locale: appSettingsManager.interfaceLocale), value: $adjustments.sharpness, range: 0...1.5)
            }
            .padding(20)
        }
    }

    private func cropViewport(size: CGFloat) -> some View {
        let displayImage = renderedPreview ?? sourceImage
        return Image(uiImage: displayImage)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .frame(width: size, height: size)
            .clipShape(maskShape(for: mask, size: size))
            .overlay(maskStroke(for: mask, size: size))
            .gesture(dragGesture.simultaneously(with: magnificationGesture))
    }

    private func maskShape(for mask: CardImageMask, size: CGFloat) -> BuxPhotoMaskShape {
        switch mask {
        case .none:
            return BuxPhotoMaskShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        case .circle:
            return BuxPhotoMaskShape(Circle())
        case .roundedRect:
            return BuxPhotoMaskShape(RoundedRectangle(cornerRadius: size * 0.14, style: .continuous))
        }
    }

    @ViewBuilder
    private func maskStroke(for mask: CardImageMask, size: CGFloat) -> some View {
        switch mask {
        case .none:
            RoundedRectangle(cornerRadius: 4).stroke(Color.white, lineWidth: 2)
        case .circle:
            Circle().stroke(Color.white, lineWidth: 2)
        case .roundedRect:
            RoundedRectangle(cornerRadius: size * 0.14).stroke(Color.white, lineWidth: 2)
        }
    }

    private func alignmentGuides(size: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1, height: size)
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: size, height: 1)
            Circle().stroke(Color.white.opacity(0.45), lineWidth: 1).frame(width: size * 0.72)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    private func sliderRow(
        iconLeft: String,
        iconRight: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        onEnd: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Image(systemName: iconLeft).foregroundStyle(Color.white.opacity(0.55))
            Slider(value: value, in: range) { editing in
                if !editing { onEnd?() }
            }
            .tint(themeManager.contrastAccentColor(for: colorScheme))
            Image(systemName: iconRight).foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private func sliderRow(
        iconLeft: String,
        iconRight: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Image(systemName: iconLeft).foregroundStyle(Color.white.opacity(0.55))
            Slider(value: value, in: range)
                .tint(themeManager.contrastAccentColor(for: colorScheme))
            Image(systemName: iconRight).foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private func lightSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            Slider(value: value, in: range)
                .tint(themeManager.contrastAccentColor(for: colorScheme))
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { v in scale = min(4, max(1, lastScale * v)) }
            .onEnded { _ in lastScale = scale }
    }

    private var currentTransform: ProBusinessCardPhotoTransform {
        let base = max(cropSize, 1)
        return ProBusinessCardPhotoTransform(
            zoom: Double(scale),
            offsetX: Double(offset.width / base) * 0.5,
            offsetY: Double(offset.height / base) * 0.5,
            rotation: rotation
        )
    }

    private var previewDesignSnapshot: ProBusinessCardDesign {
        var copy = design
        switch selectedTarget {
        case .profilePhoto:
            copy.options.showsPhoto = true
            copy.style.photoTransform = currentTransform
            copy.style.photoAdjustments = adjustments
            copy.style.photoMask = mask
        case .logo:
            copy.options.showsLogo = true
            copy.style.logoMask = mask
        case .backgroundPhoto:
            copy.style.photoTransform = currentTransform
        case .canvasLayer:
            copy.style.photoTransform = currentTransform
            copy.style.photoAdjustments = adjustments
        }
        return copy
    }

    private func renderPreview() async {
        isRendering = true
        let adj = adjustments
        let img = sourceImage
        let result = await Task.detached(priority: .userInitiated) {
            BusinessCardPhotoLabEngine.render(source: img, adjustments: adj)
        }.value
        renderedPreview = result ?? img
        isRendering = false
    }

    private func applyEdits() {
        let output = max(cropSize, 280)
        let baseImage = renderedPreview ?? sourceImage
        let cropped = renderCroppedImage(from: baseImage, outputSize: output)
        onApply(BuxPhotoStudioResult(
            target: selectedTarget,
            image: cropped,
            transform: currentTransform,
            adjustments: adjustments,
            mask: mask
        ))
        dismiss()
    }

    private func renderCroppedImage(from image: UIImage, outputSize: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
            switch mask {
            case .circle:
                ctx.cgContext.addEllipse(in: rect)
            case .roundedRect:
                ctx.cgContext.addPath(UIBezierPath(roundedRect: rect, cornerRadius: outputSize * 0.14).cgPath)
            case .none:
                ctx.cgContext.addRect(rect)
            }
            ctx.cgContext.clip()
            ctx.cgContext.translateBy(x: outputSize / 2 + offset.width, y: outputSize / 2 + offset.height)
            ctx.cgContext.rotate(by: CGFloat(rotation * .pi / 180))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            let draw = CGRect(x: -outputSize / 2, y: -outputSize / 2, width: outputSize, height: outputSize)
            image.draw(in: draw)
        }
    }
}

private struct BuxPhotoMaskShape: Shape {
    private let builder: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) { builder = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { builder(rect) }
}
