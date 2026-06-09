//
//  BuxPadInvoiceSignatureChrome.swift
//  BuxMuse — iPad Pencil signing on invoice detail screens.
//

import SwiftUI

extension View {
    func buxPadInvoiceSignatureChrome(invoiceId: UUID) -> some View {
        modifier(BuxPadInvoiceSignatureChromeModifier(invoiceId: invoiceId))
    }
}

private struct BuxPadInvoiceSignatureChromeModifier: ViewModifier {
    let invoiceId: UUID

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var showSignatureCapture = false
    @State private var previewToken = 0

    private var hasSignature: Bool {
        _ = previewToken
        return BuxPadInvoiceSignatureStore.hasSignature(for: invoiceId)
    }

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if BuxPadIdiom.isPad {
                    signaturePanel
                }
            }
            .sheet(isPresented: $showSignatureCapture) {
                BuxPadInvoiceSignatureCaptureSheet(invoiceId: invoiceId) {
                    previewToken &+= 1
                }
                .environmentObject(themeManager)
            }
    }

    private var signaturePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Provider signature", systemImage: "signature")
                    .font(.system(size: 12, weight: .bold))
                    .buxLabelSecondary()
                Spacer()
                if hasSignature {
                    Text("Saved")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.contrastAccentColor(for: colorScheme).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 12) {
                if let image = BuxPadInvoiceSignatureStore.loadImage(for: invoiceId) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 44)
                        .padding(.horizontal, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }

                BuxActionButton(
                    title: hasSignature ? "Re-sign" : "Sign with Apple Pencil",
                    systemImage: "applepencil.gen1",
                    role: .tinted(themeManager.contrastAccentColor(for: colorScheme)),
                    accent: themeManager.contrastAccentColor(for: colorScheme),
                    expands: true,
                    action: { showSignatureCapture = true }
                )

                if hasSignature {
                    Button("Clear") {
                        BuxPadInvoiceSignatureStore.clearSignature(for: invoiceId)
                        previewToken &+= 1
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

struct BuxPadInvoiceSignatureCaptureSheet: View {
    let invoiceId: UUID
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        BuxPadAgreementSignatureCaptureSheet(role: .provider) { png in
            BuxPadInvoiceSignatureStore.savePNG(png, for: invoiceId)
            onSaved()
        }
        .environmentObject(themeManager)
    }
}
