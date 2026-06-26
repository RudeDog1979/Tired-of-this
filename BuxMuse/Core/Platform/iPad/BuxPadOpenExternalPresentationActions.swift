//
//  BuxPadOpenExternalPresentationActions.swift
//  BuxMuse — Present Money Map / invoice preview on external display.
//

import SwiftUI

struct BuxPadPresentMoneyMapOnDisplayButton: View {
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        if BuxPadIdiom.isPad, padBrain.externalDisplayConnection.isConnected {
            Button {
                padBrain.requestExternalPresentation(.moneyMap)
            } label: {
                Label(BuxCatalogLabel.string("Present Money Map on Display", locale: appSettingsManager.interfaceLocale), systemImage: "display")
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
                Label(BuxCatalogLabel.string("Present Invoice on Display", locale: appSettingsManager.interfaceLocale), systemImage: "doc.richtext.fill")
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
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        if BuxPadIdiom.isPad {
            Menu {
                BuxPadPresentMoneyMapOnDisplayButton()
                BuxPadPresentInvoiceOnDisplayButton()
            } label: {
                Label(BuxCatalogLabel.string("External Display", locale: appSettingsManager.interfaceLocale), systemImage: "display.2")
            }
        }
    }
}
