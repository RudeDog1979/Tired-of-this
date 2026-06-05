//
//  ExpenseTabView.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Unified scroll: hero carousel + transaction list. Floating toolbar + inline search.
//

import SwiftUI

struct ExpenseTabView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var brain: BuxMuseBrain
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    @StateObject private var listModel = ExpensesViewModel()
    @State private var activeSheet: ExpenseSheetMode?
    @State private var categorySheetTransaction: Transaction?
    @State private var listAppeared = false
    @State private var carouselPlayRequest = UUID()
    @State private var carouselPlayedPages: Set<Int> = []
    @State private var carouselPageProgress: [Int: Double] = [:]
    @State private var carouselSessionReady = false
    @State private var lastAnimatedHeroDataToken: String?
    @State private var didEnterBackground = false
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

    /// Fingerprint for hero carousel charts — re-animate only when these values change.
    private var heroDataToken: String {
        let display = brain.expenseInteractionSnapshot
        var parts: [String] = []
        parts.append(String(display.header.totalSpent))
        parts.append(String(display.header.changeVsLastMonth))
        parts.append(String(display.header.monthlyTransactionCount))
        parts.append(display.header.sparklinePoints.map { String(format: "%.4f", $0) }.joined(separator: ","))
        parts.append(display.summary.categoryBreakdown.map { "\($0.0):\(String(format: "%.4f", $0.1))" }.joined(separator: ","))
        parts.append(display.summary.merchantBreakdown.map { "\($0.0):\(String(format: "%.4f", $0.1))" }.joined(separator: ","))
        parts.append(display.summary.trendPoints.map { String(format: "%.4f", $0) }.joined(separator: ","))
        return parts.joined(separator: "|")
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

    /// Search or filters active — hero collapses so results stay in focus.
    private var isListFocusMode: Bool {
        navigationCoordinator.isExpenseSearchPresented || listModel.filters.isActive
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
        .tint(themeManager.contrastAccentColor(for: colorScheme))
        .buxInterfaceLocale()
        .environment(\.expensesEnhancedTint, true)
        .buxReportsContainerWidth()
        .onAppear {
            listModel.reloadCatalog(brain: brain)
            refreshExpenseListDisplay()
            listAppeared = true
            if !carouselSessionReady {
                bumpCarouselAnimationIfNeeded()
                carouselSessionReady = true
            }
        }
        .onChange(of: heroDataToken) { old, new in
            guard old != new else { return }
            bumpCarouselAnimationIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                didEnterBackground = true
            } else if phase == .active, didEnterBackground {
                didEnterBackground = false
                bumpCarouselAnimation(force: true)
            }
        }
        .onDisappear {
            navigationCoordinator.dismissExpenseSearch()
        }
        .onChange(of: navigationCoordinator.isExpenseSearchPresented) { _, presented in
            if !presented {
                refreshExpenseListDisplay()
            }
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
        if !allRecords.isEmpty {
            ToolbarItemGroup(placement: .topBarTrailing) {
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

            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            BuxNavIconButton(
                systemName: "plus",
                accessibilityLabel: "Add expense",
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
            .padding(.top, BuxTokens.tight)
        }
        .scrollDismissesKeyboard(.interactively)
        .buxRootTabScrollChrome()
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
                if showHero, carouselSessionReady, !isListFocusMode {
                    ExpensesTopCarousel(
                        header: display.header,
                        summary: display.summary,
                        formatAmount: { appSettingsManager.format($0) },
                        playRequest: carouselPlayRequest,
                        playedPages: $carouselPlayedPages,
                        pageProgress: $carouselPageProgress
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .padding(expenseHeroRowInsets)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HustleSelectorBar()
                    .padding(.bottom, 4)

                if filteredRecords.isEmpty, listModel.filters.isActive {
                    expenseNoMatchesState
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
            .padding(.top, BuxTokens.tight)
        }
        .scrollDismissesKeyboard(.interactively)
        .buxRootTabScrollChrome()
        .animation(.buxSnap, value: isListFocusMode)
    }

    private var expenseNoMatchesState: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            BuxCatalogText.text("Try a different merchant, note, or filter.")
        } actions: {
            if listModel.filters.isActive {
                BuxButton(
                    title: "Clear filters",
                    systemImage: "xmark.circle",
                    role: .secondary,
                    size: .regular
                ) {
                    withAnimation(.buxSnap) {
                        listModel.filters = ExpenseFilterState()
                        listModel.searchScope = .all
                        navigationCoordinator.dismissExpenseSearch()
                    }
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
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

    /// Plays hero carousel charts once per data fingerprint; replays when data changes or app returns from background.
    private func bumpCarouselAnimationIfNeeded() {
        bumpCarouselAnimation(force: false)
    }

    private func bumpCarouselAnimation(force: Bool) {
        let token = heroDataToken
        guard force || lastAnimatedHeroDataToken != token else { return }
        lastAnimatedHeroDataToken = token
        carouselPlayedPages.removeAll()
        carouselPageProgress.removeAll()
        carouselPlayRequest = UUID()
    }
}

// MARK: - Inline search (iOS 26 toolbar / iOS 18 drawer)

private struct ExpenseSearchModifier: ViewModifier {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Binding var searchText: String
    @Binding var searchScope: ExpenseSearchScope
    @Binding var isSearchPresented: Bool

    func body(content: Content) -> some View {
        content
            .modifier(BuxDrawerScopeModifier(
                searchText: $searchText,
                selection: $searchScope,
                isPresented: $isSearchPresented,
                prompt: BuxCatalogLabel.string(
                    "Search merchants, notes…",
                    locale: appSettingsManager.interfaceLocale
                ),
                scopes: {
                    ForEach(ExpenseSearchScope.allCases) { scope in
                        Text(
                            BuxCatalogLabel.string(
                                scope.title,
                                locale: appSettingsManager.interfaceLocale
                            )
                        )
                        .tag(scope)
                    }
                }
            ))
            .modifier(ExpenseSearchToolbarBehaviorModifier())
    }
}

private struct ExpenseSearchToolbarBehaviorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.searchToolbarBehavior(.minimize)
        } else {
            content
        }
    }
}
