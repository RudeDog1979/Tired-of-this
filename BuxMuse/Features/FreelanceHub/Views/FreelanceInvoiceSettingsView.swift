//
//  FreelanceInvoiceSettingsView.swift
//  BuxMuse
//
//  Invoice numbering, templates, tax behavior, and bank details.
//

import SwiftUI

struct FreelanceInvoiceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: FreelanceStore

    @State private var prefix = "INV"
    @State private var pattern = "{PREFIX}-{YEAR}-{SEQ}"
    @State private var template: InvoiceTemplate = .professional
    @State private var taxBehavior: InvoiceTaxBehavior = .taxAdded
    @State private var logoPosition: InvoiceLogoPosition = .topLeft
    @State private var documentLabel = "Invoice"
    @State private var showTaxID = false
    @State private var showBankDetails = true
    @State private var bankDetails = ""
    @State private var defaultTaxRate = ""
    @State private var savedBanner: String?

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

            Form {
                Section("Numbering") {
                    TextField("Prefix", text: $prefix)
                    TextField("Pattern", text: $pattern)
                    Text("Use {PREFIX}, {YEAR}, {SEQ}")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text("Preview: \(previewNumber)")
                        .font(.system(size: 12, weight: .semibold))
                }

                Section("Design") {
                    Picker("Template", selection: $template) {
                        ForEach(InvoiceTemplate.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    Picker("Logo position", selection: $logoPosition) {
                        ForEach(InvoiceLogoPosition.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    TextField("Document label", text: $documentLabel)
                }

                Section("Tax on invoices") {
                    Picker("Tax behavior", selection: $taxBehavior) {
                        ForEach(InvoiceTaxBehavior.allCases) { b in
                            Text(b.rawValue).tag(b)
                        }
                    }
                    TextField("Default tax rate %", text: $defaultTaxRate)
                        .keyboardType(.decimalPad)
                    Toggle("Show tax ID on PDF", isOn: $showTaxID)
                }

                Section("Payment") {
                    Toggle("Show bank details", isOn: $showBankDetails)
                    TextField("Bank / payment details", text: $bankDetails, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let savedBanner {
                    Section {
                        Text(savedBanner)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Invoice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveSettings() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear { hydrate() }
    }

    private var previewNumber: String {
        var draft = FreelanceInvoiceSettings()
        draft.numberPrefix = prefix
        draft.numberPattern = pattern
        let year = Calendar.current.component(.year, from: Date())
        return draft.formatInvoiceNumber(sequence: 1, year: year)
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
        if let rate = s.defaultTaxRatePercent { defaultTaxRate = "\(rate)" }
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
        settings.defaultTaxRatePercent = Decimal(string: defaultTaxRate)
        store.updateInvoiceSettings(settings)
        savedBanner = "Invoice settings saved"
    }
}
