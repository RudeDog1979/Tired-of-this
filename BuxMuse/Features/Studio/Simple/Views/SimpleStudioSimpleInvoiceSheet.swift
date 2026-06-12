//
//  SimpleStudioSimpleInvoiceSheet.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioSimpleInvoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore

    @ObservedObject var store: SimpleStudioStore
    var prefill: SimpleInvoiceSuggestion?

    @State private var linkedJobId: UUID?
    @State private var selectedJobPickId: UUID?
    @State private var customerName = ""
    @State private var amountText = ""
    @State private var jobDescription = ""
    @State private var note = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var sharePayload: BuxShareItemsPayload?
    @State private var dismissAfterShare = false

    private var selectedJob: SimpleStudioEntry? {
        guard let linkedJobId else { return nil }
        return store.entry(id: linkedJobId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxTokens.block) {
                        BuxThemedCardForm {
                            BuxFormSection(title: "Invoice") {
                                TextField(BuxCatalogLabel.string("Customer", locale: appSettingsManager.interfaceLocale), text: $customerName)
                                    .buxFormFieldPadding()
                                customerChips
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("Amount", locale: appSettingsManager.interfaceLocale), text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                completedJobPicker
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("For what?", locale: appSettingsManager.interfaceLocale), text: $jobDescription)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                DatePicker(BuxCatalogLabel.string("Due by", locale: appSettingsManager.interfaceLocale), selection: $dueDate, displayedComponents: .date)
                                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField(BuxCatalogLabel.string("Note (optional)", locale: appSettingsManager.interfaceLocale), text: $note, axis: .vertical)
                                    .lineLimit(2...3)
                                    .buxFormFieldPadding()
                            }
                        }

                        if canPreview {
                            invoicePreview
                                .padding(.horizontal, BuxTokens.marginRegular)
                        }

                        VStack(spacing: BuxTokens.tight) {
                            BuxButton(
                                title: "Save & send",
                                systemImage: "paperplane.fill",
                                role: .primary,
                                expands: true,
                                isEnabled: canPreview
                            ) {
                                createAndSend(saveFirst: true)
                            }

                            BuxButton(
                                title: "Send only",
                                systemImage: "paperplane",
                                role: .secondary,
                                expands: true,
                                isEnabled: canPreview
                            ) {
                                createAndSend(saveFirst: false)
                            }
                        }
                        .padding(.horizontal, BuxTokens.marginRegular)
                    }
                    .padding(.top, BuxTokens.section)
                    .padding(.bottom, BuxTokens.sheetBottomClearance)
                }
            }
            .buxCatalogNavigationTitle("Simple invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxRootNavigationChrome()
            .buxInterfaceLocale()
            .buxMeshSheetPresentation()
            .onAppear {
                applyPrefillIfNeeded()
                applyJobBillingDefaultsIfNeeded()
            }
            .onChange(of: selectedJobPickId) { _, _ in
                applyJobBillingDefaultsIfNeeded()
            }
            .sheet(item: $sharePayload) { payload in
                BuxActivityShareSheet(items: payload.items) {
                    sharePayload = nil
                    if dismissAfterShare {
                        dismiss()
                    }
                    dismissAfterShare = false
                }
                .buxShareSheetPresentation()
                .ignoresSafeArea()
            }
        }
    }

    private var jobPicks: [SimpleJobInvoicePick] {
        StudioInvoiceSuggestionEngine.billableJobPicks(
            forCustomerName: customerName,
            store: store,
            studioStore: studioStore
        )
    }

    @ViewBuilder
    private var completedJobPicker: some View {
        if !jobPicks.isEmpty {
            Picker(BuxCatalogLabel.string("Bill from job", locale: appSettingsManager.interfaceLocale), selection: $selectedJobPickId) {
                BuxCatalogDynamicText(key: "None").tag(UUID?.none)
                ForEach(jobPicks) { pick in
                    Text(
                        BuxLocalizedString.format(
                            "%@ · %@",
                            locale: appSettingsManager.interfaceLocale,
                            pick.jobLabel,
                            appSettingsManager.format(pick.amount)
                        )
                    )
                        .tag(Optional(pick.jobId))
                }
            }
            .pickerStyle(.menu)
            .buxFormFieldPadding()
            .onChange(of: selectedJobPickId) { _, newId in
                guard let newId,
                      let pick = jobPicks.first(where: { $0.jobId == newId }) else { return }
                linkedJobId = pick.jobId
                amountText = "\(pick.amount)"
                jobDescription = pick.jobLabel
                applyJobBillingDefaultsIfNeeded()
            }
        }
    }

    private func applyPrefillIfNeeded() {
        guard let prefill else { return }
        linkedJobId = prefill.jobId
        selectedJobPickId = prefill.jobId
        customerName = prefill.customerName
        amountText = "\(prefill.amount)"
        jobDescription = prefill.jobDescription
        applyJobBillingDefaultsIfNeeded()
    }

    private func applyJobBillingDefaultsIfNeeded() {
        guard let job = selectedJob else { return }
        if let agreed = job.agreedPrice, agreed > 0 {
            amountText = "\(agreed)"
        }
        if let label = job.jobLabel, !label.isEmpty {
            jobDescription = label
        }
    }

    @ViewBuilder
    private var customerChips: some View {
        if !store.recentCustomerNames().isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.recentCustomerNames()) { customer in
                        Button(customer.name) {
                            customerName = customer.name
                            if jobDescription.isEmpty, let label = customer.lastJobLabel {
                                jobDescription = label
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(themeManager.accentWash(for: colorScheme))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, BuxTokens.section)
                .padding(.bottom, BuxTokens.section)
            }
        }
    }

    private var canPreview: Bool {
        guard let amount = Decimal(string: amountText), amount > 0 else { return false }
        return !customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shareMessage: String {
        let amount = appSettingsManager.format(Decimal(string: amountText) ?? 0)
        let due = formattedDueDate
        return "Invoice for \(jobDescription.isEmpty ? "work" : jobDescription): \(amount). Due by \(due)."
    }

    private var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dueDate)
    }

    private var invoicePreview: some View {
        SimpleInvoiceCardView(
            businessName: businessName,
            customerName: customerName,
            amountFormatted: appSettingsManager.format(Decimal(string: amountText) ?? 0),
            description: jobDescription.isEmpty ? "Work completed" : jobDescription,
            isPaid: false,
            accent: themeManager.contrastAccentColor(for: colorScheme),
            dueDateLabel: "\(BuxCatalogLabel.string("Due by", locale: appSettingsManager.interfaceLocale)) \(formattedDueDate)",
            note: note.isEmpty ? nil : note,
            locale: appSettingsManager.interfaceLocale
        )
    }

    private var businessName: String {
        let b = studioStore.profile.businessName
        if !b.isEmpty { return b }
        return SettingsStore.shared.resolvedDisplayName
    }

    private func createAndSend(saveFirst: Bool) {
        guard let amount = Decimal(string: amountText) else { return }
        if saveFirst {
            let invoice = SimpleInvoice(
                customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                jobDescription: jobDescription.isEmpty ? "Work" : jobDescription,
                status: .sent,
                sharedAt: Date(),
                linkedEntryId: linkedJobId
            )
            store.addInvoice(invoice)
            StudioSimpleJobInvoiceSync.afterInvoiceCreated(
                invoice,
                jobEntryId: linkedJobId,
                store: store,
                studioStore: studioStore
            )
            BuxSaveFeedback.success()
        }

        var items: [Any] = [shareMessage]
        if let image = SimpleStudioShareHelper.renderCard(invoicePreview.frame(width: 340)) {
            items.append(image)
        }

        dismissAfterShare = saveFirst
        sharePayload = BuxShareItemsPayload(items: items)
    }
}

struct SimpleInvoiceCardView: View {
    let businessName: String
    let customerName: String
    let amountFormatted: String
    let description: String
    let isPaid: Bool
    let accent: Color
    var dueDateLabel: String? = nil
    var note: String? = nil
    var locale: Locale = BuxInterfaceLocale.currentInterfaceLocale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(businessName)
                        .font(.system(size: 18, weight: .bold))
                    Text(BuxCatalogText.string("Simple Invoice", locale: locale))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(isPaid ? "PAID" : "UNPAID")
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isPaid ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(isPaid ? .green : .orange)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(BuxCatalogText.string("Bill to", locale: locale))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(customerName)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(BuxCatalogText.string("For", locale: locale))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(description)
                    .font(.system(size: 14, weight: .medium))
            }

            if let dueDateLabel {
                Text(dueDateLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }

            HStack {
                Text(BuxCatalogText.string("Amount due", locale: locale))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(amountFormatted)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
            }

            if let note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(BuxCatalogText.string("Sent via BuxMuse · Not a bank", locale: locale))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: BuxTokens.Radius.hero, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BuxTokens.Radius.hero, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }
}
