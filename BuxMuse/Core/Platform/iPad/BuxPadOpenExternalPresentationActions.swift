//
//  BuxPadOpenExternalPresentationActions.swift
//  BuxMuse — Present Money Map / invoice preview on external display.
//

import SwiftUI

struct BuxPadPresentMoneyMapOnDisplayButton: View {
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain

    var body: some View {
        if BuxPadIdiom.isPad, padBrain.externalDisplayConnection.isConnected {
            Button {
                padBrain.requestExternalPresentation(.moneyMap)
            } label: {
                Label("Present Money Map on Display", systemImage: "display")
            }
        }
    }
}

struct BuxPadPresentInvoiceOnDisplayButton: View {
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        if BuxPadIdiom.isPad, padBrain.externalDisplayConnection.isConnected {
            Button {
                presentLatestInvoice()
            } label: {
                Label("Present Invoice on Display", systemImage: "doc.richtext.fill")
            }
            .disabled(studioStore.invoices.isEmpty && padBrain.externalInvoiceContext == nil)
        }
    }

    private func presentLatestInvoice() {
        if let context = padBrain.externalInvoiceContext {
            padBrain.updateExternalInvoiceContext(context, targetInvoiceId: context.invoice.id)
        } else if let context = BuxPadInvoiceExternalContextBuilder.latestInvoiceContext(
            store: studioStore,
            studioBrain: studioBrain,
            appSettings: appSettingsManager
        ) {
            padBrain.updateExternalInvoiceContext(context, targetInvoiceId: context.invoice.id)
        }
        padBrain.requestExternalPresentation(.invoicePreview)
    }
}

struct BuxPadExternalDisplayMenu: View {
    var body: some View {
        if BuxPadIdiom.isPad {
            Menu {
                BuxPadPresentMoneyMapOnDisplayButton()
                BuxPadPresentInvoiceOnDisplayButton()
            } label: {
                Label("External Display", systemImage: "display.2")
            }
        }
    }
}
