//
//  SimpleStudioPersonDetailView.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioPersonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore

    @ObservedObject var store: SimpleStudioStore

    let customerId: UUID

    @State private var name = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var editingJob: SimpleStudioEntry?
    @State private var showJobEditor = false

    private var customer: SimpleCustomerMemory? {
        store.customers.first { $0.id == customerId }
    }

    private var relatedJobs: [SimpleStudioEntry] {
        guard let customer else { return [] }
        return store.entries.filter { entry in
            entry.kind == .job
                && entry.customerName.localizedCaseInsensitiveCompare(customer.name) == .orderedSame
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: BuxTokens.block) {
                    if let customer, customer.outstandingBalance > 0 {
                        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                                BuxCatalogDynamicText(key: "Waiting on them")
                                    .font(.system(size: 12, weight: .semibold))
                                    .buxLabelSecondary()
                                Text(appSettingsManager.format(customer.outstandingBalance))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                                BuxButton(
                                    title: "Send",
                                    systemImage: "paperplane.fill",
                                    role: .secondary,
                                    expands: true
                                ) {
                                    sendBalanceReminder(for: customer)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, BuxTokens.marginRegular)
                    }

                    if hasContactActions {
                        contactActions
                            .padding(.horizontal, BuxTokens.marginRegular)
                    }

                    BuxThemedCardForm {
                        BuxFormSection(title: "Person") {
                            TextField(BuxCatalogLabel.string("Name", locale: appSettingsManager.interfaceLocale), text: $name)
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                            TextField(BuxCatalogLabel.string("Phone / WhatsApp", locale: appSettingsManager.interfaceLocale), text: $phone)
                                .keyboardType(.phonePad)
                                .buxFormFieldPadding()
                            BuxFormRowDivider()
                            TextField(BuxCatalogLabel.string("Notes", locale: appSettingsManager.interfaceLocale), text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .buxFormFieldPadding()
                        }
                    }

                    if !relatedJobs.isEmpty {
                        VStack(alignment: .leading, spacing: BuxTokens.tight) {
                            BuxSectionHeader(title: "Jobs")
                                .padding(.horizontal, BuxTokens.marginRegular)

                            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(Array(relatedJobs.enumerated()), id: \.element.id) { index, job in
                                        if index > 0 { Divider().padding(.leading, BuxTokens.section) }
                                        jobRow(job)
                                    }
                                }
                            }
                            .padding(.horizontal, BuxTokens.marginRegular)
                        }
                    }

                    BuxButton(
                        title: "Save",
                        systemImage: "checkmark",
                        role: .primary,
                        expands: true,
                        isEnabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        savePerson()
                    }
                    .padding(.horizontal, BuxTokens.marginRegular)
                    .padding(.bottom, BuxTokens.sheetBottomClearance)
                }
                .padding(.top, BuxTokens.section)
            }
        }
        .buxCatalogNavigationTitle("Person")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showJobEditor) {
            SimpleStudioJobQuoteSheet(store: store, existingJob: editingJob)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(StudioStore.shared)
                .onDisappear { editingJob = nil }
        }
        .onAppear(perform: load)
    }

    private var hasContactActions: Bool {
        !SimpleStudioContactHelper.sanitizedDigits(phone).isEmpty
    }

    private var contactActions: some View {
        HStack(spacing: BuxTokens.tight) {
            if SimpleStudioContactHelper.whatsAppURL(phone: phone, message: "Hi \(name)") != nil {
                contactButton(title: "WhatsApp", icon: "message.fill", color: .green) {
                    openContact(channel: .whatsapp)
                }
            }
            if SimpleStudioContactHelper.telURL(phone: phone) != nil {
                contactButton(title: "Call", icon: "phone.fill", color: themeManager.contrastAccentColor(for: colorScheme)) {
                    openContact(channel: .call)
                }
            }
        }
    }

    private enum ContactChannel { case whatsapp, call }

    private func contactButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                BuxCatalogText.text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func jobRow(_ job: SimpleStudioEntry) -> some View {
        Button {
            editingJob = job
            showJobEditor = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogText.text(job.jobLabel ?? "Job")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    if job.isJobFullyPaid {
                        BuxCatalogDynamicText(key: "Paid")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                    } else {
                        Text(
                            BuxLocalizedString.format(
                                "Waiting %@",
                                locale: appSettingsManager.interfaceLocale,
                                appSettingsManager.format(job.jobBalanceDue)
                            )
                        )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, BuxTokens.section)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() {
        guard let customer else { return }
        name = customer.name
        phone = customer.phone ?? ""
        notes = customer.notes ?? ""
    }

    private func savePerson() {
        store.updateCustomer(
            id: customerId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        BuxSaveFeedback.success()
        dismiss()
    }

    private func openContact(channel: ContactChannel) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let url: URL? = switch channel {
        case .whatsapp:
            SimpleStudioContactHelper.whatsAppURL(phone: phone, message: "Hi \(trimmed)")
        case .call:
            SimpleStudioContactHelper.telURL(phone: phone)
        }
        guard let url else { return }
        openURL(url)
    }

    private func sendBalanceReminder(for customer: SimpleCustomerMemory) {
        let businessName = studioStore.profile.businessName.isEmpty
            ? SettingsStore.shared.resolvedDisplayName
            : studioStore.profile.businessName
        SimpleStudioReminderHelper.presentContactOptions(
            SimpleStudioReminderHelper.Payload(
                customerName: customer.name,
                amountFormatted: appSettingsManager.format(customer.outstandingBalance),
                jobLabel: customer.lastJobLabel ?? "outstanding work",
                businessName: businessName,
                phone: phone.isEmpty ? customer.phone : phone,
                accent: themeManager.contrastAccentColor(for: colorScheme)
            ),
            openURL: openURL
        )
    }
}
