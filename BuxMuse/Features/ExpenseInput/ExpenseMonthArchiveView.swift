//
//  ExpenseMonthArchiveView.swift
//  BuxMuse
//
//  Previous-month expense archive — pushed from the main expense list.
//

import SwiftUI

struct ExpenseArchiveMonth: Hashable {
    let monthStart: Date
}

struct ExpenseMonthArchiveView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry
    @Environment(\.openWindow) private var openWindow
    @Environment(\.buxPadExpenseUsesSplitLayout) private var usesPadSplitLayout

    let monthStart: Date
    let selectedExpenseId: UUID?
    let padNavigationBrain: BuxPadNavigationBrain?

    @Binding var expandedExpenseId: UUID?
    @Binding var activeSheet: ExpenseSheetMode?
    @Binding var categorySheetTransaction: Transaction?
    @Binding var noteRecord: ExpenseRecord?
    @Binding var noteDraft: String
    @Binding var padDeleteConfirmRecord: ExpenseRecord?

    let onOpenDetail: (ExpenseRecord) -> Void
    let onDuplicate: (ExpenseRecord) -> Void

    @State private var collapsedDays: Set<Date> = []
    @State private var groupedRows: [Date: [ExpenseRowDisplay]] = [:]
    @State private var recordsById: [UUID: ExpenseRecord] = [:]

    private let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .none
        return fmt
    }()

    private let monthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt
    }()

    private var monthLoadToken: String {
        "\(monthStart.timeIntervalSince1970)-\(brain.expenseDataRevision)"
    }

    private var sortedDays: [Date] {
        groupedRows.keys.sorted(by: >)
    }

    private var monthTitle: String {
        monthFormatter.locale = appSettingsManager.interfaceLocale
        return monthFormatter.string(from: monthStart)
    }

    private var expenseListRowInsets: EdgeInsets {
        EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(sortedDays, id: \.self) { day in
                    ExpenseDaySectionView(
                        day: day,
                        rows: groupedRows[day] ?? [],
                        dayTitle: dayHeaderTitle(day),
                        totalSpent: dailySpendTotal(day, groupedRows[day] ?? []),
                        collapsedDays: $collapsedDays,
                        recordsById: recordsById,
                        selectedExpenseId: selectedExpenseId,
                        padNavigationBrain: padNavigationBrain,
                        expandedExpenseId: $expandedExpenseId,
                        activeSheet: $activeSheet,
                        categorySheetTransaction: $categorySheetTransaction,
                        noteRecord: $noteRecord,
                        noteDraft: $noteDraft,
                        padDeleteConfirmRecord: $padDeleteConfirmRecord,
                        rowInsets: expenseListRowInsets,
                        onOpenDetail: onOpenDetail,
                        onDuplicate: onDuplicate
                    )
                }
            }
            .padding(.top, BuxTokens.tight)
            .buxPadExpenseCardRail()
            .environment(\.textCase, nil)
        }
        .scrollDismissesKeyboard(.interactively)
        .modifier(ExpensePadSplitScrollChromeModifier())
        .background {
            BuxLandingTintBackground()
                .ignoresSafeArea()
        }
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.inline)
        .buxDetailNavigationChrome()
        .task(id: monthLoadToken) {
            let records = await brain.fetchArchiveMonthRecords(monthStart: monthStart)
            let rows = brain.makeExpenseRowDisplays(from: records)
            let calendar = Calendar.current
            recordsById = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
            groupedRows = Dictionary(grouping: rows, by: { calendar.startOfDay(for: $0.date) })
        }
    }

    private func dayHeaderTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return BuxLocalizedString.string("Today", locale: appSettingsManager.interfaceLocale)
        }
        if calendar.isDateInYesterday(date) {
            return BuxLocalizedString.string("Yesterday", locale: appSettingsManager.interfaceLocale)
        }
        dayFormatter.locale = appSettingsManager.interfaceLocale
        return dayFormatter.string(from: date)
    }

    private func dailySpendTotal(_ day: Date, _ rows: [ExpenseRowDisplay]) -> Double {
        rows.reduce(0.0) { sum, row in
            if let record = recordsById[row.id], record.isSpendingOutflow {
                return sum + record.spendingAmountDouble
            }
            return sum
        }
    }
}

struct ExpensePendingWalletSectionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let rows: [ExpenseRowDisplay]
    let recordsById: [UUID: ExpenseRecord]
    let selectedExpenseId: UUID?
    let padNavigationBrain: BuxPadNavigationBrain?

    @Binding var expandedExpenseId: UUID?
    @Binding var activeSheet: ExpenseSheetMode?
    @Binding var categorySheetTransaction: Transaction?
    @Binding var noteRecord: ExpenseRecord?
    @Binding var noteDraft: String
    @Binding var padDeleteConfirmRecord: ExpenseRecord?

    let rowInsets: EdgeInsets
    let onOpenDetail: (ExpenseRecord) -> Void
    let onDuplicate: (ExpenseRecord) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(BuxLocalizedString.string("Pending", locale: appSettingsManager.interfaceLocale))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))

                Spacer()

                Text("\(rows.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme).opacity(0.65))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)

            ForEach(rows) { expense in
                if let record = recordsById[expense.id] {
                    ExpenseLedgerRowView(
                        expense: expense,
                        record: record,
                        selectedExpenseId: selectedExpenseId,
                        padNavigationBrain: padNavigationBrain,
                        expandedExpenseId: $expandedExpenseId,
                        activeSheet: $activeSheet,
                        categorySheetTransaction: $categorySheetTransaction,
                        noteRecord: $noteRecord,
                        noteDraft: $noteDraft,
                        padDeleteConfirmRecord: $padDeleteConfirmRecord,
                        rowInsets: rowInsets,
                        onOpenDetail: onOpenDetail,
                        onDuplicate: onDuplicate
                    )
                }
            }
        }
    }
}

