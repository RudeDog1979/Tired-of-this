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
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                Group {
                    if allRecords.isEmpty {
                        emptyStateWithWorkspaceAccess
                    } else {
                        unifiedExpenseList
                    }
                }
            }
            .buxCatalogNavigationTitle("Expenses")
            .navigationBarTitleDisplayMode(.large)
            .buxRootNavigationChrome()
            .toolbar { expenseToolbar }
            .modifier(ExpenseSearchModifier(
                searchText: $listModel.filters.searchText,
                searchScope: $listModel.searchScope,
                isSearchPresented: $navigationCoordinator.isExpenseSearchPresented
            ))
        }
        .buxInterfaceLocale()
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
        .onChange(of: HustleManager.shared.selectedHustleId) { _, _ in
            refreshExpenseListDisplay()
        }
        .onChange(of: SettingsStore.shared.sideHustleMatrixEnabled) { _, _ in
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
            .buxThemedSheetContent()
        }
        .sheet(isPresented: $showAdvancedFilters) {
            ExpenseFilterSheet(
                filters: $listModel.filters,
                categories: listModel.categories,
                merchants: listModel.merchants,
                heatZones: listModel.availableHeatZones
            )
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environmentObject(brain)
            .environment(\.expensesEnhancedTint, true)
            .buxThemedSheetContent()
        }
        .sheet(isPresented: $showCategoryManager) {
            ExpenseCategoryListSheet()
                .environmentObject(themeManager)
                .environmentObject(brain)
                .environment(\.expensesEnhancedTint, true)
                .buxThemedSheetContent()
        }
        .sheet(isPresented: $showMerchantManager) {
            ExpenseMerchantListSheet()
                .environmentObject(themeManager)
                .environmentObject(brain)
                .environment(\.expensesEnhancedTint, true)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
                .buxThemedSheetContent()
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
            .buxThemedSheetContent()
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
            .buxThemedSheetContent()
        }
    }

    @ToolbarContentBuilder
    private var expenseToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !allRecords.isEmpty {
                expenseFilterMenu

                BuxNavIconButton(
                    systemName: "tag",
                    accessibilityLabel: "Manage categories",
                    action: { showCategoryManager = true }
                )

                BuxNavIconButton(
                    systemName: "building.2",
                    accessibilityLabel: "Manage merchants",
                    action: { showMerchantManager = true }
                )
            }

            BuxNavIconButton(
                systemName: "plus",
                accessibilityLabel: "Add expense",
                useAccent: true,
                action: {
                    withAnimation(.buxSnap) {
                        activeSheet = .add
                    }
                }
            )
        }
    }

    private var expenseFilterMenu: some View {
        let locale = appSettingsManager.interfaceLocale
        return Menu {
            Section {
                Toggle(isOn: $listModel.filters.recurringOnly) {
                    BuxCatalogText.text("Recurring only")
                }
                Toggle(isOn: $listModel.filters.subscriptionLikeOnly) {
                    BuxCatalogText.text("Subscription-like")
                }
                Toggle(isOn: $listModel.filters.refundsOnly) {
                    BuxCatalogText.text("Refunds only")
                }
            } header: {
                BuxCatalogText.text("Quick filters")
            }

            if !listModel.categories.isEmpty {
                Menu {
                    Button {
                        listModel.filters.categoryId = nil
                    } label: {
                        BuxCatalogText.text("Any category")
                    }
                    ForEach(listModel.categories) { category in
                        Button(category.name) {
                            listModel.filters.categoryId = category.id
                        }
                    }
                } label: {
                    BuxCatalogText.text("Category")
                }
            }

            if !listModel.merchants.isEmpty {
                Menu {
                    Button {
                        listModel.filters.merchantId = nil
                    } label: {
                        BuxCatalogText.text("Any merchant")
                    }
                    ForEach(listModel.merchants.prefix(16)) { merchant in
                        Button(merchant.name) {
                            listModel.filters.merchantId = merchant.id
                        }
                    }
                } label: {
                    BuxCatalogText.text("Merchant")
                }
            }

            if !listModel.availableHeatZones.isEmpty {
                Menu {
                    Button {
                        listModel.filters.heatZoneBucket = nil
                    } label: {
                        BuxCatalogText.text("Any zone")
                    }
                    ForEach(listModel.availableHeatZones, id: \.self) { zone in
                        Button(BuxHeatZoneCopy.displayName(for: zone, locale: locale)) {
                            listModel.filters.heatZoneBucket = zone
                        }
                    }
                } label: {
                    BuxCatalogText.text("Heat zone")
                }
            }

            Button {
                showAdvancedFilters = true
            } label: {
                BuxCatalogText.text("Advanced filters…")
            }

            if listModel.filters.isActive {
                Button(role: .destructive) {
                    listModel.filters = ExpenseFilterState()
                    listModel.searchScope = .all
                } label: {
                    BuxCatalogText.text("Clear filters")
                }
            }
        } label: {
            BuxToolbarIcon(
                systemName: listModel.filters.isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityLabel(BuxCatalogLabel.string("Filter expenses", locale: locale))
    }

    private var emptyStateWithWorkspaceAccess: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                if SettingsStore.shared.sideHustleMatrixEnabled {
                    HustleSelectorBar()
                        .padding(.bottom, 4)
                }

                if HustleWorkspaceFilter.isFilteringActive {
                    ContentUnavailableView {
                        Label("No expenses in this workspace", systemImage: "rectangle.3.group")
                    } description: {
                        Text(
                            BuxLocalizedString.format(
                                "Pick another workspace above, or add an expense tagged to %@.",
                                locale: appSettingsManager.interfaceLocale,
                                HustleWorkspaceFilter.activeWorkspaceLabel()
                                    ?? BuxLocalizedString.string(
                                        String.LocalizationValue(stringLiteral: "this workspace"),
                                        locale: appSettingsManager.interfaceLocale
                                    )
                            )
                        )
                    } actions: {
                        addExpenseButton
                    }
                } else {
                    ContentUnavailableView {
                        Label("No expenses logged yet", systemImage: "creditcard")
                    } description: {
                        BuxCatalogText.text("Your financial details are kept strictly offline and secure inside the BuxMuse Brain.")
                    } actions: {
                        addExpenseButton
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .buxScrollContentMargins()
        .buxRootScrollEdgeChrome()
        .buxStaggeredReveal(index: 0, isVisible: listAppeared)
    }

    private var addExpenseButton: some View {
        BuxButton(
            title: "Add expense",
            systemImage: "plus.circle.fill",
            role: .primary,
            size: .regular
        ) {
            activeSheet = .add
        }
    }

    private var unifiedExpenseList: some View {
        let display = brain.expenseInteractionSnapshot
        let showHero = !display.sections.isEmpty || display.header.totalSpent != 0

        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if showHero {
                    ExpensesTopCarousel(
                        header: display.header,
                        summary: display.summary,
                        formatAmount: { appSettingsManager.format($0) }
                    )
                    .environmentObject(themeManager)
                    .padding(expenseHeroRowInsets)
                    .padding(.bottom, 16)
                }

                HustleSelectorBar()
                    .padding(.bottom, 4)

                ForEach(display.sections) { section in
                    Section {
                        ForEach(section.expenses) { expense in
                            if let record = filteredRecords.first(where: { $0.id == expense.id }) {
                                expenseRowContent(expense: expense, record: record)
                            }
                        }
                    } header: {
                        HStack {
                            Text(
                                BuxCatalogLabel.string(section.title, locale: appSettingsManager.interfaceLocale)
                                    .uppercased()
                            )
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                .kerning(1.2)

                            Spacer()

                            if let insight = section.microInsight {
                                InlineInsightView(text: insight)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .buxScrollContentMargins()
        .buxRootScrollEdgeChrome()
    }

    @ViewBuilder
    private func expenseRowContent(expense: ExpenseRowDisplay, record: ExpenseRecord) -> some View {
        ExpandableExpenseCard(
            expense: expense,
            record: record,
            expandedId: $expandedExpenseId,
            onOpenDetail: {
                withAnimation(.buxSnap) {
                    selectedRecord = record
                }
            }
        ) {
            withAnimation(.buxSnap) {
                activeSheet = .edit(record.toTransaction())
            }
        }
        .environmentObject(themeManager)
        .environmentObject(brain)
        .padding(expenseListRowInsets)
        .contextMenu {
            Button {
                noteDraft = record.notes ?? ""
                noteRecord = record
            } label: {
                Label("Note", systemImage: "note.text")
            }

            Button {
                withAnimation(.buxSnap) {
                    activeSheet = .edit(record.toTransaction())
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                categorySheetTransaction = record.toTransaction()
            } label: {
                Label("Category", systemImage: "tag")
            }

            Button {
                duplicateExpense(record)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

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
                    Text(
                        BuxCatalogLabel.string(
                            scope.title,
                            locale: BuxInterfaceLocale.currentInterfaceLocale
                        )
                    )
                    .tag(scope)
                }
            }
    }
}
