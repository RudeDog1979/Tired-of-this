//
//  StudioInvoiceViews.swift
//  BuxMuse
//
//  Invoicing — ledger, designer-first composer, PDF export.
//

import SwiftUI
import PDFKit

struct StudioInvoicesListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: StudioStore

    @State private var showEditor = false
    @State private var searchText = ""
    @State private var isInvoiceSearchPresented = false
    @State private var statusFilter: InvoiceStatus?

    private var filteredInvoices: [StudioInvoice] {
        store.invoices.filter { inv in
            let matchesStatus = statusFilter == nil || inv.status == statusFilter
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return matchesStatus }
            let clientName = store.clients.first { $0.id == inv.clientId }?.name.lowercased() ?? ""
            let matchesSearch = inv.invoiceNumber.lowercased().contains(query) || clientName.contains(query)
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        StudioThemedListBackdrop {
            if store.invoices.isEmpty {
                emptyState
            } else {
                invoiceList
            }
        }
        .navigationTitle("Invoices")
        .navigationBarTitleDisplayMode(.large)
        .buxRootNavigationChrome()
        .toolbar { invoiceToolbar }
        .modifier(BuxDrawerSearchModifier(
            searchText: $searchText,
            prompt: "Search invoices or clients",
            isPresented: $isInvoiceSearchPresented
        ))
        .onAppear {
            isInvoiceSearchPresented = true
        }
        .onDisappear {
            isInvoiceSearchPresented = false
        }
        .fullScreenCover(isPresented: $showEditor) {
            StudioInvoiceEditorView(invoiceToEdit: nil)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
        }
    }

    private var invoiceList: some View {
        List {
            Section {
                invoiceFilterBar
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(filteredInvoices) { invoice in
                let client = store.clients.first { $0.id == invoice.clientId }

                NavigationLink(
                    destination: StudioInvoiceDetailView(invoice: invoice)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                ) {
                    invoiceRowCard(invoice: invoice, client: client)
                }
                .studioThemedListRowChrome()
            }
            .onDelete(perform: deleteInvoice)
        }
        .contentMargins(.top, BuxLayout.invoicesNavChromeScrollInset, for: .scrollContent)
        .studioThemedListRows()
    }

    @ToolbarContentBuilder
    private var invoiceToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            NavigationLink {
                StudioInvoiceSettingsView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environment(\.studioEnhancedTint, true)
            } label: {
                BuxToolbarIcon(systemName: "gearshape.fill")
            }

            Menu {
                Button("All") { statusFilter = nil }
                ForEach(InvoiceStatus.allCases) { status in
                    Button(status.rawValue) { statusFilter = status }
                }
            } label: {
                BuxToolbarIcon(systemName: "line.3.horizontal.decrease.circle")
            }

            BuxToolbarButton(
                systemName: "plus",
                accessibilityLabel: "Create invoice",
                action: { showEditor = true }
            )
        }
    }
    
    private func invoiceRowCard(invoice: StudioInvoice, client: StudioClient?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(invoice.invoiceNumber)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Text(client?.name ?? "Unknown Client")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(appSettingsManager.format(invoice.total))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Text(invoice.status.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(statusColor(invoice.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(invoice.status).opacity(colorScheme == .dark ? 0.22 : 0.14))
                    .clipShape(Capsule())
            }
        }
        .studioThemedListRowCard()
    }

    private var invoiceFilterBar: some View {
        HStack {
            if let statusFilter {
                Text(statusFilter.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.current.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            Spacer()
            Text("\(filteredInvoices.count) invoice(s)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 32))
                .buxLabelSecondary()
            
            Text("No Invoices logged yet")
                .font(.system(size: 14, weight: .semibold))
                .buxLabelSecondary()
            
            BuxButton(
                title: "Create Invoice",
                systemImage: "plus.rectangle.fill.on.folder.fill",
                role: .primary,
                size: .regular
            ) {
                showEditor = true
            }
        }
    }
    
    private func deleteInvoice(at offsets: IndexSet) {
        let ids = offsets.map { filteredInvoices[$0].id }
        ids.forEach { store.deleteInvoice(id: $0) }
    }
    
    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .paid: return .green
        case .sent: return themeManager.current.accentColor
        case .overdue: return .red
        case .cancelled: return themeManager.labelTertiary(for: colorScheme)
        case .draft: return themeManager.current.accentColor.opacity(0.85)
        }
    }
}