struct ExpenseDaySectionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let day: Date
    let rows: [ExpenseRowDisplay]
    let dayTitle: String
    let totalSpent: Double
    @Binding var collapsedDays: Set<Date>
    let recordsById: [UUID: ExpenseRecord]
    let selectedExpenseId: UUID?
    let padNavigationBrain: BuxPadNavigationBrain?

    @Binding var expandedExpenseId: UUID?
    @Binding var activeSheet: ExpenseSheetMode?
    @Binding var categorySheetTransaction: Transaction?
    @Binding var noteRecord: ExpenseRecord?
    @Binding var noteDraft: String
    @Binding var padDeleteConfirmRecord: ExpenseRecord?

    let rowInsets: EdgeInsets
    let onOpenDetail: (ExpenseRecord) -> Void
    let onDuplicate: (ExpenseRecord) -> Void

    private var isCollapsed: Bool {
        collapsedDays.contains(day)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.buxSnap) {
                    if collapsedDays.contains(day) {
                        collapsedDays.remove(day)
                    } else {
                        collapsedDays.insert(day)
                    }
                }
            } label: {
                HStack {
                    Text(dayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))

                    Spacer()

                    if totalSpent > 0 {
                        Text(appSettingsManager.format(totalSpent))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme).opacity(0.85))
                            .padding(.trailing, 4)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme).opacity(0.5))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
                .contentShape(Rectangle())
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                ForEach(rows) { expense in
                    if let record = recordsById[expense.id] {
                        ExpenseLedgerRowView(
                            expense: expense,
                            record: record,
                            selectedExpenseId: selectedExpenseId,
                            padNavigationBrain: padNavigationBrain,
                            expandedExpenseId: $expandedExpenseId,
                            activeSheet: $activeSheet,
                            categorySheetTransaction: $categorySheetTransaction,
                            noteRecord: $noteRecord,
                            noteDraft: $noteDraft,
                            padDeleteConfirmRecord: $padDeleteConfirmRecord,
                            rowInsets: rowInsets,
                            onOpenDetail: onOpenDetail,
                            onDuplicate: onDuplicate
                        )
                    }
                }
            }
        }
    }
}

