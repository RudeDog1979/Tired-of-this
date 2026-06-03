//
//  SimpleStudioInvoiceDetailView.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioInvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore

    @ObservedObject var store: SimpleStudioStore
    @ObservedObject private var settingsStore = SettingsStore.shared

    let invoiceId: UUID

    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?

    private var isProStudio: Bool { settingsStore.studioMode == .pro }

    private var invoice: SimpleInvoice? {
        store.invoice(id: invoiceId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                if let invoice {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: BuxTokens.block) {
                            SimpleInvoiceCardView(
                                businessName: businessName,
                                customerName: invoice.customerName,
                                amountFormatted: appSettingsManager.format(invoice.amount),
                                description: invoice.jobDescription,
                                isPaid: invoice.status == .paid,
                                accent: themeManager.current.accentColor
                            )
                            .padding(.horizontal, BuxTokens.marginRegular)

                            StudioAgreementDealLinkButton(
                                agreement: invoiceDealAgreement,
                                linkedJob: invoiceLinkedJob,
                                linkedProject: nil
                            )
                            .environmentObject(store)
                            .padding(.horizontal, BuxTokens.marginRegular)

                            BuxThemedCardForm {
                                BuxFormSection(title: "Invoice") {
                                    detailRow("Customer", invoice.customerName)
                                    BuxFormRowDivider()
                                    detailRow("Amount", appSettingsManager.format(invoice.amount))
                                    BuxFormRowDivider()
                                    detailRow("For", invoice.jobDescription)
                                    BuxFormRowDivider()
                                    detailRow("Status", invoice.status == .paid ? "Paid" : "Waiting")
                                    BuxFormRowDivider()
                                    detailRow("Sent", formattedDate(invoice.createdAt))
                                }
                            }

                            BuxButton(
                                title: "Export PDF",
                                systemImage: "doc.richtext",
                                role: .secondary,
                                expands: true
                            ) {
                                if isProStudio, let proInvoice = matchingProInvoice {
                                    exportProPDF(proInvoice)
                                } else {
                                    proUpsellFeature = .pdfInvoices
                                }
                            }
                            .padding(.horizontal, BuxTokens.marginRegular)

                            if invoice.status != .paid {
                                BuxButton(
                                    title: "Send",
                                    systemImage: "paperplane.fill",
                                    role: .secondary,
                                    expands: true
                                ) {
                                    sendReminder(for: invoice)
                                }
                                .padding(.horizontal, BuxTokens.marginRegular)

                                BuxButton(
                                    title: "Mark paid",
                                    systemImage: "checkmark.circle.fill",
                                    role: .primary,
                                    expands: true
                                ) {
                                    store.markInvoicePaid(id: invoice.id)
                                    BuxSaveFeedback.success()
                                    dismiss()
                                }
                                .padding(.horizontal, BuxTokens.marginRegular)
                            }
                        }
                        .padding(.top, BuxTokens.section)
                        .padding(.bottom, BuxTokens.sheetBottomClearance)
                    }
                } else {
                    missingContent(title: "Invoice not found", message: "This invoice may have been removed.")
                }
            }
            .buxCatalogNavigationTitle("Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxStudioSheetContent()
            .sheet(item: $proUpsellFeature) { feature in
                StudioProUpsellSheet(feature: feature)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(store)
            }
        }
    }

    private var matchingProInvoice: StudioInvoice? {
        studioStore.invoices.first { $0.id == invoiceId }
    }

    private var invoiceLinkedJob: SimpleStudioEntry? {
        guard let invoice else { return nil }
        return StudioWorkDealHelpers.linkedJob(forSimpleInvoice: invoice, simpleStore: store)
    }

    private var invoiceDealAgreement: AgreementDraft? {
        guard let invoice else { return nil }
        return StudioWorkDealHelpers.agreement(
            forSimpleInvoice: invoice,
            studioStore: studioStore,
            simpleStore: store
        )
    }

    private func exportProPDF(_ invoice: StudioInvoice) {
        let client = studioStore.clients.first { $0.id == invoice.clientId }
        let data: Data?
        if let snapshot = invoice.designerSnapshot {
            let ctx = InvoiceDesignerEngine.buildRenderContext(
                invoice: invoice,
                client: client,
                profile: studioStore.profile,
                settings: studioStore.invoiceSettings,
                snapshot: snapshot,
                taxProfile: studioStore.taxProfile,
                currencyCode: appSettingsManager.selectedCurrency.id
            )
            data = InvoiceDesignerEngine.generatePDF(context: ctx)
        } else {
            data = StudioInvoicePDFRenderer.generatePDF(
                invoice: invoice,
                client: client,
                profile: studioStore.profile,
                settings: studioStore.invoiceSettings,
                taxProfile: studioStore.taxProfile,
                countryCode: appSettingsManager.selectedCountry.id
            )
        }
        guard let data,
              let url = writeTemporaryPDF(data, invoiceNumber: invoice.invoiceNumber) else { return }
        SimpleStudioShareHelper.present(items: [url])
    }

    private func writeTemporaryPDF(_ data: Data, invoiceNumber: String) -> URL? {
        let clean = invoiceNumber.isEmpty ? "Invoice" : invoiceNumber.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(clean).pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
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

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .buxLabelSecondary()
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
        .buxFormFieldPadding()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func sendReminder(for invoice: SimpleInvoice) {
        let phone = store.customer(named: invoice.customerName)?.phone
        SimpleStudioReminderHelper.presentContactOptions(
            SimpleStudioReminderHelper.Payload(
                customerName: invoice.customerName,
                amountFormatted: appSettingsManager.format(invoice.amount),
                jobLabel: invoice.jobDescription,
                businessName: businessName,
                phone: phone,
                accent: themeManager.current.accentColor
            ),
            openURL: openURL
        )
    }
}
