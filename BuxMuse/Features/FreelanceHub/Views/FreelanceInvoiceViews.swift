//
//  FreelanceInvoiceViews.swift
//  BuxMuse
//
//  Invoicing engine panels allowing interactive line-item edits and offline PDF compilations.
//

import SwiftUI
import PDFKit

struct FreelanceInvoicesListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    @State private var showEditor = false
    @State private var searchText = ""
    @State private var statusFilter: InvoiceStatus?

    private var filteredInvoices: [FreelanceInvoice] {
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
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if store.invoices.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    invoiceFilterBar
                    List {
                        ForEach(filteredInvoices) { invoice in
                        let client = store.clients.first { $0.id == invoice.clientId }
                        
                        NavigationLink(destination: FreelanceInvoiceDetailView(invoice: invoice).environmentObject(themeManager).environmentObject(appSettingsManager)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(invoice.invoiceNumber)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    
                                    Text(client?.name ?? "Unknown Client")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(appSettingsManager.format(invoice.total))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                    
                                    Text(invoice.status.rawValue)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(statusColor(invoice.status))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(statusColor(invoice.status).opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : Color.white)
                    }
                    .onDelete(perform: deleteInvoice)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Invoices Ledger")
        .searchable(text: $searchText, prompt: "Search invoices or clients")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("All") { statusFilter = nil }
                    ForEach(InvoiceStatus.allCases) { status in
                        Button(status.rawValue) { statusFilter = status }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showEditor = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            FreelanceInvoiceEditorView(invoiceToEdit: nil)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
        }
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
                .foregroundColor(.gray)
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No Invoices logged yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
            
            Button("Create Invoice") {
                showEditor = true
            }
            .buttonStyle(BuxMicroShrinkStyle())
        }
    }
    
    private func deleteInvoice(at offsets: IndexSet) {
        let ids = offsets.map { filteredInvoices[$0].id }
        ids.forEach { store.deleteInvoice(id: $0) }
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

// MARK: - Invoice Editor View

struct FreelanceInvoiceEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    
    var invoiceToEdit: FreelanceInvoice?
    
    // Editor fields
    @State private var selectedClientId: UUID = UUID()
    @State private var invoiceNumber = ""
    @State private var issueDate = Date()
    @State private var dueDate = Date().addingTimeInterval(14 * 24 * 3600)
    @State private var status: InvoiceStatus = .draft
    @State private var notes = ""
    @State private var vatRate = ""
    @State private var taxLabel = "Tax"
    @State private var lineItems: [FreelanceInvoiceLineItem] = []
    
    // New Item fields
    @State private var showAddItemSheet = false
    @State private var newItemDesc = ""
    @State private var newItemQty = "1.0"
    @State private var newItemPrice = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                Form {
                    Section("Metadata") {
                        Picker("Client", selection: $selectedClientId) {
                            if store.clients.isEmpty {
                                Text("Add Clients first").tag(UUID())
                            } else {
                                ForEach(store.clients) { client in
                                    Text(client.name).tag(client.id)
                                }
                            }
                        }
                        
                        TextField("Invoice Number", text: $invoiceNumber)
                        DatePicker("Issue Date", selection: $issueDate, displayedComponents: .date)
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        
                        Picker("Status", selection: $status) {
                            ForEach(InvoiceStatus.allCases) { st in
                                Text(st.rawValue).tag(st)
                            }
                        }
                    }
                    
                    Section("Line Items") {
                        ForEach(lineItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.description)
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Qty: \(String(format: "%.1f", item.quantity)) • Rate: \(appSettingsManager.format(item.unitPrice))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(appSettingsManager.format(item.total))
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .onDelete(perform: deleteLineItem)
                        
                        Button("Add Line Item") {
                            showAddItemSheet = true
                        }
                        .foregroundColor(themeManager.current.accentColor)
                    }
                    
                    Section("Tax Settings & Notes") {
                        Text(taxLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                        TextField("Tax Percentage (e.g. 20)", text: $vatRate)
                            .keyboardType(.decimalPad)
                        
                        TextField("Payment Terms & Bank Details", text: $notes)
                    }
                    
                    Section("Estimated Totals") {
                        let (sub, tax, grand) = calculatePreview()
                        HStack {
                            Text("Subtotal")
                            Spacer()
                            Text(appSettingsManager.format(sub))
                        }
                        HStack {
                            Text(taxLabel)
                            Spacer()
                            Text(appSettingsManager.format(tax))
                        }
                        HStack {
                            Text("Grand Total")
                                .fontWeight(.bold)
                            Spacer()
                            Text(appSettingsManager.format(grand))
                                .fontWeight(.bold)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(invoiceToEdit == nil ? "New Invoice" : "Edit Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveInvoice()
                        dismiss()
                    }
                    .disabled(invoiceNumber.isEmpty || lineItems.isEmpty)
                }
            }
            .sheet(isPresented: $showAddItemSheet) {
                addItemSheet
            }
            .onAppear {
                setupInitialFields()
            }
        }
    }
    
    // MARK: - Subviews & Sheets
    
    private var addItemSheet: some View {
        NavigationStack {
            Form {
                TextField("Description", text: $newItemDesc)
                TextField("Quantity", text: $newItemQty)
                    .keyboardType(.decimalPad)
                TextField("Unit Price / Hour rate", text: $newItemPrice)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showAddItemSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let qty = Double(newItemQty) ?? 1.0
                        let price = Decimal(string: newItemPrice) ?? 0
                        let item = FreelanceInvoiceLineItem(description: newItemDesc, quantity: qty, unitPrice: price)
                        lineItems.append(item)
                        showAddItemSheet = false
                        newItemDesc = ""
                        newItemQty = "1.0"
                        newItemPrice = ""
                    }
                    .disabled(newItemDesc.isEmpty || newItemPrice.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func setupInitialFields() {
        if let inv = invoiceToEdit {
            selectedClientId = inv.clientId
            invoiceNumber = inv.invoiceNumber
            issueDate = inv.issueDate
            dueDate = inv.dueDate
            status = inv.status
            notes = inv.notes
            lineItems = inv.lineItems
            if let vat = inv.vatRate {
                vatRate = "\(vat)"
            }
            taxLabel = inv.taxLabel
        } else {
            selectedClientId = store.clients.first?.id ?? UUID()
            invoiceNumber = store.nextInvoiceNumber()
            taxLabel = resolvedTaxLabel()
            if let defaultRate = store.invoiceSettings.defaultTaxRatePercent {
                vatRate = "\(defaultRate)"
            }
        }
    }

    private func resolvedTaxLabel() -> String {
        let indirect = store.taxProfile.effectiveIndirectTax
        let short = IndirectTaxLabelResolver.shortName(from: indirect)
        return short.isEmpty ? "Tax" : short
    }
    
    private func calculatePreview() -> (Decimal, Decimal, Decimal) {
        let vatDec = Decimal(string: vatRate)
        return FreelanceInvoiceEngine.computeTotals(items: lineItems, vatRate: vatDec, profile: store.profile)
    }
    
    private func deleteLineItem(at offsets: IndexSet) {
        lineItems.remove(atOffsets: offsets)
    }
    
    private func saveInvoice() {
        let (sub, tax, grand) = calculatePreview()
        let vatDec = Decimal(string: vatRate)
        
        let inv = FreelanceInvoice(
            id: invoiceToEdit?.id ?? UUID(),
            clientId: selectedClientId,
            invoiceNumber: invoiceNumber,
            issueDate: issueDate,
            dueDate: dueDate,
            status: status,
            currencyCode: appSettingsManager.selectedCurrency.id,
            lineItems: lineItems,
            subtotal: sub,
            taxAmount: tax,
            total: grand,
            vatRate: vatDec,
            taxLabel: taxLabel,
            notes: notes
        )
        
        if store.invoices.contains(where: { $0.id == inv.id }) {
            store.updateInvoice(inv)
        } else {
            store.addInvoice(inv)
        }
    }
}

// MARK: - Invoice Detail View & Local Preview

struct FreelanceInvoiceDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    @State private var showEdit = false
    @State private var pdfData: Data? = nil
    @State private var showShareSheet = false
    
    var invoice: FreelanceInvoice
    
    var body: some View {
        let client = store.clients.first { $0.id == invoice.clientId }
        let intelligence = FreelanceInvoiceEngine.analyzeInvoice(invoice: invoice, client: client, profile: store.profile, historicalInvoices: store.invoices)
        
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    // 1. Intelligence warnings & underpricing indicators
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
                    
                    // Late Risk Alert
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
                    
                    // 2. Summary Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(invoice.invoiceNumber)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
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
                                    .foregroundColor(.gray)
                                Text(client?.name ?? "Unknown Client")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("TOTAL DUE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.gray)
                                Text(appSettingsManager.format(invoice.total))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                        }
                    }
                    .padding(BuxLayout.section)
                    .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
                    
                    // PDF Renderer & share launcher
                    Button(action: {
                        pdfData = FreelanceInvoicePDFRenderer.generatePDF(
                            invoice: invoice,
                            client: client,
                            profile: store.profile,
                            settings: store.invoiceSettings,
                            countryCode: appSettingsManager.selectedCountry.id
                        )
                        showShareSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up.fill")
                            Text("Export & Share invoice PDF")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.current.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(BuxMicroShrinkStyle())
                    
                    // Quick state toggling
                    HStack(spacing: 8) {
                        Button("Mark Paid") {
                            updateStatus(.paid)
                        }
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        
                        Button("Mark Sent") {
                            updateStatus(.sent)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            }
        }
        .sheet(isPresented: $showEdit) {
            FreelanceInvoiceEditorView(invoiceToEdit: invoice)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
        }
        .sheet(isPresented: $showShareSheet) {
            if let data = pdfData {
                ShareSheet(items: [data])
            }
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

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
