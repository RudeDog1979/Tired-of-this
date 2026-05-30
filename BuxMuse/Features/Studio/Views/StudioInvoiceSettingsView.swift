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

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

            BuxThemedCardForm {
                BuxFormSection(title: "Numbering") {
                    TextField("Prefix", text: $prefix)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField("Pattern", text: $pattern)
                        .buxFormFieldPadding()
                    Text("Use {PREFIX}, {YEAR}, {SEQ}")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                        .buxFormFieldPadding()
                    Text("Preview: \(previewNumber)")
                        .font(.system(size: 12, weight: .semibold))
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Design") {
                    Picker("Template", selection: $template) {
                        ForEach(InvoiceTemplate.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Picker("Logo position", selection: $logoPosition) {
                        ForEach(InvoiceLogoPosition.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField("Document label", text: $documentLabel)
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Tax on invoices") {
                    Picker("Tax behavior", selection: $taxBehavior) {
                        ForEach(InvoiceTaxBehavior.allCases) { b in
                            Text(b.rawValue).tag(b)
                        }
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField("Default tax rate %", text: $defaultTaxRate)
                        .keyboardType(.decimalPad)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Toggle("Show tax ID on PDF", isOn: $showTaxID)
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Payment") {
                    Toggle("Show bank details", isOn: $showBankDetails)
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField("Bank / payment details", text: $bankDetails, axis: .vertical)
                        .lineLimit(3...8)
                        .buxFormFieldPadding()
                }

                BuxFormSection(title: "Legal footer") {
                    Toggle("Show registration footer on PDF", isOn: $showLegalFooter)
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                    Text("Displays company address and registration at the bottom of designed invoices.")
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
        .navigationTitle("Invoice Settings")
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
        savedBanner = "Invoice settings saved"
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