// MARK: - Invoice Composer (designer-first)

struct StudioInvoiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    var invoiceToEdit: StudioInvoice?

    @State private var selectedClientId: UUID = UUID()
    @State private var invoiceNumber = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingTimeInterval(14 * 24 * 3600)
    @State private var status: InvoiceStatus = .draft
    @State private var notes = ""
    @State private var lineItems: [StudioInvoiceLineItem] = []

    @StateObject private var designerEngine = InvoiceDesignerEngine()

    private var hasValidClient: Bool {
        store.clients.contains { $0.id == selectedClientId }
    }

    private var canSave: Bool {
        !invoiceNumber.isEmpty && !lineItems.isEmpty && hasValidClient
    }

    private var initialDesignerTab: DesignerTab {
        invoiceToEdit?.designerSnapshot != nil ? .branding : .invoice
    }

    var body: some View {
        InvoiceDesignerHubView(
            engine: designerEngine,
            selectedClientId: $selectedClientId,
            invoiceNumber: $invoiceNumber,
            issueDate: $issueDate,
            dueDate: $dueDate,
            status: $status,
            notes: $notes,
            lineItems: $lineItems,
            currencyCode: appSettingsManager.selectedCurrency.id,
            initialTab: initialDesignerTab,
            canSave: canSave,
            navigationTitle: invoiceToEdit == nil ? "New Invoice" : "Edit Invoice",
            onSave: {
                saveInvoice()
                dismiss()
            }
        )
        .environmentObject(themeManager)
        .environmentObject(appSettingsManager)
        .environmentObject(store)
        .onAppear {
            setupInitialFields()
            designerEngine.loadDefaults(
                settings: store.invoiceSettings,
                taxProfile: store.taxProfile,
                existingSnapshot: invoiceToEdit?.designerSnapshot,
                lineItems: lineItems
            )
        }
    }

    private func setupInitialFields() {
        if let inv = invoiceToEdit {
            selectedClientId = inv.clientId
            invoiceNumber = inv.invoiceNumber
            issueDate = inv.issueDate
            dueDate = inv.dueDate
            status = inv.status
            notes = inv.notes
            lineItems = inv.lineItems
        } else {
            selectedClientId = store.clients.first?.id ?? UUID()
            invoiceNumber = store.nextInvoiceNumber()
        }
    }

    private func saveInvoice() {
        let client = store.clients.first { $0.id == selectedClientId }
        let snapshot = designerEngine.buildSnapshot(
            issuerParty: store.profile.resolvedPartyDetails(),
            recipientParty: client?.resolvedPartyDetails()
        )
        let totals = InvoiceDesignerEngine.computeTotals(
            items: lineItems,
            taxConfig: snapshot.taxConfig,
            currencyCode: appSettingsManager.selectedCurrency.id
        )
        let taxTotal = totals.taxLines.reduce(Decimal(0)) { $0 + $1.amount }
        let primaryRate = snapshot.taxConfig.rates.first?.percentage
        let label = snapshot.taxConfig.localizedLabel

        let inv = StudioInvoice(
            id: invoiceToEdit?.id ?? UUID(),
            clientId: selectedClientId,
            invoiceNumber: invoiceNumber,
            issueDate: issueDate,
            dueDate: dueDate,
            status: status,
            currencyCode: appSettingsManager.selectedCurrency.id,
            lineItems: lineItems,
            subtotal: totals.subtotal,
            taxAmount: taxTotal,
            total: totals.grandTotal,
            vatRate: primaryRate,
            taxLabel: label,
            notes: notes,
            designerSnapshot: snapshot
        )

        if store.invoices.contains(where: { $0.id == inv.id }) {
            store.updateInvoice(inv)
        } else {
            store.addInvoice(inv)
        }
    }
}

// MARK: - Invoice Detail View & Local Preview

