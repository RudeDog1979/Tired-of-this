//
//  InvoiceDesignerHubView.swift
//  BuxMuse
//
//  The Invoice Designer & Engine Hub — split-panel workspace.
//  iPhone: segmented controls + scrollable panel + live canvas.
//  iPad: fixed 35% control panel + 65% live A4 preview.
//  iOS 26 Liquid Glass where available, ultraThinMaterial fallback for iOS 18.
//

import SwiftUI

// MARK: - Designer Tab

enum DesignerTab: String, CaseIterable {
    case invoice  = "Invoice"
    case branding = "Branding"
    case tax      = "Tax & Rates"
    case payment  = "Payment"
}

// MARK: - Main Designer Hub View

struct InvoiceDesignerHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var settingsStore = SettingsStore.shared

    @ObservedObject var engine: InvoiceDesignerEngine

    @Binding var selectedClientId: UUID
    @Binding var invoiceNumber: String
    @Binding var issueDate: Date
    @Binding var dueDate: Date
    @Binding var status: InvoiceStatus
    @Binding var notes: String
    @Binding var lineItems: [StudioInvoiceLineItem]

    let currencyCode: String
    let initialTab: DesignerTab
    let canSave: Bool
    var navigationTitle: String = "Invoice Designer"
    let onSave: () -> Void

    @State private var selectedTab: DesignerTab = .invoice
    @State private var showNotesEditor  = false
    @State private var showAddItemSheet = false
    @State private var showAddClientHint = false
    @State private var savedBanner: String?

    @State private var showAddRateSheet = false
    @State private var newItemDesc = ""
    @State private var newItemQty = "1.0"
    @State private var newItemPrice = ""

    private var client: StudioClient? {
        store.clients.first { $0.id == selectedClientId }
    }

    private var draftInvoice: StudioInvoice {
        StudioInvoice(
            clientId: selectedClientId,
            invoiceNumber: invoiceNumber,
            issueDate: issueDate,
            dueDate: dueDate,
            status: status,
            currencyCode: currencyCode,
            lineItems: lineItems,
            subtotal: engine.totalsDisplay.subtotal,
            taxAmount: engine.totalsDisplay.taxLines.reduce(0) { $0 + $1.amount },
            total: engine.totalsDisplay.grandTotal,
            vatRate: engine.taxConfig.rates.first?.percentage,
            taxLabel: engine.taxConfig.localizedLabel,
            notes: notes
        )
    }

    private var renderContext: InvoiceRenderContext {
        let currency = appSettingsManager.selectedCurrency.id
        let formatter = NumberFormatter()
        formatter.numberStyle           = .currency
        formatter.currencyCode          = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return engine.buildRenderContext(
            invoice: draftInvoice,
            client: client,
            profile: store.profile,
            settings: store.invoiceSettings,
            taxProfile: store.taxProfile,
            currencyCode: currency,
            autoDetectBankType: settingsStore.autoDetectInvoiceBankAccountType,
            bankTypeOverride: settingsStore.invoiceBankAccountTypeOverride
        )
    }

    private var resolvedBankType: BankAccountType {
        InvoicePartyEngine.resolveBankAccountType(
            countryCode: appSettingsManager.selectedCountry.id,
            paymentConfig: engine.paymentConfig,
            autoDetect: settingsStore.autoDetectInvoiceBankAccountType,
            manualOverride: settingsStore.invoiceBankAccountTypeOverride
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    ipadLayout
                } else {
                    iphoneLayout
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showNotesEditor) { notesEditorSheet.buxThemedSheetContent() }
            .sheet(isPresented: $showAddRateSheet) { addRateSheet.buxThemedSheetContent() }
            .sheet(isPresented: $showAddItemSheet) { addLineItemSheet.buxThemedSheetContent() }
        }
        .tint(themeManager.current.accentColor)
        .onAppear {
            selectedTab = initialTab
            engine.totalsDisplay = InvoiceDesignerEngine.computeTotals(
                items: lineItems,
                taxConfig: engine.taxConfig,
                currencyCode: currencyCode
            )
        }
        .onChange(of: lineItems) { _, items in
            engine.updateLineItems(items)
        }
    }

    // MARK: - Layouts

    private var ipadLayout: some View {
        HStack(spacing: 0) {
            // Left: Control Panel
            ScrollView(showsIndicators: false) {
                controlPanel
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .frame(width: 320)
            .background(.ultraThinMaterial)

            Divider()

            // Right: Live Preview Canvas
            ZStack {
                (colorScheme == .dark
                    ? Color(red: 18/255, green: 20/255, blue: 26/255)
                    : Color(red: 240/255, green: 241/255, blue: 244/255))
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    previewLabel
                    InvoicePreviewCanvas(context: renderContext)
                        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 8)
                    actionButtons
                        .padding(.horizontal, 32)
                }
                .padding(.vertical, 20)
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var iphoneLayout: some View {
        VStack(spacing: 0) {
            // Preview Canvas (top ~43% of screen)
            ZStack {
                (colorScheme == .dark
                    ? Color(red: 18/255, green: 20/255, blue: 26/255)
                    : Color(red: 240/255, green: 241/255, blue: 244/255))

                VStack(spacing: 8) {
                    previewLabel
                    InvoicePreviewCanvas(context: renderContext)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                }
                .padding(.vertical, 12)
            }
            .frame(height: 280)

            // Tab selector
            Picker("Section", selection: $selectedTab) {
                ForEach(DesignerTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            // Scrollable control panel
            ScrollView(showsIndicators: false) {
                controlPanel
                    .padding(.bottom, 100)
            }

            // Sticky action bar
            actionBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Control Panel

    @ViewBuilder
    private var controlPanel: some View {
        switch selectedTab {
        case .invoice:  invoiceControls
        case .branding: brandingControls
        case .tax:      taxControls
        case .payment:  paymentControls
        }
    }

    // MARK: Invoice Controls (client, items, metadata)

    private var invoiceControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            designerSection("Client") {
                if store.clients.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a client in Studio → Clients before sending this invoice.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Picker("Client", selection: $selectedClientId) {
                        ForEach(store.clients) { client in
                            Text(client.name).tag(client.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            designerSection("Invoice Details") {
                VStack(spacing: 10) {
                    TextField("Invoice number", text: $invoiceNumber)
                        .padding(10)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-number pattern")
                                .font(.system(size: 10, weight: .bold))
                                .buxLabelSecondary()
                            Text(store.invoiceSettings.numberPattern)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                        Spacer()
                        BuxActionButton(
                            title: "Next #",
                            systemImage: "number",
                            role: .secondary,
                            accent: themeManager.current.accentColor,
                            size: .compact,
                            action: { invoiceNumber = store.nextInvoiceNumber() }
                        )
                    }
                    .padding(10)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Text("Customize prefix & pattern in Studio → Invoices → Settings. You can always type your own number above.")
                        .font(.system(size: 10))
                        .buxLabelSecondary()

                    DatePicker("Issue date", selection: $issueDate, displayedComponents: .date)
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    Picker("Status", selection: $status) {
                        ForEach(InvoiceStatus.allCases) { st in
                            Text(st.rawValue).tag(st)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            designerSection("Line Items") {
                VStack(spacing: 8) {
                    if lineItems.isEmpty {
                        Text("Add at least one line item to save this invoice.")
                            .font(.system(size: 11))
                            .buxLabelSecondary()
                    }
                    ForEach(lineItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.description)
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Qty \(String(format: "%.1f", item.quantity)) · \(formatCurrency(item.unitPrice))")
                                    .font(.system(size: 10))
                                    .buxLabelSecondary()
                            }
                            Spacer()
                            Text(formatCurrency(item.total))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .padding(10)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                if let idx = lineItems.firstIndex(where: { $0.id == item.id }) {
                                    lineItems.remove(at: idx)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(BuxSwipeActionTint.delete)
                        }
                    }

                    BuxActionButton(
                        title: "Add line item",
                        systemImage: "plus.circle.fill",
                        role: .secondary,
                        accent: themeManager.current.accentColor,
                        expands: true,
                        size: .regular,
                        action: { showAddItemSheet = true }
                    )
                }
            }

            designerSection("Totals Preview") {
                VStack(spacing: 6) {
                    totalPreviewRow("Subtotal", engine.totalsDisplay.subtotal)
                    ForEach(engine.totalsDisplay.taxLines) { line in
                        totalPreviewRow(line.label, line.amount)
                    }
                    Divider()
                    totalPreviewRow("Grand total", engine.totalsDisplay.grandTotal, bold: true)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func totalPreviewRow(_ label: String, _ amount: Decimal, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: bold ? 13 : 12, weight: bold ? .bold : .regular))
            Spacer()
            Text(formatCurrency(amount))
                .font(.system(size: bold ? 14 : 12, weight: bold ? .bold : .semibold, design: .rounded))
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currencyCode) \(amount)"
    }

    // MARK: Branding Controls

    private var brandingControls: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Template Style Picker
            designerSection("Template Style") {
                HStack(spacing: 10) {
                    ForEach(InvoiceTemplateStyle.allCases) { style in
                        TemplateStyleCard(
                            style: style,
                            isSelected: engine.templateConfig.style == style,
                            accentColor: themeManager.current.accentColor
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                engine.templateConfig.style = style
                            }
                        }
                    }
                }
            }

            // Primary Color
            designerSection("Brand Color") {
                ColorSwatchRow(
                    presets: InvoiceColorPresets.primary,
                    selectedHex: engine.templateConfig.primaryColorHex,
                    onSelectHex: { engine.templateConfig.primaryColorHex = $0 },
                    onCustomColor: { engine.templateConfig.primaryColorHex = UIColor($0).hexString }
                )
            }

            // Secondary Color
            designerSection("Accent Color") {
                ColorSwatchRow(
                    presets: InvoiceColorPresets.secondary,
                    selectedHex: engine.templateConfig.secondaryColorHex,
                    onSelectHex: { engine.templateConfig.secondaryColorHex = $0 },
                    onCustomColor: { engine.templateConfig.secondaryColorHex = UIColor($0).hexString }
                )
            }

            // Typography
            designerSection("Typography") {
                threeWayPicker(
                    options: InvoiceTypographyStyle.allCases,
                    selected: engine.templateConfig.typography,
                    label: \.rawValue,
                    onSelect: { engine.templateConfig.typography = $0 }
                )
            }

            // Corner Style
            designerSection("Corners") {
                threeWayPicker(
                    options: InvoiceCornerStyle.allCases,
                    selected: engine.templateConfig.cornerStyle,
                    label: \.rawValue,
                    onSelect: { engine.templateConfig.cornerStyle = $0 }
                )
            }

            // Density
            designerSection("Density") {
                threeWayPicker(
                    options: InvoiceDensity.allCases,
                    selected: engine.templateConfig.density,
                    label: \.rawValue,
                    onSelect: { engine.templateConfig.density = $0 }
                )
            }

            // Logo Position
            designerSection("Logo Position") {
                threeWayPicker(
                    options: InvoiceLogoPosition.allCases,
                    selected: engine.templateConfig.logoPosition,
                    label: \.rawValue,
                    onSelect: { engine.templateConfig.logoPosition = $0 }
                )
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Tax Controls

    private var taxControls: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Tax Mode
            designerSection("Tax Mode") {
                VStack(spacing: 8) {
                    ForEach(InvoiceTaxMode.allCases) { mode in
                        taxModeRow(mode)
                    }
                }
            }

            // Tax Rates
            designerSection("Tax Rates") {
                VStack(spacing: 6) {
                    ForEach(Array(engine.taxConfig.rates.enumerated()), id: \.element.id) { idx, rate in
                        taxRateRow(rate: rate, index: idx)
                    }
                    BuxActionButton(
                        title: "Add Tax Rate",
                        systemImage: "plus.circle.fill",
                        role: .secondary,
                        accent: themeManager.current.accentColor,
                        expands: true,
                        size: .regular,
                        action: { showAddRateSheet = true }
                    )
                }
            }

            designerSection("Invoice Notes") {
                Button(action: { showNotesEditor = true }) {
                    HStack {
                        Text(notes.isEmpty ? "Tap to add notes & payment terms…" : notes)
                            .font(.system(size: 12))
                            .foregroundColor(notes.isEmpty ? .gray : Color(UIColor.label))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .buxLabelSecondary()
                    }
                    .padding(10)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(BuxPressFeedbackStyle())
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Payment Controls

    private var paymentControls: some View {
        VStack(alignment: .leading, spacing: 20) {

            // Bank Block
            designerSection("Bank Transfer") {
                VStack(spacing: 10) {
                    Toggle("Show bank details", isOn: $engine.paymentConfig.showBankBlock)
                        .tint(themeManager.current.accentColor)

                    if engine.paymentConfig.showBankBlock {
                        Picker("Account type", selection: bankTypeBinding) {
                            ForEach(BankAccountType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        paymentField("Bank Name", text: $engine.paymentConfig.bankName)
                        bankTypeFields
                    }
                }
            }

            // QR Code Block
            designerSection("QR Code") {
                VStack(spacing: 10) {
                    Toggle("Show QR code block", isOn: $engine.paymentConfig.showQRBlock)
                        .tint(themeManager.current.accentColor)

                    if engine.paymentConfig.showQRBlock {
                        paymentField("QR Payload (URL, IBAN, etc.)", text: $engine.paymentConfig.qrPayload)
                        if !engine.paymentConfig.qrPayload.isEmpty,
                           let qr = InvoiceDesignerEngine.generateQRImage(from: engine.paymentConfig.qrPayload, size: 72) {
                            HStack {
                                Text("Preview:")
                                    .font(.system(size: 11))
                                    .buxLabelSecondary()
                                Image(uiImage: qr)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 56, height: 56)
                            }
                        }
                    }
                }
            }

            // Payment Link
            designerSection("Payment Link") {
                VStack(spacing: 10) {
                    Toggle("Show payment link", isOn: $engine.paymentConfig.showPaymentLink)
                        .tint(themeManager.current.accentColor)
                    if engine.paymentConfig.showPaymentLink {
                        paymentField("URL (e.g. https://pay.stripe.com/…)", text: $engine.paymentConfig.paymentLinkURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Shared Sub-Views

    @ViewBuilder
    private func designerSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeManager.current.accentColor)
                .tracking(0.8)
            content()
        }
    }

    @ViewBuilder
    private func threeWayPicker<T: Equatable & Hashable>(
        options: [T],
        selected: T,
        label: KeyPath<T, String>,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button(action: { withAnimation(.spring(response: 0.25)) { onSelect(option) } }) {
                    Text(option[keyPath: label])
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : Color(UIColor.label))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? themeManager.current.accentColor : Color(UIColor.tertiarySystemFill))
                        .clipShape(Capsule())
                }
                .buttonStyle(BuxChipButtonStyle())
            }
        }
    }

    private func taxModeRow(_ mode: InvoiceTaxMode) -> some View {
        let isSelected = engine.taxConfig.mode == mode
        return Button(action: {
            withAnimation(.spring(response: 0.25)) {
                engine.taxConfig.mode = mode
                engine.recomputeTotals()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? themeManager.current.accentColor : .gray)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(Color(UIColor.label))
                    Text(mode == .exclusive ? "Tax added on top of line item prices" : "Tax extracted from line item prices")
                        .font(.system(size: 10))
                        .buxLabelSecondary()
                }
                Spacer()
            }
            .padding(10)
            .background(isSelected ? themeManager.current.accentColor.opacity(0.08) : Color(UIColor.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(BuxPressFeedbackStyle())
    }

    private func taxRateRow(rate: InvoiceTaxRate, index: Int) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(rate.label) — \(NSDecimalNumber(decimal: rate.percentage).stringValue)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(UIColor.label))
                if rate.isCompounding {
                    Text("Compounding")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(themeManager.current.accentColor)
                }
            }
            Spacer()
            Button(action: {
                withAnimation {
                    engine.taxConfig.rates.remove(at: index)
                    engine.recomputeTotals()
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.system(size: 18))
            }
        }
        .padding(10)
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var bankTypeBinding: Binding<BankAccountType> {
        Binding(
            get: { engine.paymentConfig.accountType ?? resolvedBankType },
            set: { engine.paymentConfig.accountType = $0 }
        )
    }

    private var activeBankType: BankAccountType {
        engine.paymentConfig.accountType ?? resolvedBankType
    }

    @ViewBuilder
    private var bankTypeFields: some View {
        switch activeBankType {
        case .iban:
            paymentField("IBAN", text: $engine.paymentConfig.iban)
            paymentField("BIC / SWIFT", text: $engine.paymentConfig.bic)
        case .uk:
            paymentField("Sort Code", text: $engine.paymentConfig.sortCode)
            paymentField("Account Number", text: $engine.paymentConfig.accountNumber)
            paymentField("IBAN (optional)", text: $engine.paymentConfig.iban)
        case .us:
            paymentField("Routing Number", text: $engine.paymentConfig.routingNumber)
            paymentField("Account Number", text: $engine.paymentConfig.accountNumber)
        case .canada:
            paymentField("Transit Number", text: $engine.paymentConfig.transitNumber)
            paymentField("Institution Number", text: $engine.paymentConfig.institutionNumber)
            paymentField("Account Number", text: $engine.paymentConfig.accountNumber)
        case .australia:
            paymentField("BSB", text: $engine.paymentConfig.bsb)
            paymentField("Account Number", text: $engine.paymentConfig.accountNumber)
        case .generic:
            paymentField("Account Number", text: $engine.paymentConfig.accountNumber)
            paymentField("IBAN (optional)", text: $engine.paymentConfig.iban)
            paymentField("BIC / SWIFT (optional)", text: $engine.paymentConfig.bic)
        }
    }

    private func paymentField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 12))
            .padding(10)
            .background(Color(UIColor.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Preview Label

    private var previewLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(themeManager.current.accentColor)
                .frame(width: 6, height: 6)
            Text("Live Preview · \(engine.templateConfig.style.rawValue)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeManager.current.accentColor)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            BuxActionButton(
                title: "Save Default",
                systemImage: "star.fill",
                role: .secondary,
                accent: themeManager.current.accentColor,
                expands: true,
                action: saveAsDefault
            )
            BuxActionButton(
                title: "Save Invoice",
                systemImage: "checkmark.seal.fill",
                role: .primary,
                accent: themeManager.current.accentColor,
                expands: true,
                isEnabled: canSave,
                action: saveInvoice
            )
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            BuxActionButton(
                title: "Save Default",
                systemImage: "star.fill",
                role: .secondary,
                accent: themeManager.current.accentColor,
                expands: true,
                action: saveAsDefault
            )
            BuxActionButton(
                title: "Save Invoice",
                systemImage: "checkmark.seal.fill",
                role: .primary,
                accent: themeManager.current.accentColor,
                expands: true,
                isEnabled: canSave,
                action: saveInvoice
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background {
            ZStack {
                themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.07 : 0.05)
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Sheets

    private var notesEditorSheet: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                TextEditor(text: $notes)
                    .font(.system(size: 14))
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
            }
            .navigationTitle("Notes & Terms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarDoneButton { showNotesEditor = false }
                }
            }
        }
    }

    private var addLineItemSheet: some View {
        NavigationStack {
            Form {
                TextField("Description", text: $newItemDesc)
                TextField("Quantity", text: $newItemQty)
                    .keyboardType(.decimalPad)
                TextField("Unit price", text: $newItemPrice)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Line Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { showAddItemSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: "Add",
                        isEnabled: !newItemDesc.isEmpty && !newItemPrice.isEmpty
                    ) {
                        let qty = Double(newItemQty) ?? 1
                        let price = Decimal(string: newItemPrice) ?? 0
                        lineItems.append(
                            StudioInvoiceLineItem(description: newItemDesc, quantity: qty, unitPrice: price)
                        )
                        showAddItemSheet = false
                        newItemDesc = ""
                        newItemQty = "1.0"
                        newItemPrice = ""
                    }
                }
            }
        }
    }

    private var addRateSheet: some View {
        AddTaxRateSheet { newRate in
            withAnimation {
                engine.taxConfig.rates.append(newRate)
                engine.recomputeTotals()
            }
            showAddRateSheet = false
        }
        .environmentObject(themeManager)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            BuxToolbarCancelButton { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            BuxToolbarSaveButton(isDirty: canSave) {
                saveInvoice()
                BuxSaveFeedback.success()
            }
        }
    }

    // MARK: - Actions

    private func saveInvoice() {
        guard canSave else { return }
        onSave()
    }

    private func saveAsDefault() {
        var settings = store.invoiceSettings
        settings.defaultTemplateConfig = engine.templateConfig
        settings.defaultPaymentConfig  = engine.paymentConfig
        store.updateInvoiceSettings(settings)

        withAnimation {
            savedBanner = "Design saved as default"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { savedBanner = nil }
        }
    }
}

// MARK: - A4 Preview Canvas

struct InvoicePreviewCanvas: View {
    let context: InvoiceRenderContext

    private let pageWidth:  CGFloat = 612
    private let pageHeight: CGFloat = 792

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / pageWidth
            let scaledHeight = pageHeight * scale

            InvoiceTemplateDispatcher.view(for: context)
                .frame(width: pageWidth, height: pageHeight)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4 / scale))
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: scaledHeight, alignment: .topLeading)
                .clipped()
        }
        .aspectRatio(pageWidth / pageHeight, contentMode: .fit)
    }
}

// MARK: - Template Style Card

private struct TemplateStyleCard: View {
    let style: InvoiceTemplateStyle
    let isSelected: Bool
    let accentColor: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
            // Abstract mini-thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? accentColor.opacity(0.10) : Color(UIColor.tertiarySystemFill))
                    .frame(height: 60)
                templateThumbnail
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )

            Text(style.rawValue)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? accentColor : Color(UIColor.label))

            Text(style.tagline)
                .font(.system(size: 8))
                .buxLabelSecondary()
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(BuxChipButtonStyle())
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    @ViewBuilder
    private var templateThumbnail: some View {
        switch style {
        case .modern:
            VStack(spacing: 3) {
                Rectangle().fill(accentColor).frame(height: 14) // header band
                HStack(spacing: 3) {
                    Rectangle().fill(Color.gray.opacity(0.18)).frame(height: 6)
                    Rectangle().fill(Color.gray.opacity(0.10)).frame(height: 6)
                }
                .padding(.horizontal, 8)
                Rectangle().fill(Color.gray.opacity(0.13)).frame(height: 4).padding(.horizontal, 8)
                Rectangle().fill(Color.gray.opacity(0.10)).frame(height: 4).padding(.horizontal, 8)
                Rectangle().fill(accentColor.opacity(0.35)).frame(height: 6).padding(.horizontal, 8)
            }
            .padding(.vertical, 6)

        case .minimalist:
            VStack(alignment: .leading, spacing: 4) {
                Rectangle().fill(Color.gray.opacity(0.35)).frame(width: 40, height: 4)
                Rectangle().fill(Color.gray.opacity(0.12)).frame(height: 0.5)
                Rectangle().fill(Color.gray.opacity(0.15)).frame(width: 60, height: 3)
                Rectangle().fill(Color.gray.opacity(0.10)).frame(height: 3)
                Rectangle().fill(Color.gray.opacity(0.10)).frame(height: 3)
                Rectangle().fill(Color.gray.opacity(0.12)).frame(height: 0.5)
                Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 50, height: 4).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

        case .executive:
            VStack(spacing: 2) {
                // Full-width banner
                LinearGradient(colors: [accentColor, accentColor.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 18)
                // Two-column area
                HStack(spacing: 2) {
                    Rectangle().fill(accentColor.opacity(0.06)).frame(maxWidth: .infinity, maxHeight: .infinity)
                    Rectangle().fill(accentColor.opacity(0.03)).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 12)
                Rectangle().fill(Color.gray.opacity(0.12)).frame(height: 3).padding(.horizontal, 6)
                Rectangle().fill(accentColor.opacity(0.3)).frame(height: 7).padding(.horizontal, 0)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Color Swatch Row

private struct ColorSwatchRow: View {
    let presets: [(name: String, hex: String)]
    let selectedHex: String
    let onSelectHex: (String) -> Void
    let onCustomColor: (Color) -> Void

    @State private var customColor: Color = .purple
    @State private var showColorPicker = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.hex) { preset in
                let isSelected = selectedHex.uppercased() == preset.hex.uppercased()
                Button(action: { onSelectHex(preset.hex) }) {
                    Circle()
                        .fill(Color(hex: preset.hex))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                        )
                        .overlay(
                            Circle().stroke(Color(hex: preset.hex).opacity(0.6), lineWidth: isSelected ? 3 : 1)
                        )
                        .shadow(color: Color(hex: preset.hex).opacity(0.4), radius: isSelected ? 4 : 0)
                        .scaleEffect(isSelected ? 1.18 : 1.0)
                }
                .buttonStyle(BuxChipButtonStyle())
                .animation(.spring(response: 0.25), value: isSelected)
            }
            // Custom color picker
            ColorPicker("", selection: $customColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 26, height: 26)
                .onChange(of: customColor) { _, newColor in
                    onCustomColor(newColor)
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Tax Rate Sheet

private struct AddTaxRateSheet: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let onAdd: (InvoiceTaxRate) -> Void

    @State private var label       = ""
    @State private var percentage  = ""
    @State private var compounding = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                Form {
                    Section("Rate Details") {
                        TextField("Label (e.g. VAT, GST, ITBIS)", text: $label)
                        HStack {
                            TextField("Rate %", text: $percentage)
                                .keyboardType(.decimalPad)
                            Text("%")
                                .buxLabelSecondary()
                        }
                    }
                    Section("Options") {
                        Toggle("Compounding (stacks on previous rate)", isOn: $compounding)
                            .tint(themeManager.current.accentColor)
                        Text("Compounding rates apply to the running total including previous taxes.")
                            .font(.system(size: 11))
                            .buxLabelSecondary()
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Tax Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: "Add",
                        isEnabled: !label.isEmpty && (Decimal(string: percentage) ?? 0) > 0
                    ) {
                        guard let pct = Decimal(string: percentage), pct > 0, !label.isEmpty else { return }
                        onAdd(InvoiceTaxRate(label: label, percentage: pct, isCompounding: compounding))
                    }
                }
            }
        }
    }
}
