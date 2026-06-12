//
//  SimpleStudioLogMoneySheet.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioLogMoneySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain
    @ObservedObject private var settings = SettingsStore.shared

    @ObservedObject var store: SimpleStudioStore

    let initialKind: SimpleEntryKind?

    @State private var pendingSetAside: PendingSetAside?

    @State private var kind: SimpleEntryKind = .income
    @State private var amountText = ""
    @State private var customerName = ""
    @State private var jobLabel = ""
    @State private var note = ""
    @State private var materialsText = ""
    @State private var petrolText = ""
    @State private var transportText = ""
    @State private var platformFeeText = ""
    @State private var isUnpaid = false

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                BuxThemedCardForm {
                    BuxFormSection(title: "Type") {
                        Picker(loc("Type"), selection: $kind) {
                            ForEach(logKinds, id: \.self) { k in
                                Label {
                                    Text(k.localizedLogTitle(locale: appSettingsManager.interfaceLocale))
                                } icon: {
                                    Image(systemName: k.systemImage)
                                }
                                .tag(k)
                            }
                        }
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Amount") {
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Who") {
                        TextField(BuxCatalogLabel.string("Customer name", locale: appSettingsManager.interfaceLocale), text: $customerName)
                            .buxFormFieldPadding()
                        if !store.recentCustomerNames().isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(store.recentCustomerNames()) { customer in
                                        Button(customer.name) {
                                            customerName = customer.name
                                            if jobLabel.isEmpty, let label = customer.lastJobLabel {
                                                jobLabel = label
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

                    if kind == .job || kind == .income {
                        BuxFormSection(title: "Job") {
                            TextField(BuxCatalogLabel.string("What was it for?", locale: appSettingsManager.interfaceLocale), text: $jobLabel)
                                .buxFormFieldPadding()
                        }
                        jobCostFields
                    }

                    if kind == .owedToMe || kind == .job {
                        BuxFormSection {
                            Toggle(isOn: $isUnpaid) {
                                BuxCatalogDynamicText(key: "Not paid yet")
                            }
                                .tint(themeManager.contrastAccentColor(for: colorScheme))
                                .buxFormFieldPadding()
                        }
                    }

                    BuxFormSection(title: "Note") {
                        TextField(BuxCatalogLabel.string("Optional", locale: appSettingsManager.interfaceLocale), text: $note)
                            .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle("Log money")
            .buxInterfaceLocale()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarSaveButton(isDirty: canSave) { save() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if canSave {
                    BuxButton(
                        title: "Send",
                        systemImage: "paperplane.fill",
                        role: .secondary,
                        expands: true
                    ) {
                        sendPreview()
                    }
                    .padding(.horizontal, BuxTokens.marginRegular)
                    .padding(.bottom, BuxTokens.tight)
                    .background(.ultraThinMaterial)
                }
            }
            .buxRootNavigationChrome()
            .buxMeshSheetPresentation()
            .onAppear {
                if let initialKind { kind = initialKind }
            }
            .sheet(item: $pendingSetAside, onDismiss: { dismiss() }) { pending in
                TaxEnvelopeSetAsideSheet(entryId: pending.entryId, incomeAmount: pending.amount)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(taxEnvelopeBrain)
                    .environmentObject(store)
            }
        }
    }

    private struct PendingSetAside: Identifiable {
        var id: UUID { entryId }
        let entryId: UUID
        let amount: Decimal
    }

    @ViewBuilder
    private var jobCostFields: some View {
        BuxFormSection(title: "Job costs") {
            costField("Materials", text: $materialsText)
            BuxFormRowDivider()
            costField("Petrol / gas", text: $petrolText)
            BuxFormRowDivider()
            costField("Transport", text: $transportText)
            if settings.studioPersona == .tasksAndGigs {
                BuxFormRowDivider()
                costField("Platform fee", text: $platformFeeText)
            }
        }
    }

    private func costField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            BuxCatalogText.text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
        .buxFormFieldPadding()
    }

    private var logKinds: [SimpleEntryKind] {
        settings.studioPersona == .lending
            ? SimpleEntryKind.lendingKinds
            : SimpleEntryKind.dailyLogKinds
    }

    private var canSave: Bool {
        Decimal(string: amountText) != nil && !(Decimal(string: amountText) == 0)
    }

    private func save() {
        guard let amount = Decimal(string: amountText) else { return }
        let status: SimplePaymentStatus = isUnpaid ? .unpaid : .paid
        let entry = SimpleStudioEntry(
            kind: kind,
            amount: amount,
            customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            jobLabel: jobLabel.isEmpty ? nil : jobLabel,
            note: note.isEmpty ? nil : note,
            paymentStatus: (kind == .owedToMe || kind == .job) && isUnpaid ? .unpaid : status,
            platformFee: decimal(from: platformFeeText),
            materials: decimal(from: materialsText),
            petrol: decimal(from: petrolText),
            transport: decimal(from: transportText)
        )
        store.addEntry(entry)
        BuxSaveFeedback.success()
        let isIncome = kind == .income || kind == .job || kind == .repaymentReceived
        if isIncome,
           studioStore.taxEnvelope.isEnabled,
           TaxEnvelopeContextBridge.incomeAmount(for: entry) > 0 {
            pendingSetAside = PendingSetAside(entryId: entry.id, amount: entry.amount + (entry.tip ?? 0))
        } else {
            dismiss()
        }
    }

    private func decimal(from text: String) -> Decimal? {
        guard !text.isEmpty else { return nil }
        return Decimal(string: text)
    }

    private func sendPreview() {
        guard let amount = Decimal(string: amountText) else { return }
        let formatted = appSettingsManager.format(amount)
        let who = customerName.isEmpty ? "someone" : customerName
        let what = jobLabel.isEmpty ? kind.logTitle.lowercased() : jobLabel
        let message = "\(kind.logTitle): \(formatted) — \(who) · \(what)"
        let card = SimpleInvoiceCardView(
            businessName: SettingsStore.shared.resolvedDisplayName,
            customerName: who,
            amountFormatted: formatted,
            description: what,
            isPaid: !isUnpaid,
            accent: themeManager.contrastAccentColor(for: colorScheme),
            dueDateLabel: isUnpaid ? "Waiting on payment" : nil,
            note: note.isEmpty ? nil : note
        )
        var items: [Any] = [message]
        if let image = SimpleStudioShareHelper.renderCard(card) {
            items.append(image)
        }
        let phone = store.customer(named: customerName)?.phone
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
