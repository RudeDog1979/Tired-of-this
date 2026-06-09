//
//  SimpleStudioMyMoneyView.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioMyMoneyView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore

    @ObservedObject var store: SimpleStudioStore

    let display: SimpleMyMoneyDisplay

    @State private var selectedSliceID: String?
    @State private var detailDestination: SimpleStudioDetailDestination?
    @State private var pendingMarkPaidId: UUID?
    @State private var showMarkPaidConfirmation = false

    private var sliceResults: [SimpleStudioSearchEngine.Result] {
        guard let selectedSliceID else { return [] }
        return SimpleStudioSearchEngine.chartFilterResults(
            sliceID: selectedSliceID,
            snapshot: store.snapshot,
            format: appSettingsManager.format
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: BuxTokens.block) {
                BuxSectionHeader(title: "This month")

                BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
                    VStack(spacing: BuxTokens.section) {
                        SimpleStudioDonutChart(
                            slices: display.monthSlices,
                            height: 200,
                            selectedSliceID: $selectedSliceID
                        )
                        SimpleStudioChartLegend(
                            slices: display.monthSlices,
                            selectedSliceID: $selectedSliceID
                        )

                        BuxCatalogText.text("Tap the chart or a row below to filter")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        if selectedSliceID != nil {
                            Button(BuxCatalogLabel.string("Clear filter", locale: appSettingsManager.interfaceLocale)) {
                                withAnimation(SimpleStudioDonutChart.selectionAnimation) {
                                    selectedSliceID = nil
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        }
                    }
                }

                if let selectedSliceID {
                    filteredResultsSection(sliceID: selectedSliceID)
                }

                SimpleStudioWaitingSection(
                    items: display.waitingItems,
                    onMarkPaid: { id in
                        pendingMarkPaidId = id
                        showMarkPaidConfirmation = true
                    },
                    onRemind: { item in
                        shareReminder(for: item)
                    },
                    onTap: { id in
                        openEntry(for: id)
                    }
                )

                if !display.iOweItems.isEmpty {
                    SimpleStudioIOweSection(
                        items: display.iOweItems,
                        onMarkSettled: { id in
                            pendingMarkPaidId = id
                            showMarkPaidConfirmation = true
                        },
                        onTap: { id in
                            openEntry(for: id)
                        }
                    )
                }

                if !display.jobPockets.isEmpty {
                    VStack(alignment: .leading, spacing: BuxTokens.tight) {
                        BuxSectionHeader(title: "Job pockets")

                        ForEach(display.jobPockets) { pocket in
                            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(pocket.customerName)
                                                .font(.system(size: 15, weight: .bold))
                                            Text(pocket.jobLabel)
                                                .font(.system(size: 11, weight: .medium))
                                                .buxLabelSecondary()
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(
                                                BuxLocalizedString.format(
                                                    "Keep %@",
                                                    locale: appSettingsManager.interfaceLocale,
                                                    pocket.keptFormatted
                                                )
                                            )
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.green)
                                            Text(
                                                BuxLocalizedString.format(
                                                    "Agreed %@",
                                                    locale: appSettingsManager.interfaceLocale,
                                                    pocket.agreedFormatted
                                                )
                                            )
                                                .font(.system(size: 10, weight: .medium))
                                                .buxLabelSecondary()
                                        }
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.orange.opacity(0.15))
                                            Capsule()
                                                .fill(Color.green.opacity(0.85))
                                                .frame(width: geo.size.width * pocket.keptFraction)
                                        }
                                    }
                                    .frame(height: 8)
                                    HStack {
                                        Text(
                                            BuxLocalizedString.format(
                                                "Spent %@",
                                                locale: appSettingsManager.interfaceLocale,
                                                pocket.spentFormatted
                                            )
                                        )
                                        Spacer()
                                        Text(
                                            BuxLocalizedString.format(
                                                "Paid %@",
                                                locale: appSettingsManager.interfaceLocale,
                                                pocket.paidFormatted
                                            )
                                        )
                                        Spacer()
                                        Text(
                                            BuxLocalizedString.format(
                                                "Waiting %@",
                                                locale: appSettingsManager.interfaceLocale,
                                                pocket.waitingFormatted
                                            )
                                        )
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .buxLabelSecondary()
                                    Text(
                                        BuxLocalizedString.format(
                                            "When paid: keep %@",
                                            locale: appSettingsManager.interfaceLocale,
                                            pocket.projectedKeptFormatted
                                        )
                                    )
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                }
                            }
                        }
                    }
                }

                SimpleStudioTaxSection(tile: display.taxTile)
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.vertical, BuxTokens.section)
            .environment(\.studioEnhancedTint, true)
        }
        .background {
            if !usesPadSplitLayout {
                themeManager.screenBackground(for: colorScheme)
            }
        }
        .buxCatalogNavigationTitle("My money")
        .buxInterfaceLocale()
        .navigationBarTitleDisplayMode(.large)
        .alert(markPaidAlertTitle, isPresented: $showMarkPaidConfirmation) {
            Button(markPaidConfirmLabel) {
                guard let id = pendingMarkPaidId else { return }
                store.markEntryPaid(id: id)
                if store.invoices.contains(where: { $0.id == id }) {
                    store.markInvoicePaid(id: id)
                }
                pendingMarkPaidId = nil
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {
                pendingMarkPaidId = nil
            }
        } message: {
            Text(markPaidAlertMessage)
        }
        .sheet(item: $detailDestination) { destination in
            switch destination {
            case .entry(let id):
                SimpleStudioEntryDetailView(store: store, entryId: id)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            case .invoice(let id):
                SimpleStudioInvoiceDetailView(store: store, invoiceId: id)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            case .person(let id):
                NavigationStack {
                    SimpleStudioPersonDetailView(store: store, customerId: id)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(studioStore)
                }
                .buxStudioSheetContent()
            }
        }
    }

    @ViewBuilder
    private func filteredResultsSection(sliceID: String) -> some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: filterTitle(for: sliceID))

            if sliceResults.isEmpty {
                BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                    Text(emptyFilterMessage(for: sliceID))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(sliceResults.prefix(8).enumerated()), id: \.element.id) { index, result in
                            if index > 0 { Divider().padding(.leading, BuxTokens.section) }
                            filteredRow(result)
                        }
                    }
                }
            }
        }
    }

    private func filteredRow(_ result: SimpleStudioSearchEngine.Result) -> some View {
        Button {
            switch result.kind {
            case .entry(let id): detailDestination = .entry(id)
            case .invoice(let id): detailDestination = .invoice(id)
            case .person(let id): detailDestination = .person(id)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(result.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let amount = result.amountFormatted {
                    Text(amount)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .padding(.horizontal, BuxTokens.section)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func filterTitle(for sliceID: String) -> String {
        switch sliceID {
        case "made": return SimpleStudioCopy.line("Made this month", locale: locale)
        case "spent": return SimpleStudioCopy.line("Spent this month", locale: locale)
        case "waiting": return SimpleStudioCopy.line("Waiting on", locale: locale)
        case "owe": return SimpleStudioCopy.line("You owe", locale: locale)
        default: return SimpleStudioCopy.line("Filtered", locale: locale)
        }
    }

    private func emptyFilterMessage(for sliceID: String) -> String {
        switch sliceID {
        case "waiting":
            return SimpleStudioCopy.line("Nothing waiting right now — nice.", locale: locale)
        case "owe":
            return SimpleStudioCopy.line("You don't owe anyone in your ledger.", locale: locale)
        case "made":
            return SimpleStudioCopy.line("No income logged this month yet.", locale: locale)
        case "spent":
            return SimpleStudioCopy.line("No spending logged this month yet.", locale: locale)
        default:
            return SimpleStudioCopy.line("No matches for this slice.", locale: locale)
        }
    }

    private var markPaidAlertTitle: String {
        guard let id = pendingMarkPaidId else {
            return SimpleStudioCopy.line("Mark as paid?", locale: locale)
        }
        return display.iOweItems.contains { $0.id == id }
            ? SimpleStudioCopy.line("Mark as settled?", locale: locale)
            : SimpleStudioCopy.line("Mark as paid?", locale: locale)
    }

    private var markPaidConfirmLabel: String {
        guard let id = pendingMarkPaidId else {
            return SimpleStudioCopy.line("Mark paid", locale: locale)
        }
        return display.iOweItems.contains { $0.id == id }
            ? SimpleStudioCopy.line("Mark settled", locale: locale)
            : SimpleStudioCopy.line("Mark paid", locale: locale)
    }

    private var markPaidAlertMessage: String {
        guard let id = pendingMarkPaidId else {
            return SimpleStudioCopy.line("This will mark the balance as fully paid.", locale: locale)
        }
        return display.iOweItems.contains { $0.id == id }
            ? SimpleStudioCopy.line("This clears what you owe them.", locale: locale)
            : SimpleStudioCopy.line("This will mark the balance as fully paid.", locale: locale)
    }

    private func openEntry(for id: UUID) {
        if store.entry(id: id) != nil {
            detailDestination = .entry(id)
        } else if store.invoice(id: id) != nil {
            detailDestination = .invoice(id)
        }
    }

    private func shareReminder(for item: SimpleWaitingItem) {
        let phone = store.customer(named: item.customerName)?.phone
        let businessName = studioStore.profile.businessName.isEmpty
            ? SimpleStudioCopy.line("Your Work", locale: locale)
            : studioStore.profile.businessName
        SimpleStudioReminderHelper.presentContactOptions(
            SimpleStudioReminderHelper.Payload(
                customerName: item.customerName,
                amountFormatted: item.amountFormatted,
                jobLabel: item.jobLabel,
                businessName: businessName,
                phone: phone,
                accent: themeManager.contrastAccentColor(for: colorScheme)
            ),
            openURL: openURL
        )
    }
}
