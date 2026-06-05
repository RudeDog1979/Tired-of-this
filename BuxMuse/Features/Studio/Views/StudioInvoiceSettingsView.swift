//
//  StudioInvoiceSettingsView.swift
//  BuxMuse
//
//  Invoice numbering, templates, tax behavior, and bank details.
//

import SwiftUI

struct StudioInvoiceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    @State private var prefix = "INV"
    @State private var pattern = "{PREFIX}-{YEAR}-{SEQ}"
    @State private var template: InvoiceTemplate = .professional
    @State private var taxBehavior: InvoiceTaxBehavior = .taxAdded
    @State private var logoPosition: InvoiceLogoPosition = .topLeft
    @State private var documentLabel = "Invoice"
    @State private var showTaxID = false
    @State private var showBankDetails = true
    @State private var bankDetails = ""
    @State private var showLegalFooter = true
    @State private var defaultTaxRate = ""
    @State private var savedBanner: String?
    @State private var lastSavedDraft: InvoiceSettingsDraft?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

            BuxThemedCardForm {
                BuxFormSection(title: "Numbering") {
                    TextField(loc("Prefix"), text: $prefix)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField(loc("Pattern"), text: $pattern)
                        .buxFormFieldPadding()
                    BuxCatalogDynamicText(key: "Use {PREFIX}, {YEAR}, {SEQ}")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                    Text(
                        BuxLocalizedString.format(
                            "Preview: %@",
                            locale: appSettingsManager.interfaceLocale,
                            previewNumber
                        )
                    )
                        .font(.system(size: 12, weight: .semibold))
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Design") {
                    Picker(loc("Template"), selection: $template) {
                        ForEach(InvoiceTemplate.allCases) { t in
                            Text(t.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(t)
                        }
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Picker(loc("Logo position"), selection: $logoPosition) {
                        ForEach(InvoiceLogoPosition.allCases) { p in
                            Text(p.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(p)
                        }
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField(loc("Document label"), text: $documentLabel)
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Tax on invoices") {
                    Picker(loc("Tax behavior"), selection: $taxBehavior) {
                        ForEach(InvoiceTaxBehavior.allCases) { b in
                            Text(b.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(b)
                        }
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField(loc("Default tax rate %"), text: $defaultTaxRate)
                        .keyboardType(.decimalPad)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Toggle(loc("Show tax ID on PDF"), isOn: $showTaxID)
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Payment") {
                    Toggle(loc("Show bank details"), isOn: $showBankDetails)
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField(loc("Bank / payment details"), text: $bankDetails, axis: .vertical)
                        .lineLimit(3...8)
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Legal footer") {
                    Toggle(loc("Show registration footer on PDF"), isOn: $showLegalFooter)
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                    BuxCatalogDynamicText(key: "Displays company address and registration at the bottom of designed invoices.")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                }

                if let savedBanner {
                    BuxFormSection {
                        Text(savedBanner)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                            .buxFormFieldPadding()
                    }
                }
            }
        }
        .buxCatalogNavigationTitle("Invoice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.studioEnhancedTint, true)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                BuxToolbarSaveButton(isDirty: hasUnsavedChanges) {
                    saveSettings()
                }
            }
        }
        .onAppear { hydrate() }
    }

    private var previewNumber: String {
        var draft = StudioInvoiceSettings()
        draft.numberPrefix = prefix
        draft.numberPattern = pattern
        let year = Calendar.current.component(.year, from: Date())
        return draft.formatInvoiceNumber(sequence: 1, year: year)
    }

    private var currentDraft: InvoiceSettingsDraft {
        InvoiceSettingsDraft(
            prefix: prefix,
            pattern: pattern,
            template: template,
            taxBehavior: taxBehavior,
            logoPosition: logoPosition,
            documentLabel: documentLabel,
            showTaxID: showTaxID,
            showBankDetails: showBankDetails,
            bankDetails: bankDetails,
            showLegalFooter: showLegalFooter,
            defaultTaxRate: defaultTaxRate
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let lastSavedDraft else { return true }
        return lastSavedDraft != currentDraft
    }

    private func hydrate() {
        let s = store.invoiceSettings
        prefix = s.numberPrefix
        pattern = s.numberPattern
        template = s.defaultTemplate
        taxBehavior = s.defaultTaxBehavior
        logoPosition = s.logoPosition
        documentLabel = s.documentLabel
        showTaxID = s.showTaxID
        showBankDetails = s.showBankDetails
        bankDetails = s.bankDetails
        showLegalFooter = s.showLegalFooter
        if let rate = s.defaultTaxRatePercent { defaultTaxRate = "\(rate)" }
        lastSavedDraft = currentDraft
    }

    private func saveSettings() {
        var settings = store.invoiceSettings
        settings.numberPrefix = prefix
        settings.numberPattern = pattern
        settings.defaultTemplate = template
        settings.defaultTaxBehavior = taxBehavior
        settings.logoPosition = logoPosition
        settings.documentLabel = documentLabel
        settings.showTaxID = showTaxID
        settings.showBankDetails = showBankDetails
        settings.bankDetails = bankDetails
        settings.showLegalFooter = showLegalFooter
        settings.defaultTaxRatePercent = Decimal(string: defaultTaxRate)
        store.updateInvoiceSettings(settings)
        lastSavedDraft = currentDraft
        BuxSaveFeedback.success()
        savedBanner = loc("Invoice settings saved")
    }
}

private struct InvoiceSettingsDraft: Equatable {
    var prefix: String
    var pattern: String
    var template: InvoiceTemplate
    var taxBehavior: InvoiceTaxBehavior
    var logoPosition: InvoiceLogoPosition
    var documentLabel: String
    var showTaxID: Bool
    var showBankDetails: Bool
    var bankDetails: String
    var showLegalFooter: Bool
    var defaultTaxRate: String
}
