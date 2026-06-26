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
                                accent: themeManager.contrastAccentColor(for: colorScheme)
                            )
                            .padding(.horizontal, BuxTokens.marginRegular)

                            if let job = invoiceLinkedJob {
                                linkedJobCard(job)
                                    .padding(.horizontal, BuxTokens.marginRegular)
                            }

                            BuxThemedCardForm {
                                BuxFormSection(title: "Invoice") {
                                    detailRow("Customer", invoice.customerName)
                                    BuxFormRowDivider()
                                    detailRow("Amount", appSettingsManager.format(invoice.amount))
                                    BuxFormRowDivider()
                                    detailRow("For", invoice.jobDescription)
                                    BuxFormRowDivider()
                                    detailRow("Status", invoice.status == .paid ? BuxCatalogLabel.string("Paid", locale: appSettingsManager.interfaceLocale) : BuxCatalogLabel.string("Waiting", locale: appSettingsManager.interfaceLocale))
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
            .buxPadInvoiceSignatureChrome(invoiceId: invoiceId)
        }
    }

    private var matchingProInvoice: StudioInvoice? {
        studioStore.invoices.first { $0.id == invoiceId }
    }

    private var invoiceLinkedJob: SimpleStudioEntry? {
        guard let invoice else { return nil }
        return StudioWorkDealHelpers.linkedJob(forSimpleInvoice: invoice, simpleStore: store)
    }

    private func linkedJobCard(_ job: SimpleStudioEntry) -> some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                BuxCatalogText.text("Linked job")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
                Text(job.jobLabel ?? job.customerName)
                    .font(.system(size: 14, weight: .semibold))
                if let agreed = job.agreedPrice, agreed > 0 {
                    Text(appSettingsManager.format(agreed))
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                currencyCode: appSettingsManager.selectedCurrency.id,
                interfaceLocale: appSettingsManager.interfaceLocale
            )
            data = InvoiceDesignerEngine.generatePDF(context: ctx)
        } else {
            data = StudioInvoicePDFRenderer.generatePDF(
                invoice: invoice,
                client: client,
                profile: studioStore.profile,
                settings: studioStore.invoiceSettings,
                taxProfile: studioStore.taxProfile,
                countryCode: appSettingsManager.selectedCountry.id,
                locale: appSettingsManager.interfaceLocale
            )
        }
        guard let data else { return }
        let clean = invoice.invoiceNumber.isEmpty ? "Invoice" : invoice.invoiceNumber.replacingOccurrences(of: "/", with: "-")
        SimpleStudioShareHelper.presentPDF(
            data: BuxPadInvoicePDFExport.finalizePDF(data, invoiceId: invoice.id),
            fileName: clean
        )
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
            BuxCatalogDynamicText(key: title)
                .font(.system(size: 17, weight: .bold))
            BuxCatalogDynamicText(key: message)
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
            BuxCatalogText.text(label)
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
        BuxDisplayDate.monthDayYear(from: date, locale: appSettingsManager.interfaceLocale)
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
                accent: themeManager.contrastAccentColor(for: colorScheme)
            ),
            openURL: openURL
        )
    }
}
