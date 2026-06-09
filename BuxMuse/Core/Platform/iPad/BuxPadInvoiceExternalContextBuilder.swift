//
//  BuxPadInvoiceExternalContextBuilder.swift
//  BuxMuse — Builds invoice preview context for external display (pad only).
//

import Foundation

enum BuxPadInvoiceExternalContextBuilder {
    @MainActor
    static func renderContext(
        for invoice: StudioInvoice,
        store: StudioStore,
        studioBrain: StudioBrain,
        appSettings: AppSettingsManager
    ) -> InvoiceRenderContext {
        let client = store.clients.first { $0.id == invoice.clientId }
        let snapshot = invoice.designerSnapshot
        let taxConfig = snapshot?.taxConfig ?? InvoiceTaxProfileResolver.config(
            taxProfile: store.taxProfile,
            settings: store.invoiceSettings,
            source: .taxProfile,
            clientRegionCode: client?.regionCode,
            locale: appSettings.interfaceLocale
        )
        let templateConfig = snapshot?.templateConfig ?? store.invoiceSettings.defaultTemplateConfig ?? .default
        let paymentConfig = snapshot?.paymentConfig ?? store.invoiceSettings.defaultPaymentConfig ?? .default
        let totals = InvoiceDesignerEngine.computeTotals(
            items: invoice.lineItems,
            taxConfig: taxConfig,
            currencyCode: invoice.currencyCode
        )

        return studioBrain.buildInvoiceRenderContext(
            invoice: invoice,
            client: client,
            settings: store.invoiceSettings,
            templateConfig: templateConfig,
            taxConfig: taxConfig,
            paymentConfig: paymentConfig,
            totals: totals,
            formatAmount: { appSettings.format($0) },
            snapshot: snapshot
        )
    }

    @MainActor
    static func latestInvoiceContext(
        store: StudioStore,
        studioBrain: StudioBrain,
        appSettings: AppSettingsManager
    ) -> InvoiceRenderContext? {
        guard let invoice = store.invoices.last else {
            return nil
        }
        return renderContext(
            for: invoice,
            store: store,
            studioBrain: studioBrain,
            appSettings: appSettings
        )
    }
}
