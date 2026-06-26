//
//  BusinessCardPhotoLabView.swift
//  BuxMuse
//
//  CoreImage photo lab — filters + adjustments with live card preview.
//

import SwiftUI

struct BusinessCardPhotoLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let design: ProBusinessCardDesign
    let logoData: Data?
    let sourceImage: UIImage
    @Binding var adjustments: ProBusinessCardPhotoAdjustments
    let onApply: (UIImage) -> Void

    @State private var renderedImage: UIImage?
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                previewSection
                filterStrip
                adjustmentPanel
            }
            .background(Color.black.opacity(0.94).ignoresSafeArea())
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .buxCatalogNavigationTitle("Bux Photo Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale)) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(BuxCatalogLabel.string("Apply", locale: appSettingsManager.interfaceLocale)) {
                        if let renderedImage { onApply(renderedImage) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(renderedImage == nil)
                }
        }
        .preferredColorScheme(.dark)
        .foregroundStyle(.white)
        .task { await render() }
            .onChange(of: adjustments.filterName) { _, _ in Task { await render() } }
        }
    }

    private var previewSection: some View {
        VStack(spacing: 8) {
            BuxCatalogDynamicText(key: "Live on your card")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))
            let previewDesign = previewDesignWithAdjustments
            let context = ProBusinessCardRenderFactory.makeContext(design: previewDesign, logoData: logoData)
            let fit = min(1, 180 / context.size.height)
            ProBusinessCardRenderer(context: context)
                .scaleEffect(fit)
                .frame(width: context.size.width * fit, height: context.size.height * fit)
                .shadow(radius: 8, y: 4)

            ZStack {
                if let img = renderedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if isRendering { ProgressView() }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }

    private var previewDesignWithAdjustments: ProBusinessCardDesign {
        var copy = design
        copy.options.showsPhoto = true
        copy.style.photoAdjustments = adjustments
        return copy
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BusinessCardCIFilterPipeline.presets, id: \.ciName) { preset in
                    Button(preset.name) {
                        adjustments.filterName = preset.ciName
                        Task { await render() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(adjustments.filterName == preset.ciName ? themeManager.current.accentColor : Color.white.opacity(0.12))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private var adjustmentPanel: some View {
        VStack(spacing: 10) {
            labSlider("Brightness", value: $adjustments.brightness, range: -0.5...0.5)
            labSlider("Contrast", value: $adjustments.contrast, range: 0.5...1.8)
            labSlider("Saturation", value: $adjustments.saturation, range: 0...2)
            labSlider("Sharpness", value: $adjustments.sharpness, range: 0...1.5)
        }
        .padding()
        .background(Color.white.opacity(0.08))
    }

    private func labSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue)).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range) { editing in
                if !editing { Task { await render() } }
            }
            .tint(themeManager.contrastAccentColor(for: colorScheme))
        }
    }

    private func render() async {
        isRendering = true
        let adj = adjustments
        let img = sourceImage
        let result = await Task.detached(priority: .userInitiated) {
            BusinessCardPhotoLabEngine.render(source: img, adjustments: adj)
        }.value
        renderedImage = result ?? img
        isRendering = false
    }
}
