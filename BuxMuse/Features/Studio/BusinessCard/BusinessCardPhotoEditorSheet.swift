//
//  BusinessCardPhotoEditorSheet.swift
//  BuxMuse
//
//  Apple Photos-style editor with live card preview.
//

import SwiftUI

struct BusinessCardPhotoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let design: ProBusinessCardDesign
    let logoData: Data?
    let inputImage: UIImage
    let onSave: (UIImage, ProBusinessCardPhotoTransform) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var showGuides = true
    @State private var cropSize: CGFloat = 280

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let viewport = min(geo.size.width - 48, geo.size.height * 0.52, 420)
                VStack(spacing: BuxTokens.section) {
                    liveCardPreview

                    ZStack {
                        cropViewport(size: viewport)
                        if showGuides { alignmentGuides(size: viewport) }
                    }
                    .frame(width: viewport + 36, height: viewport + 36)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .onAppear { cropSize = viewport }

                    Toggle(BusinessCardL10n.line("Alignment guides", locale: appSettingsManager.interfaceLocale), isOn: $showGuides)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "minus.magnifyingglass").foregroundStyle(Color.white.opacity(0.55))
                            Slider(value: $scale, in: 1...4)
                                .tint(themeManager.contrastAccentColor(for: colorScheme))
                            Image(systemName: "plus.magnifyingglass").foregroundStyle(Color.white.opacity(0.55))
                        }
                        HStack {
                            Image(systemName: "rotate.left").foregroundStyle(Color.white.opacity(0.55))
                            Slider(value: $rotation, in: -180...180)
                                .tint(themeManager.contrastAccentColor(for: colorScheme))
                            Image(systemName: "rotate.right").foregroundStyle(Color.white.opacity(0.55))
                        }
                        BuxCatalogDynamicText(key: "Drag to move · pinch or slide to zoom · rotate to straighten")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 0)
                }
                .padding(.top, BuxTokens.section)
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(Color.black.opacity(0.92).ignoresSafeArea())
            .buxCatalogNavigationTitle("Edit photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.92), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BusinessCardL10n.line("Cancel", locale: appSettingsManager.interfaceLocale)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(BusinessCardL10n.line("Done", locale: appSettingsManager.interfaceLocale)) { saveCropped() }.fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .foregroundStyle(.white)
        .onAppear {
            scale = max(1, CGFloat(design.style.photoTransform.zoom))
            lastScale = scale
            rotation = design.style.photoTransform.rotation
            let base = max(cropSize, 280)
            offset = CGSize(
                width: CGFloat(design.style.photoTransform.offsetX) * base * 2,
                height: CGFloat(design.style.photoTransform.offsetY) * base * 2
            )
            lastOffset = offset
        }
    }

    private var liveCardPreview: some View {
        let previewDesign = previewDesignWithTransform
        let context = ProBusinessCardRenderFactory.makeContext(design: previewDesign, logoData: logoData)
        let fit = min(1, 160 / max(context.size.height, 1))
        return VStack(spacing: 4) {
            BuxCatalogDynamicText(key: "Live preview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))
            ProBusinessCardRenderer(context: context)
                .scaleEffect(fit)
                .frame(width: max(1, context.size.width * fit), height: max(1, context.size.height * fit))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
    }

    private var previewDesignWithTransform: ProBusinessCardDesign {
        var copy = design
        copy.options.showsPhoto = true
        copy.style.photoTransform = currentTransform
        return copy
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

    private func cropViewport(size: CGFloat) -> some View {
        Image(uiImage: inputImage)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .gesture(dragGesture.simultaneously(with: magnificationGesture))
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

    private func saveCropped() {
        let output = max(cropSize, 280)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: output, height: output))
        let cropped = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: output, height: output)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.clip()
            ctx.cgContext.translateBy(x: output / 2 + offset.width, y: output / 2 + offset.height)
            ctx.cgContext.rotate(by: CGFloat(rotation * .pi / 180))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            let draw = CGRect(x: -output / 2, y: -output / 2, width: output, height: output)
            inputImage.draw(in: draw)
        }
        onSave(cropped, currentTransform)
        dismiss()
    }
}
