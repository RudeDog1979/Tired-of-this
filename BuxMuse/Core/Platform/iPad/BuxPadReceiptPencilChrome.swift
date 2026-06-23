//
//  BuxPadReceiptPencilChrome.swift
//  BuxMuse — iPad receipt markup entry points (detail + scanner preview).
//

import SwiftUI

extension View {
    /// Saved receipt detail — preview scan + Markup toolbar action (iPad only).
    func buxPadReceiptDetailPencilChrome(receipt: StudioReceipt) -> some View {
        modifier(BuxPadReceiptDetailPencilChromeModifier(receipt: receipt))
    }

    /// Scanner draft image — Pencil markup sheet (iPad only).
    func buxPadReceiptScannerPencilChrome(
        scannedImage: Binding<UIImage?>,
        isPresented: Binding<Bool>
    ) -> some View {
        modifier(BuxPadReceiptScannerPencilChromeModifier(
            scannedImage: scannedImage,
            isPresented: isPresented
        ))
    }
}

private struct BuxPadReceiptDetailPencilChromeModifier: ViewModifier {
    let receipt: StudioReceipt

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showMarkup = false
    @State private var previewToken = 0

    private var interfaceLocale: Locale { BuxInterfaceLocale.currentInterfaceLocale }

    private var canMarkup: Bool {
        BuxPadIdiom.isPad && receipt.localImagePath != nil
    }

    private var previewImage: UIImage? {
        _ = previewToken
        return BuxPadReceiptMarkupStore.previewImage(basePath: receipt.localImagePath, receiptId: receipt.id)
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if canMarkup, let previewImage {
                    receiptPreviewCard(previewImage)
                }
            }
            .toolbar {
                if canMarkup {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showMarkup = true
                        } label: {
                            Label {
                                Text(BuxLocalizedString.string("Markup", locale: interfaceLocale))
                            } icon: {
                                Image(systemName: "pencil.tip.crop.circle")
                            }
                        }
                        .buxToolbarTextActionStyle(accent: themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showMarkup) {
                BuxPadReceiptMarkupSheet(source: .savedReceipt(receipt))
                    .environmentObject(themeManager)
                    .onDisappear {
                        previewToken &+= 1
                    }
            }
    }

    private func receiptPreviewCard(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(BuxLocalizedString.string("Receipt scan", locale: interfaceLocale))
                } icon: {
                    Image(systemName: "doc.viewfinder")
                }
                    .font(.system(size: 12, weight: .bold))
                    .buxLabelSecondary()
                Spacer()
                if BuxPadReceiptMarkupStore.hasMarkup(for: receipt.id) {
                    Text(BuxLocalizedString.string("Markup saved", locale: interfaceLocale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.contrastAccentColor(for: colorScheme).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
                )
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
        .padding(.top, BuxLayout.tight)
        .padding(.bottom, BuxLayout.unit)
    }
}

private struct BuxPadReceiptScannerPencilChromeModifier: ViewModifier {
    @Binding var scannedImage: UIImage?
    @Binding var isPresented: Bool

    @EnvironmentObject private var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                if let binding = draftImageBinding {
                    BuxPadReceiptMarkupSheet(source: .draftImage(binding))
                        .environmentObject(themeManager)
                }
            }
    }

    private var draftImageBinding: Binding<UIImage>? {
        guard scannedImage != nil else { return nil }
        return Binding(
            get: { scannedImage ?? UIImage() },
            set: { scannedImage = $0 }
        )
    }
}

extension View {
    @ViewBuilder
    func buxPadScannerMarkupButton(action: @escaping () -> Void) -> some View {
        if BuxPadIdiom.isPad {
            Button(action: action) {
                Label {
                    Text(BuxLocalizedString.string("Mark up with Apple Pencil", locale: BuxInterfaceLocale.currentInterfaceLocale))
                } icon: {
                    Image(systemName: "pencil.tip.crop.circle")
                }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buxNativeButtonStyle(.secondary, controlSize: .regular)
            .padding(.horizontal)
        }
    }
}
