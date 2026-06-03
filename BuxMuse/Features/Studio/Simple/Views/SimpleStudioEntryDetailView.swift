//
//  SimpleStudioEntryDetailView.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioEntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore

    @ObservedObject var store: SimpleStudioStore

    let entryId: UUID

    @State private var showScanEditor = false
    @State private var showJobEditor = false
    @State private var invoicePrefill: SimpleInvoiceSuggestion?

    private var entry: SimpleStudioEntry? {
        store.entry(id: entryId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                if let entry {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: BuxTokens.block) {
                            if let image = SimpleStudioScanImageStore.load(path: entry.sourcePhotoPath) {
                                BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.tight) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 280)
                                        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                                        .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, BuxTokens.marginRegular)
                            }

                            if entry.kind == .job {
                                StudioJobAgreementSummarySection(job: entry)
                                    .environmentObject(studioStore)
                                    .environmentObject(store)
                                    .padding(.horizontal, BuxTokens.marginRegular)
                            }

                            BuxThemedCardForm {
                                BuxFormSection(title: "Details") {
                                    detailRow("Type", entry.kind.logTitle)
                                    BuxFormRowDivider()
                                    detailRow("Amount", appSettingsManager.format(entry.amount))
                                    if !entry.customerName.isEmpty {
                                        BuxFormRowDivider()
                                        detailRow("Who", entry.customerName)
                                    }
                                    if let jobLabel = entry.jobLabel, !jobLabel.isEmpty {
                                        BuxFormRowDivider()
                                        detailRow("What", jobLabel)
                                    }
                                    if entry.kind == .job || entry.kind == .owedToMe {
                                        BuxFormRowDivider()
                                        detailRow("Payment", paymentLabel(entry.paymentStatus))
                                    }
                                    if entry.kind == .job {
                                        jobPayRows(entry)
                                    }
                                    if let note = entry.note, !note.isEmpty {
                                        BuxFormRowDivider()
                                        detailRow("Note", note)
                                    }
                                    BuxFormRowDivider()
                                    detailRow("When", formattedDate(entry.createdAt))
                                }
                            }

                            if showsWaitingActions(for: entry) {
                                if let suggestion = jobInvoiceSuggestion(for: entry) {
                                    BuxButton(
                                        title: "Invoice \(appSettingsManager.format(suggestion.amount))",
                                        systemImage: "doc.text.fill",
                                        role: .primary,
                                        expands: true
                                    ) {
                                        invoicePrefill = suggestion
                                    }
                                    .padding(.horizontal, BuxTokens.marginRegular)
                                }

                                BuxButton(
                                    title: "Send",
                                    systemImage: "paperplane.fill",
                                    role: .secondary,
                                    expands: true
                                ) {
                                    sendEntry(entry)
                                }
                                .padding(.horizontal, BuxTokens.marginRegular)

                                BuxButton(
                                    title: "Mark paid",
                                    systemImage: "checkmark.circle.fill",
                                    role: .primary,
                                    expands: true
                                ) {
                                    store.markEntryPaid(id: entry.id)
                                    BuxSaveFeedback.success()
                                    dismiss()
                                }
                                .padding(.horizontal, BuxTokens.marginRegular)
                            } else if showsSettledAction(for: entry) {
                                BuxButton(
                                    title: "Mark settled",
                                    systemImage: "checkmark.circle.fill",
                                    role: .primary,
                                    expands: true
                                ) {
                                    store.markEntryPaid(id: entry.id)
                                    BuxSaveFeedback.success()
                                    dismiss()
                                }
                                .padding(.horizontal, BuxTokens.marginRegular)
                            }

                            if !showsWaitingActions(for: entry) {
                                BuxButton(
                                    title: "Send",
                                    systemImage: "paperplane.fill",
                                    role: .secondary,
                                    expands: true
                                ) {
                                    sendEntry(entry)
                                }
                                .padding(.horizontal, BuxTokens.marginRegular)
                            }

                            BuxButton(
                                title: editButtonTitle(for: entry),
                                systemImage: "pencil",
                                role: showsWaitingActions(for: entry) || showsSettledAction(for: entry) ? .secondary : .primary,
                                expands: true
                            ) {
                                openEditor(for: entry)
                            }
                            .padding(.horizontal, BuxTokens.marginRegular)
                            .padding(.bottom, BuxTokens.sheetBottomClearance)
                        }
                        .padding(.top, BuxTokens.section)
                    }
                } else {
                    missingContent(title: "Entry not found", message: "This entry may have been removed.")
                }
            }
            .navigationTitle("Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxStudioSheetContent()
            .sheet(isPresented: $showScanEditor) {
                if let entry {
                    SimpleStudioScanView(store: store, existingEntry: entry)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                }
            }
            .sheet(isPresented: $showJobEditor) {
                if let entry {
                    SimpleStudioJobQuoteSheet(store: store, existingJob: entry)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(StudioStore.shared)
                }
            }
            .sheet(item: $invoicePrefill) { prefill in
                SimpleStudioSimpleInvoiceSheet(store: store, prefill: prefill)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            }
        }
    }

    private func jobInvoiceSuggestion(for entry: SimpleStudioEntry) -> SimpleInvoiceSuggestion? {
        guard entry.kind == .job else { return nil }
        return StudioInvoiceSuggestionEngine.simpleSuggestions(store: store, studioStore: studioStore)
            .first { $0.jobId == entry.id }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .buxLabelSecondary()
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .multilineTextAlignment(.trailing)
        }
        .buxFormFieldPadding()
    }

    private func paymentLabel(_ status: SimplePaymentStatus) -> String {
        switch status {
        case .paid: return "Paid"
        case .unpaid: return "Still waiting"
        case .partial: return "Partial"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func editButtonTitle(for entry: SimpleStudioEntry) -> String {
        if entry.sourcePhotoPath != nil { return "Edit scan" }
        if entry.kind == .job { return "Edit job" }
        return "Edit entry"
    }

    private func openEditor(for entry: SimpleStudioEntry) {
        if entry.kind == .job {
            showJobEditor = true
        } else {
            showScanEditor = true
        }
    }

    @ViewBuilder
    private func jobPayRows(_ entry: SimpleStudioEntry) -> some View {
        Group {
            BuxFormRowDivider()
            detailRow("Pay type", entry.resolvedPayStyle.plainTitle)
            if entry.resolvedPayStyle == .byTheHour, let rate = entry.hourlyRate {
                BuxFormRowDivider()
                detailRow("Hourly rate", "\(appSettingsManager.format(rate)) / hr")
            } else if let agreed = entry.agreedPrice {
                BuxFormRowDivider()
                detailRow("Agreed price", appSettingsManager.format(agreed))
            }
        if let planned = entry.plannedTimeLabel {
            BuxFormRowDivider()
            detailRow("Planned time", planned)
        }
        if let logged = entry.loggedHoursLabel {
            BuxFormRowDivider()
            detailRow("Time on job", logged)
        }
            if entry.resolvedPayStyle == .byTheHour,
               let rate = entry.hourlyRate,
               rate > 0 {
                BuxFormRowDivider()
                detailRow(
                    "Owed from hours",
                    appSettingsManager.format(
                        SimpleStudioTimePayEngine.earnings(
                            seconds: entry.loggedSeconds ?? 0,
                            hourlyRate: rate
                        )
                    )
                )
            }
        }
    }

    private func showsWaitingActions(for entry: SimpleStudioEntry) -> Bool {
        switch entry.kind {
        case .owedToMe:
            return entry.paymentStatus != .paid
        case .job:
            return !entry.isJobFullyPaid
        default:
            return false
        }
    }

    private func showsSettledAction(for entry: SimpleStudioEntry) -> Bool {
        (entry.kind == .iOwe || entry.kind == .lent) && entry.paymentStatus != .paid
    }

    private var businessName: String {
        let name = studioStore.profile.businessName
        return name.isEmpty ? SettingsStore.shared.resolvedDisplayName : name
    }

    private func missingContent(title: String, message: String) -> some View {
        VStack(spacing: BuxTokens.section) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 17, weight: .bold))
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            BuxButton(title: "Close", systemImage: "xmark", role: .secondary, expands: false) {
                dismiss()
            }
        }
        .padding(BuxTokens.marginRegular)
    }

    private func sendEntry(_ entry: SimpleStudioEntry) {
        if showsWaitingActions(for: entry) {
            let due = entry.kind == .job ? entry.jobBalanceDue : entry.amount
            let phone = store.customer(named: entry.customerName)?.phone
            SimpleStudioReminderHelper.presentContactOptions(
                SimpleStudioReminderHelper.Payload(
                    customerName: entry.customerName,
                    amountFormatted: appSettingsManager.format(due),
                    jobLabel: entry.jobLabel ?? entry.kind.logTitle,
                    businessName: businessName,
                    phone: phone,
                    accent: themeManager.current.accentColor
                ),
                openURL: openURL
            )
            return
        }

        let amount = entry.kind == .job ? entry.jobBalanceDue : entry.amount
        let message = "\(entry.kind.logTitle): \(appSettingsManager.format(amount)) — \(entry.jobLabel ?? entry.customerName)"
        var items: [Any] = [message]
        if let image = SimpleStudioScanImageStore.load(path: entry.sourcePhotoPath) {
            items.append(image)
        } else {
            let card = SimpleInvoiceCardView(
                businessName: businessName,
                customerName: entry.customerName.isEmpty ? "Customer" : entry.customerName,
                amountFormatted: appSettingsManager.format(amount),
                description: entry.jobLabel ?? entry.kind.logTitle,
                isPaid: entry.paymentStatus == .paid,
                accent: themeManager.current.accentColor
            )
            if let rendered = SimpleStudioShareHelper.renderCard(card) {
                items.append(rendered)
            }
        }
        let phone = store.customer(named: entry.customerName)?.phone
        SimpleStudioContactActions.present(
            SimpleStudioContactActions.Options(
                message: message,
                recipientPhone: phone,
                shareItems: items
            ),
            openURL: openURL
        )
    }
}
