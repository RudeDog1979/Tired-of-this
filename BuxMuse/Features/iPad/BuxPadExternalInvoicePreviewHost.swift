//
//  BuxPadExternalInvoicePreviewHost.swift
//  BuxMuse — Live invoice A4 preview for external display (controls stay on iPad).
//

import SwiftUI

struct BuxPadExternalInvoicePreviewHost: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            if let context = resolvedContext {
                VStack(spacing: 24) {
                    BuxCatalogText.text("Invoice Preview")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    InvoicePreviewCanvas(context: context)
                        .frame(maxWidth: 720)
                        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
                }
                .padding(32)
            } else {
                BuxPadDetailEmptyState(
                    title: "Invoice Preview",
                    systemImage: "doc.richtext",
                    message: "Open an invoice on iPad, then present it on the external display."
                )
            }
        }
        .onChange(of: studioStore.invoices) { _, _ in
            refreshInvoiceContextFromStore()
        }
        .onAppear {
            refreshInvoiceContextFromStore()
        }
    }

    private var resolvedContext: InvoiceRenderContext? {
        padBrain.externalInvoiceContext
    }

    private func refreshInvoiceContextFromStore() {
        guard padBrain.activeExternalPresentation == .invoicePreview else { return }
        if let targetId = padBrain.externalInvoiceTargetId,
           let invoice = studioStore.invoices.first(where: { $0.id == targetId }) {
            let context = BuxPadInvoiceExternalContextBuilder.renderContext(
                for: invoice,
                store: studioStore,
                studioBrain: studioBrain,
                appSettings: appSettingsManager
            )
            padBrain.updateExternalInvoiceContext(context, targetInvoiceId: targetId)
            return
        }
        if padBrain.externalInvoiceContext == nil,
           let context = BuxPadInvoiceExternalContextBuilder.latestInvoiceContext(
               store: studioStore,
               studioBrain: studioBrain,
               appSettings: appSettingsManager
           ) {
            padBrain.updateExternalInvoiceContext(context, targetInvoiceId: context.invoice.id)
        }
    }
}
