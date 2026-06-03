//
//  SimpleStudioSimpleInvoiceSheet.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioSimpleInvoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
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

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxTokens.block) {
                        BuxThemedCardForm {
                            BuxFormSection(title: "Invoice") {
                                TextField("Customer", text: $customerName)
                                    .buxFormFieldPadding()
                                customerChips
                                BuxFormRowDivider()
                                TextField("Amount", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                completedJobPicker
                                BuxFormRowDivider()
                                TextField("For what?", text: $jobDescription)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                DatePicker("Due by", selection: $dueDate, displayedComponents: .date)
                                    .tint(themeManager.current.accentColor)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField("Note (optional)", text: $note, axis: .vertical)
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
            .navigationTitle("Simple invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxStudioSheetContent()
            .onAppear { applyPrefillIfNeeded() }
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
            Picker("Bill from job", selection: $selectedJobPickId) {
                Text("None").tag(UUID?.none)
                ForEach(jobPicks) { pick in
                    Text("\(pick.jobLabel) · \(appSettingsManager.format(pick.amount))")
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
                        .foregroundColor(themeManager.current.accentColor)
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
            accent: themeManager.current.accentColor,
            dueDateLabel: "Due \(formattedDueDate)",
            note: note.isEmpty ? nil : note
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
            if let jobId = linkedJobId {
                StudioSyncCoordinator.linkSimpleInvoiceToJob(
                    invoiceId: invoice.id,
                    jobEntryId: jobId,
                    store: store
                )
            }
            BuxSaveFeedback.success()
        }

        var items: [Any] = [shareMessage]
        if let image = SimpleStudioShareHelper.renderCard(invoicePreview.frame(width: 340)) {
            items.append(image)
        }
        let phone = store.customer(named: customerName)?.phone ?? store.customer(named: customerName.trimmingCharacters(in: .whitespacesAndNewlines))?.phone
        SimpleStudioContactActions.present(
            SimpleStudioContactActions.Options(
                sheetTitle: "Send invoice",
                message: shareMessage,
                recipientPhone: phone,
                shareItems: items
            ),
            openURL: openURL
        )

        if saveFirst {
            dismiss()
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(businessName)
                        .font(.system(size: 18, weight: .bold))
                    Text("Simple Invoice")
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
                Text("Bill to")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(customerName)
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("For")
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
                Text("Amount due")
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

            Text("Sent via BuxMuse · Not a bank")
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

struct SimpleStudioShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
