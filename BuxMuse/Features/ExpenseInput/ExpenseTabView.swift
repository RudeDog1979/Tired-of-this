//
//  ExpenseTabView.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Unified scroll: hero carousel + transaction list. Monzo-style top toolbar + nav search.
//

import SwiftUI

struct ExpenseTabView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var brain: BuxMuseBrain
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @StateObject private var listModel = ExpensesViewModel()
    @State private var activeSheet: ExpenseSheetMode?
    @State private var categorySheetTransaction: Transaction?
    @State private var listAppeared = false
    @State private var removedRowIds: Set<UUID> = []
    @State private var expandedExpenseId: UUID?
    @State private var selectedRecord: ExpenseRecord?
    @State private var noteRecord: ExpenseRecord?
    @State private var noteDraft = ""
    @State private var showAdvancedFilters = false
    @State private var showCategoryManager = false
    @State private var showMerchantManager = false

    private var allRecords: [ExpenseRecord] {
        brain.expenseRecords
    }

    private var filteredRecords: [ExpenseRecord] {
        listModel.filteredRecords(from: allRecords)
    }

    private var expenseDataToken: String {
        brain.expenseRecords.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }.joined(separator: "|")
    }

    private var expenseListRowInsets: EdgeInsets {
        EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
    }

    private var expenseHeroRowInsets: EdgeInsets {
        EdgeInsets(
            top: BuxLayout.tight,
            leading: 0,
            bottom: BuxLayout.expenseHeroShadowBleed,
            trailing: 0
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                BuxHeroMeshBackground()

                Group {
                    if allRecords.isEmpty {
                        emptyState
                    } else {
                        unifiedExpenseList
                    }
                }
            }
            .navigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.large)
            .buxRootNavigationChrome()
            .toolbar { expenseToolbar }
            .modifier(ExpenseSearchModifier(
                searchText: $listModel.filters.searchText,
                searchScope: $listModel.searchScope,
                isSearchPresented: $navigationCoordinator.isExpenseSearchPresented
            ))
        }
        .environment(\.expensesEnhancedTint, true)
        .buxReportsContainerWidth()
        .onAppear {
            listModel.reloadCatalog(brain: brain)
            refreshExpenseListDisplay()
            listAppeared = true
        }
        .onDisappear {
            navigationCoordinator.dismissExpenseSearch()
        }
        .onChange(of: expenseDataToken) { _, _ in
            listModel.reloadCatalog(brain: brain)
            refreshExpenseListDisplay()
        }
        .onChange(of: listModel.filters) { _, _ in
            refreshExpenseListDisplay()
        }
        .onChange(of: listModel.searchScope) { _, _ in
            listModel.applySearchScope()
            refreshExpenseListDisplay()
        }
        .onChange(of: appSettingsManager.selectedCurrency.id) { _, _ in
            refreshExpenseListDisplay()
        }
        .sheet(item: $activeSheet) { mode in
            AddExpenseSheet(brain: brain, settingsManager: appSettingsManager, mode: mode)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
                .environment(\.expensesEnhancedTint, true)
        }
        .sheet(item: $categorySheetTransaction) { tx in
            ExpenseCategorySheet(transaction: tx) { category, categoryId in
                changeCategory(tx, to: category, categoryId: categoryId)
            }
            .environmentObject(themeManager)
            .environmentObject(brain)
            .environment(\.expensesEnhancedTint, true)
        }
        .sheet(isPresented: $showAdvancedFilters) {
            ExpenseFilterSheet(
                filters: $listModel.filters,
                categories: listModel.categories,
                merchants: listModel.merchants,
                heatZones: listModel.availableHeatZones
            )
            .environmentObject(themeManager)
            .environmentObject(brain)
            .environment(\.expensesEnhancedTint, true)
        }
        .sheet(isPresented: $showCategoryManager) {
            ExpenseCategoryListSheet()
                .environmentObject(themeManager)
                .environmentObject(brain)
                .environment(\.expensesEnhancedTint, true)
        }
        .sheet(isPresented: $showMerchantManager) {
            ExpenseMerchantListSheet()
                .environmentObject(themeManager)
                .environmentObject(brain)
                .environment(\.expensesEnhancedTint, true)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(item: $noteRecord) { record in
            ExpenseNoteSheet(
                merchantName: record.name,
                notes: $noteDraft,
                onSave: {
                    try brain.updateExpenseNotes(id: record.id, notes: noteDraft.isEmpty ? nil : noteDraft)
                }
            )
            .environmentObject(themeManager)
            .environment(\.expensesEnhancedTint, true)
            .onAppear {
                noteDraft = record.notes ?? ""
            }
        }
        .fullScreenCover(item: $selectedRecord) { record in
            ExpenseDetailView(record: record, brain: brain, settingsManager: appSettingsManager) {
                listModel.reloadCatalog(brain: brain)
                refreshExpenseListDisplay()
            }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environment(\.expensesEnhancedTint, true)
            .buxThemedPresentation()
        }
    }

    @ToolbarContentBuilder
    private var expenseToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !allRecords.isEmpty {
                expenseFilterMenu

                Button {
                    showCategoryManager = true
                } label: {
                    BuxToolbarIcon(systemName: "tag")
                }
                .accessibilityLabel("Manage categories")

                Button {
                    showMerchantManager = true
                } label: {
                    BuxToolbarIcon(systemName: "building.2")
                }
                .accessibilityLabel("Manage merchants")
            }

            Button {
                withAnimation(.buxSnap) {
                    activeSheet = .add
                }
            } label: {
                BuxToolbarIcon(systemName: "plus")
            }
            .accessibilityLabel("Add expense")
        }
    }

    private var expenseFilterMenu: some View {
        Menu {
            Section("Quick filters") {
                Toggle("Recurring only", isOn: $listModel.filters.recurringOnly)
                Toggle("Subscription-like", isOn: $listModel.filters.subscriptionLikeOnly)
                Toggle("Refunds only", isOn: $listModel.filters.refundsOnly)
            }

            if !listModel.categories.isEmpty {
                Menu("Category") {
                    Button("Any category") { listModel.filters.categoryId = nil }
                    ForEach(listModel.categories) { category in
                        Button(category.name) {
                            listModel.filters.categoryId = category.id
                        }
                    }
                }
            }

            if !listModel.merchants.isEmpty {
                Menu("Merchant") {
                    Button("Any merchant") { listModel.filters.merchantId = nil }
                    ForEach(listModel.merchants.prefix(16)) { merchant in
                        Button(merchant.name) {
                            listModel.filters.merchantId = merchant.id
                        }
                    }
                }
            }

            if !listModel.availableHeatZones.isEmpty {
                Menu("Heat zone") {
                    Button("Any zone") { listModel.filters.heatZoneBucket = nil }
                    ForEach(listModel.availableHeatZones, id: \.self) { zone in
                        Button(zone.replacingOccurrences(of: "_", with: " ")) {
                            listModel.filters.heatZoneBucket = zone
                        }
                    }
                }
            }

            Button("Advanced filters…") {
                showAdvancedFilters = true
            }

            if listModel.filters.isActive {
                Button("Clear filters", role: .destructive) {
                    listModel.filters = ExpenseFilterState()
                    listModel.searchScope = .all
                }
            }
        } label: {
            BuxToolbarIcon(
                systemName: listModel.filters.isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityLabel("Filter expenses")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No expenses logged yet", systemImage: "creditcard")
        } description: {
            Text("Your financial details are kept strictly offline and secure inside the BuxMuse Brain.")
        } actions: {
            BuxButton(
                title: "Add expense",
                systemImage: "plus.circle.fill",
                role: .primary,
                size: .regular
            ) {
                activeSheet = .add
            }
        }
        .buxStaggeredReveal(index: 0, isVisible: listAppeared)
    }

    private var unifiedExpenseList: some View {
        let display = brain.expenseInteractionSnapshot
        let showHero = !display.sections.isEmpty || display.header.totalSpent != 0

        return List {
            if showHero {
                Section {
                    ExpensesTopCarousel(
                        header: display.header,
                        summary: display.summary,
                        formatAmount: { appSettingsManager.format($0) }
                    )
                    .environmentObject(themeManager)
                    .listRowInsets(expenseHeroRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(display.sections) { section in
                Section {
                    ForEach(section.expenses) { expense in
                        if let record = filteredRecords.first(where: { $0.id == expense.id }) {
                            expenseRowContent(expense: expense, record: record)
                        }
                    }
                } header: {
                    HStack {
                        Text(section.title.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                            .kerning(1.2)

                        if let insight = section.microInsight {
                            Spacer()
                            InlineInsightView(text: insight)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .buxListContentMargins()
        .buxCustomTabBarScrollClearance()
    }

    @ViewBuilder
    private func expenseRowContent(expense: ExpenseRowDisplay, record: ExpenseRecord) -> some View {
        Button(action: {
            withAnimation(.buxSnap) {
                selectedRecord = record
            }
        }) {
            ExpandableExpenseCard(expense: expense, expandedId: $expandedExpenseId)
                .environmentObject(themeManager)
                .contentShape(Rectangle())
        }
        .buttonStyle(BuxMicroShrinkStyle())
            .listRowInsets(expenseListRowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    withAnimation(.buxSnap) {
                        activeSheet = .edit(record.toTransaction())
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(themeManager.current.accentColor)

                Button {
                    categorySheetTransaction = record.toTransaction()
                } label: {
                    Label("Category", systemImage: "tag")
                }
                .tint(.orange)

                Button {
                    duplicateExpense(record)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .tint(Color(red: 90/255, green: 85/255, blue: 245/255))

                Button(role: .destructive) {
                    deleteExpense(record)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button {
                    activeSheet = .edit(record.toTransaction())
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    noteDraft = record.notes ?? ""
                    noteRecord = record
                } label: {
                    Label("Add note", systemImage: "note.text")
                }
                Button {
                    categorySheetTransaction = record.toTransaction()
                } label: {
                    Label("Change category", systemImage: "tag")
                }
                Button {
                    duplicateExpense(record)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Divider()
                Button(role: .destructive) {
                    deleteExpense(record)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private func refreshExpenseListDisplay() {
        brain.updateExpenseInteractionSnapshot(
            records: filteredRecords,
            currency: appSettingsManager.selectedCurrency
        )
    }

    private func duplicateExpense(_ record: ExpenseRecord) {
        do {
            _ = try brain.duplicateExpense(record.toTransaction())
            refreshExpenseListDisplay()
        } catch {
            print("Duplicate failed: \(error)")
        }
    }

    private func deleteExpense(_ record: ExpenseRecord) {
        _ = withAnimation(.buxSnap) {
            removedRowIds.insert(record.id)
        }
        do {
            try brain.deleteExpense(id: record.id)
            removedRowIds.remove(record.id)
        } catch {
            removedRowIds.remove(record.id)
            print("Delete failed: \(error)")
        }
    }

    private func changeCategory(_ tx: Transaction, to category: TransactionCategory, categoryId: UUID?) {
        do {
            try brain.changeExpenseCategory(id: tx.id, category: category, categoryId: categoryId)
        } catch {
            print("Category change failed: \(error)")
        }
    }
}

// MARK: - Navigation-owned search (Monzo / Apple Music pattern)

private struct ExpenseSearchModifier: ViewModifier {
    @Binding var searchText: String
    @Binding var searchScope: ExpenseSearchScope
    @Binding var isSearchPresented: Bool

    func body(content: Content) -> some View {
        content
            .modifier(BuxDrawerSearchModifier(
                searchText: $searchText,
                prompt: "Search merchants, notes…",
                isPresented: $isSearchPresented
            ))
            .searchScopes($searchScope) {
                ForEach(ExpenseSearchScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
    }
}
