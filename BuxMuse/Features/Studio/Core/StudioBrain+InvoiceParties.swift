//
//  StudioBrain+InvoiceParties.swift
//  BuxMuse
//
//  Invoice party & payment render assembly — delegates to InvoicePartyEngine.
//

import Foundation

extension StudioBrain {

    public func buildInvoiceRenderContext(
        invoice: StudioInvoice,
        client: StudioClient?,
        settings: StudioInvoiceSettings,
        templateConfig: InvoiceTemplateConfig,
        taxConfig: InvoiceTaxEngineConfig,
        paymentConfig: InvoicePaymentConfig,
        totals: InvoiceTotalsDisplay,
        formatAmount: @escaping (Decimal) -> String,
        snapshot: InvoiceDesignerSnapshot? = nil
    ) -> InvoiceRenderContext {
        let settingsStore = SettingsStore.shared
        let country = appSettings.selectedCountry.id
        return InvoicePartyEngine.enrichRenderContext(
            invoice: invoice,
            client: client,
            profile: store.profile,
            settings: settings,
            taxProfile: store.taxProfile,
            templateConfig: templateConfig,
            taxConfig: taxConfig,
            paymentConfig: paymentConfig,
            totals: totals,
            formatAmount: formatAmount,
            snapshotIssuer: snapshot?.issuerPartySnapshot,
            snapshotRecipient: snapshot?.recipientPartySnapshot,
            countryCode: country,
            autoDetectBankType: settingsStore.autoDetectInvoiceBankAccountType,
            manualOverride: settingsStore.invoiceBankAccountTypeOverride,
            interfaceLocale: appSettings.interfaceLocale
        )
    }

    public func partyDetailsForSnapshot(client: StudioClient?) -> (issuer: InvoicePartyDetails, recipient: InvoicePartyDetails?) {
        (store.profile.resolvedPartyDetails(), client.map { $0.resolvedPartyDetails() })
    }
}