struct ExpenseLedgerRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine
    @EnvironmentObject private var expenseTabStore: ExpenseTabStore
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry
    @Environment(\.openWindow) private var openWindow
    @Environment(\.buxPadExpenseUsesSplitLayout) private var usesPadSplitLayout

    let expense: ExpenseRowDisplay
    let record: ExpenseRecord
    let selectedExpenseId: UUID?
    let padNavigationBrain: BuxPadNavigationBrain?

    @Binding var expandedExpenseId: UUID?
    @Binding var activeSheet: ExpenseSheetMode?
    @Binding var categorySheetTransaction: Transaction?
    @Binding var noteRecord: ExpenseRecord?
    @Binding var noteDraft: String
    @Binding var padDeleteConfirmRecord: ExpenseRecord?

    @ObservedObject private var settingsStore = SettingsStore.shared
    @State private var showLinkPaycheckSheet = false
    @State private var showLinkDebtPaymentSheet = false

    let rowInsets: EdgeInsets
    let onOpenDetail: (ExpenseRecord) -> Void
    let onDuplicate: (ExpenseRecord) -> Void

    private var linkedDebt: Debt? {
        debtEngine.linkedDebt(for: record.id)
    }

    private var displayExpense: ExpenseRowDisplay {
        var row = expense
        row.linkedDebtName = linkedDebt?.name
        return row
    }

    private var canLinkToDebt: Bool {
        settingsStore.consumerDebtEnabled
            && record.isSpendingOutflow
            && linkedDebt == nil
            && !debtEngine.activeDebts.isEmpty
    }

    var body: some View {
        ExpandableExpenseCard(
            expense: displayExpense,
            record: record,
            expandedId: $expandedExpenseId,
            onOpenDetail: {
                withAnimation(.buxSnap) {
                    onOpenDetail(record)
                }
            }
        ) {
            withAnimation(.buxSnap) {
                activeSheet = .edit(record.toTransaction())
            }
        }
        .environmentObject(themeManager)
        .environmentObject(brain)
        .padding(rowInsets)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if record.isSpendingOutflow, record.bridgeKind == nil {
                Button {
                    withAnimation(.buxSnap) {
                        activeSheet = .editWithCategorySplit(record.toTransaction())
                    }
                } label: {
                    Label(BuxCatalogLabel.string("Split categories", locale: appSettingsManager.interfaceLocale), systemImage: "square.split.2x1")
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
            }
        }
        .buxPadExpenseRowInteractions(recordId: record.id, enabled: BuxPadIdiom.isPad && usesPadSplitLayout)
        .background {
            if usesPadSplitLayout, selectedExpenseId == record.id {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(themeManager.contrastAccentColor(for: colorScheme).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                themeManager.contrastAccentColor(for: colorScheme).opacity(0.35),
                                lineWidth: 1.5
                            )
                    )
            }
        }
        .contextMenu {
            if record.amountValue > 0, !record.isSalaryTagged {
                Button {
                    showLinkPaycheckSheet = true
                } label: {
                    Label(
                        BuxCatalogLabel.string("Link as paycheck", locale: appSettingsManager.interfaceLocale),
                        systemImage: "briefcase.fill"
                    )
                }
            }

            if canLinkToDebt {
                Button {
                    showLinkDebtPaymentSheet = true
                } label: {
                    Label(
                        BuxCatalogLabel.string("Log as debt payment", locale: appSettingsManager.interfaceLocale),
                        systemImage: "creditcard.and.123"
                    )
                }
            }

            if usesPadSplitLayout, let padNavigationBrain, selectedExpenseId != record.id {
                Button {
                    padNavigationBrain.selectExpense(record.id)
                } label: {
                    Label(BuxCatalogLabel.string("Select", locale: appSettingsManager.interfaceLocale), systemImage: "checkmark.circle")
                }
            }

            Button {
                noteDraft = record.notes ?? ""
                noteRecord = record
            } label: {
                Label(BuxCatalogLabel.string("Note", locale: appSettingsManager.interfaceLocale), systemImage: "note.text")
            }

            Button {
                withAnimation(.buxSnap) {
                    activeSheet = .edit(record.toTransaction())
                }
            } label: {
                Label(BuxCatalogLabel.string("Edit", locale: appSettingsManager.interfaceLocale), systemImage: "pencil")
            }

            Button {
                categorySheetTransaction = record.toTransaction()
            } label: {
                Label(BuxCatalogLabel.string("Category", locale: appSettingsManager.interfaceLocale), systemImage: "tag")
            }

            if record.isSpendingOutflow, record.bridgeKind == nil {
                Button {
                    withAnimation(.buxSnap) {
                        activeSheet = .editWithCategorySplit(record.toTransaction())
                    }
                } label: {
                    Label(BuxCatalogLabel.string("Split categories", locale: appSettingsManager.interfaceLocale), systemImage: "square.split.2x1")
                }
            }

            Button {
                onDuplicate(record)
            } label: {
                Label(BuxCatalogLabel.string("Duplicate", locale: appSettingsManager.interfaceLocale), systemImage: "plus.square.on.square")
            }

            Button(role: .destructive) {
                padDeleteConfirmRecord = record
            } label: {
                Label(BuxCatalogLabel.string("Delete", locale: appSettingsManager.interfaceLocale), systemImage: "trash")
            }

            if usesPadSplitLayout, let padNavigationBrain, !padSceneBrainRegistry.isAuxiliary(padNavigationBrain) {
                Divider()
                Button {
                    padNavigationBrain.selectExpense(record.id)
                    BuxPadWindowLauncher.openExpenseWindow(
                        from: padNavigationBrain,
                        registry: padSceneBrainRegistry,
                        openWindow: openWindow
                    )
                } label: {
                    Label(
                        BuxCatalogLabel.string("Open in New Window", locale: appSettingsManager.interfaceLocale),
                        systemImage: "macwindow.on.rectangle"
                    )
                }
            }
        }
        .sheet(isPresented: $showLinkPaycheckSheet) {
            LinkPaycheckSheet(record: record)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .buxThemedSheetContent()
                .onDisappear {
                    expenseTabStore.reloadFromLedger(currency: appSettingsManager.selectedCurrency)
                }
        }
        .sheet(isPresented: $showLinkDebtPaymentSheet) {
            LinkDebtPaymentSheet(record: record, debtEngine: debtEngine)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(debtEngine)
                .environmentObject(brain)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .buxThemedSheetContent()
                .onDisappear {
                    expenseTabStore.reloadFromLedger(currency: appSettingsManager.selectedCurrency)
                }
        }
    }
}

struct ExpenseMonthFolderCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let monthTitle: String
    let transactionCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(themeManager.contrastAccentColor(for: colorScheme).opacity(0.12))
                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(monthTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)

                Text(
                    BuxLocalizedString.format(
                        "%lld transactions",
                        locale: appSettingsManager.interfaceLocale,
                        Int64(transactionCount)
                    )
                )
                .font(.footnote)
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .frame(width: 28, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .modifier(ExpenseListCardChromeModifier(cornerRadius: 16))
        .environment(\.textCase, nil)
    }
}