struct StudioInvoiceDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: StudioStore
    @State private var showEdit = false
    @State private var pdfData: Data? = nil
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    
    var invoice: StudioInvoice
    
    var body: some View {
        let client = store.clients.first { $0.id == invoice.clientId }
        let intelligence = StudioInvoiceEngine.analyzeInvoice(invoice: invoice, client: client, profile: store.profile, historicalInvoices: store.invoices)
        
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    if let warn = intelligence.rateWarning {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(warn)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    if intelligence.latePaymentRisk > 0.5 {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.red)
                            Text("Late Risk Detected. Awaiting payment speed estimated at \(intelligence.paymentPredictionDays) days.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(invoice.invoiceNumber)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            
                            Spacer()
                            
                            Text(invoice.status.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(statusColor(invoice.status))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(statusColor(invoice.status).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CLIENT")
                                    .font(.system(size: 10, weight: .semibold))
                                    .buxLabelSecondary()
                                Text(client?.name ?? "Unknown Client")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("TOTAL DUE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .buxLabelSecondary()
                                Text(appSettingsManager.format(invoice.total))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                        }

                        if let style = invoice.designerSnapshot?.templateConfig.style.rawValue {
                            Text("Template: \(style)")
                                .font(.system(size: 11, weight: .medium))
                                .buxLabelSecondary()
                        }
                    }
                    .padding(BuxLayout.section)
                    .studioThemedCardChrome(cornerRadius: 24)
                    
                    BuxActionButton(
                        title: "Export & Share PDF",
                        systemImage: invoice.designerSnapshot != nil
                            ? "paintbrush.pointed.fill"
                            : "square.and.arrow.up.fill",
                        role: .primary,
                        accent: themeManager.current.accentColor,
                        expands: true,
                        action: exportPDF
                    )

                    HStack(spacing: 12) {
                        BuxActionButton(
                            title: "Mark Paid",
                            systemImage: "checkmark.circle.fill",
                            role: .tinted(.green),
                            accent: themeManager.current.accentColor,
                            expands: true,
                            action: { updateStatus(.paid) }
                        )
                        BuxActionButton(
                            title: "Mark Sent",
                            systemImage: "paperplane.fill",
                            role: .tinted(.blue),
                            accent: themeManager.current.accentColor,
                            expands: true,
                            action: { updateStatus(.sent) }
                        )
                    }
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .navigationTitle(invoice.invoiceNumber)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEdit = true }
                    .buxToolbarTextActionStyle(accent: themeManager.current.accentColor)
            }
        }
        .fullScreenCover(isPresented: $showEdit) {
            StudioInvoiceEditorView(invoiceToEdit: invoice)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
        }
    }

    private func exportPDF() {
        let client = store.clients.first { $0.id == invoice.clientId }
        let data: Data
        if let snapshot = invoice.designerSnapshot {
            let settingsStore = SettingsStore.shared
            let ctx = InvoiceDesignerEngine.buildRenderContext(
                invoice: invoice,
                client: client,
                profile: store.profile,
                settings: store.invoiceSettings,
                snapshot: snapshot,
                taxProfile: store.taxProfile,
                currencyCode: invoice.currencyCode,
                autoDetectBankType: settingsStore.autoDetectInvoiceBankAccountType,
                bankTypeOverride: settingsStore.invoiceBankAccountTypeOverride
            )
            data = InvoiceDesignerEngine.generatePDF(context: ctx)
        } else {
            data = StudioInvoicePDFRenderer.generatePDF(
                invoice: invoice,
                client: client,
                profile: store.profile,
                settings: store.invoiceSettings,
                taxProfile: store.taxProfile,
                countryCode: appSettingsManager.selectedCountry.id
            )
        }

        pdfData = data
        let cleanNum = invoice.invoiceNumber.replacingOccurrences(of: "/", with: "_")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice_\(cleanNum).pdf")
        do {
            try data.write(to: tempURL)
            presentShareSheet(items: [tempURL])
        } catch {
            print("Error writing PDF to temporary directory: \(error)")
        }
    }
    
    private func updateStatus(_ st: InvoiceStatus) {
        var updated = invoice
        updated.status = st
        if st == .paid {
            updated.paymentDate = Date()
        }
        store.updateInvoice(updated)
        dismiss()
    }
    
    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .paid: return .green
        case .sent: return .blue
        case .overdue: return .red
        case .cancelled: return .gray
        case .draft: return .orange
        }
    }
}

// MARK: - UIKit Share Sheet Helper

extension View {
    func presentShareSheet(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootVC.present(activityVC, animated: true)
    }
}
