//
//  SimpleStudioMyMoneyView.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioMyMoneyView: View {
    @Environment(\.colorScheme) private var colorScheme
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

                        Text("Tap the chart or a row below to filter")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        if selectedSliceID != nil {
                            Button("Clear filter") {
                                withAnimation(SimpleStudioDonutChart.selectionAnimation) {
                                    selectedSliceID = nil
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.current.accentColor)
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
                                            Text("Keep \(pocket.keptFormatted)")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.green)
                                            Text("Agreed \(pocket.agreedFormatted)")
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
                                        Text("Spent \(pocket.spentFormatted)")
                                        Spacer()
                                        Text("Paid \(pocket.paidFormatted)")
                                        Spacer()
                                        Text("Waiting \(pocket.waitingFormatted)")
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .buxLabelSecondary()
                                    Text("When paid: keep \(pocket.projectedKeptFormatted)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(themeManager.current.accentColor)
                                }
                            }
                        }
                    }
                }

                SimpleStudioTaxSection(tile: display.taxTile)
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.vertical, BuxTokens.section)
        }
        .background(themeManager.screenBackground(for: colorScheme))
        .navigationTitle("My money")
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
            Button("Cancel", role: .cancel) {
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

    private func filterTitle(for sliceID: String) -> String {
        switch sliceID {
        case "made": return "Made this month"
        case "spent": return "Spent this month"
        case "waiting": return "Waiting on"
        case "owe": return "You owe"
        default: return "Filtered"
        }
    }

    private func emptyFilterMessage(for sliceID: String) -> String {
        switch sliceID {
        case "waiting":
            return "Nothing waiting right now — nice."
        case "owe":
            return "You don't owe anyone in your ledger."
        case "made":
            return "No income logged this month yet."
        case "spent":
            return "No spending logged this month yet."
        default:
            return "No matches for this slice."
        }
    }

    private var markPaidAlertTitle: String {
        guard let id = pendingMarkPaidId else { return "Mark as paid?" }
        return display.iOweItems.contains { $0.id == id } ? "Mark as settled?" : "Mark as paid?"
    }

    private var markPaidConfirmLabel: String {
        guard let id = pendingMarkPaidId else { return "Mark paid" }
        return display.iOweItems.contains { $0.id == id } ? "Mark settled" : "Mark paid"
    }

    private var markPaidAlertMessage: String {
        guard let id = pendingMarkPaidId else {
            return "This will mark the balance as fully paid."
        }
        return display.iOweItems.contains { $0.id == id }
            ? "This clears what you owe them."
            : "This will mark the balance as fully paid."
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
        let businessName = studioStore.profile.businessName.isEmpty ? "Your Work" : studioStore.profile.businessName
        SimpleStudioReminderHelper.presentContactOptions(
            SimpleStudioReminderHelper.Payload(
                customerName: item.customerName,
                amountFormatted: item.amountFormatted,
                jobLabel: item.jobLabel,
                businessName: businessName,
                phone: phone,
                accent: themeManager.current.accentColor
            ),
            openURL: openURL
        )
    }
}
