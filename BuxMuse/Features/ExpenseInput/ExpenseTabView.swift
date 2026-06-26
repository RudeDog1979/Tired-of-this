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
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var brain: BuxMuseBrain
    @EnvironmentObject private var expenseTabStore: ExpenseTabStore
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry
    @EnvironmentObject private var tutorialCoordinator: AppTutorialCoordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.buxPadExpenseUsesSplitLayout) private var usesPadSplitLayout

    @StateObject private var listModel = ExpensesViewModel()
    @ObservedObject private var expenseCarouselSession = ExpenseCarouselSession.shared
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
    @State private var padDeleteConfirmRecord: ExpenseRecord?
    @State private var isExpenseSearchPresented = false
    @State private var expenseArchivePath = NavigationPath()
    @State private var showSpendingTrends = false

    private var tabDisplay: ExpenseInteractionDisplay {
        expenseTabStore.display
    }

    private var filtersAreActive: Bool {
        listModel.filters.isActive
            || !listModel.filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredRecords: [ExpenseRecord] {
        if filtersAreActive {
            return listModel.filteredRecords(from: brain.expenseRecords)
        }
        return Array(expenseTabStore.recordsById.values)
    }

    private var showsExpenseEmptyState: Bool {
        !filtersAreActive
            && tabDisplay.sections.isEmpty
            && tabDisplay.archiveMonths.isEmpty
    }

    private var recordsById: [UUID: ExpenseRecord] {
        expenseTabStore.recordsById
    }

    private var carouselDataToken: String {
        [
            "\(expenseTabStore.displayRevision)",
            HustleManager.shared.selectedHustleId?.uuidString ?? "all",
            appSettingsManager.selectedCurrency.id,
            filtersAreActive ? "filtered" : "scoped"
        ].joined(separator: "|")
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

    /// Filters active — iPad inline hero hides while refining results.
    private var isFilterFocusMode: Bool {
        listModel.filters.isActive
    }

    /// Search field open — drives toolbar search and iPhone hero overlay.
    private var isSearchFocusMode: Bool {
        isExpenseSearchPresented
    }

    private var isListFocusMode: Bool {
        isSearchFocusMode || isFilterFocusMode
    }

    var body: some View {
        NavigationStack(path: $expenseArchivePath) {
            ZStack {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                Group {
                    if showsExpenseEmptyState {
                        emptyStateWithWorkspaceAccess
                    } else {
                        unifiedExpenseList
                    }
                }
            }
            .tutorialAnchor(.expensesTabHeader, coordinator: tutorialCoordinator)
            .buxPadExpenseSplitNavigationChrome()
            .modifier(ExpenseSearchModifier(
                searchText: $listModel.filters.searchText,
                searchScope: $listModel.searchScope,
                isSearchPresented: $isExpenseSearchPresented
            ))
            .toolbar { expenseToolbar }
            .navigationDestination(for: ExpenseArchiveMonth.self) { archive in
                ExpenseMonthArchiveView(
                    monthStart: archive.monthStart,
                    selectedExpenseId: usesPadSplitLayout ? padNavigationBrain.selectedExpenseId : nil,
                    padNavigationBrain: usesPadSplitLayout ? padNavigationBrain : nil,
                    expandedExpenseId: $expandedExpenseId,
                    activeSheet: $activeSheet,
                    categorySheetTransaction: $categorySheetTransaction,
                    noteRecord: $noteRecord,
                    noteDraft: $noteDraft,
                    padDeleteConfirmRecord: $padDeleteConfirmRecord,
                    onOpenDetail: { record in
                        openExpenseDetail(record)
                    },
                    onDuplicate: { record in
                        duplicateExpense(record)
                    }
                )
                .environmentObject(themeManager)
                .environmentObject(brain)
                .environmentObject(appSettingsManager)
                .environmentObject(navigationCoordinator)
                .environmentObject(padSceneBrainRegistry)
            }
        }
        .tint(themeManager.contrastAccentColor(for: colorScheme))
        .buxInterfaceLocale()
        .environment(\.expensesEnhancedTint, true)
        .buxReportsContainerWidth()
        .onAppear {
            Task { @MainActor in
                if listModel.categories.isEmpty {
                    listModel.reloadCatalog(brain: brain)
                }
            }
            applyPendingExpenseFilterIfNeeded()
            listAppeared = true
            ExpenseCarouselSession.shared.playInitialIfNeeded(dataToken: carouselDataToken)
            Task { @MainActor in
                refreshExpenseListDisplay()
                selectInitialPadExpenseIfNeeded()
            }
        }
        .onChange(of: carouselDataToken) { old, new in
            guard !old.isEmpty, old != new else { return }
            ExpenseCarouselSession.shared.bumpForDataChange(dataToken: new)
        }
        .onDisappear {
            closeExpenseSearch()
        }
        .onChange(of: isExpenseSearchPresented) { _, presented in
            navigationCoordinator.isExpenseSearchPresented = presented
            if !presented {
                refreshExpenseListDisplay()
            }
        }
        .onChange(of: navigationCoordinator.isExpenseSearchPresented) { _, presented in
            if !presented, isExpenseSearchPresented {
                closeExpenseSearch()
            } else if presented, !isExpenseSearchPresented {
                isExpenseSearchPresented = true
            }
        }
        .onChange(of: brain.expenseDataRevision) { _, _ in
            if listModel.categories.isEmpty {
                listModel.reloadCatalog(brain: brain)
            }
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
        .onChange(of: navigationCoordinator.selectedTab) { _, tab in
            guard tab == .expense else { return }
            applyPendingExpenseFilterIfNeeded()
        }
        .onChange(of: SettingsStore.shared.sideHustleMatrixEnabled) { _, _ in
            refreshExpenseListDisplay()
        }
        .onChange(of: navigationCoordinator.padKeyboardNewExpenseToken) { _, _ in
            guard BuxPadIdiom.isPad else { return }
            activeSheet = .add
        }
        .onChange(of: navigationCoordinator.padKeyboardFocusSearchToken) { _, _ in
            guard BuxPadIdiom.isPad else { return }
            isExpenseSearchPresented = true
        }
        .onChange(of: padNavigationBrain.keyboardCommandToken) { _, _ in
            guard BuxPadIdiom.isPad, usesPadSplitLayout else { return }
            switch padNavigationBrain.lastKeyboardCommand {
            case .selectPreviousRow:
                padNavigationBrain.selectAdjacentExpense(in: filteredRecords, direction: -1)
            case .selectNextRow:
                padNavigationBrain.selectAdjacentExpense(in: filteredRecords, direction: 1)
            default:
                break
            }
        }
        .sheet(item: $activeSheet) { mode in
            AddExpenseSheet(brain: brain, settingsManager: appSettingsManager, mode: mode)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
                .environmentObject(tutorialCoordinator)
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
        .buxPadExpensePickerPresentation(
            categoryTransaction: $categorySheetTransaction,
            noteRecord: $noteRecord,
            noteDraft: $noteDraft,
            onCategoryChange: changeCategory,
            onNoteSave: {
                guard let record = noteRecord else { return }
                try? brain.updateExpenseNotes(id: record.id, notes: noteDraft.isEmpty ? nil : noteDraft)
            }
        )
        .fullScreenCover(item: Binding(
            get: { usesPadSplitLayout ? nil : selectedRecord },
            set: { selectedRecord = $0 }
        )) { record in
            ExpenseDetailView(record: record, brain: brain, settingsManager: appSettingsManager) {
                listModel.reloadCatalog(brain: brain)
                refreshExpenseListDisplay()
            }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environment(\.expensesEnhancedTint, true)
            .buxThemedSheetContent()
        }
        .buxPadExpenseDeleteConfirmation(
            pendingRecord: $padDeleteConfirmRecord,
            locale: appSettingsManager.interfaceLocale,
            onConfirm: deleteExpense
        )
        .fullScreenCover(isPresented: $showSpendingTrends) {
            SpendingTrendsView(initialMonthStart: currentCalendarMonthStart)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
        }
    }

    private var currentCalendarMonthStart: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    @ToolbarContentBuilder
    private var expenseToolbar: some ToolbarContent {
        if usesPadSplitLayout {
            if #available(iOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .topBarTrailing)
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

        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            expenseManageMenu
            if !showsExpenseEmptyState {
                expenseFilterMenu
            }
        }
    }

    private var expenseManageMenu: some View {
        Menu {
            Button {
                withAnimation(.buxSnap) {
                    activeSheet = .addIncome
                }
            } label: {
                Label(BuxCatalogLabel.string("Log income", locale: appSettingsManager.interfaceLocale), systemImage: "arrow.down.circle.fill")
            }

            if SettingsStore.shared.appleWalletSyncEnabled {
                Button {
                    Task {
                        await syncWalletFromExpenses()
                    }
                } label: {
                    Label(BuxCatalogLabel.string("Sync Apple Wallet", locale: appSettingsManager.interfaceLocale), systemImage: "wallet.pass")
                }
            }
            Button {
                showCategoryManager = true
            } label: {
                Label(BuxCatalogLabel.string("Manage categories", locale: appSettingsManager.interfaceLocale), systemImage: "tag")
            }
            Button {
                showMerchantManager = true
            } label: {
                Label(BuxCatalogLabel.string("Manage merchants", locale: appSettingsManager.interfaceLocale), systemImage: "building.2")
            }
            if !showsExpenseEmptyState {
                Button {
                    showAdvancedFilters = true
                } label: {
                    Label(BuxCatalogLabel.string("Advanced filters…", locale: appSettingsManager.interfaceLocale), systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        } label: {
            BuxToolbarIcon(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(BuxCatalogLabel.string("Expense options", locale: appSettingsManager.interfaceLocale))
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
                        Button(category.localizedDisplayName(locale: locale)) {
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
                        Label(BuxCatalogLabel.string("No expenses in this workspace", locale: appSettingsManager.interfaceLocale), systemImage: "rectangle.3.group")
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
                        Label(BuxCatalogLabel.string("Log your first expense", locale: appSettingsManager.interfaceLocale), systemImage: "creditcard")
                    } description: {
                        BuxCatalogText.text("No bank connection needed. Everything stays on your phone.")
                    } actions: {
                        addExpenseButton
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.top, BuxTokens.tight)
            .buxPadExpenseCardRail()
        }
        .scrollDismissesKeyboard(.interactively)
        .modifier(ExpensePadSplitScrollChromeModifier())
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

    @ViewBuilder
    private var unifiedExpenseList: some View {
        if BuxPadIdiom.isPad {
            padUnifiedExpenseList
        } else {
            iphoneUnifiedExpenseList
        }
    }

    private var padUnifiedExpenseList: some View {
        let display = tabDisplay
        let showHero = !display.sections.isEmpty || display.header.totalSpent != 0

        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if showHero, !isListFocusMode {
                    ExpensesHeroCarouselHost(
                        header: display.header,
                        summary: display.summary,
                        formatAmount: { appSettingsManager.format($0) },
                        playRequest: expenseCarouselSession.playRequest,
                        onOpenSpendingTrends: { showSpendingTrends = true }
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .padding(expenseHeroRowInsets)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ExpenseListBodyView(
                    display: display,
                    filteredRecords: filteredRecords,
                    filtersActive: listModel.filters.isActive,
                    recordsById: recordsById,
                    selectedExpenseId: padNavigationBrain.selectedExpenseId,
                    padNavigationBrain: padNavigationBrain,
                    expandedExpenseId: $expandedExpenseId,
                    activeSheet: $activeSheet,
                    categorySheetTransaction: $categorySheetTransaction,
                    noteRecord: $noteRecord,
                    noteDraft: $noteDraft,
                    padDeleteConfirmRecord: $padDeleteConfirmRecord,
                    onClearFilters: {
                        withAnimation(.buxSnap) {
                            listModel.filters = ExpenseFilterState()
                            listModel.searchScope = .all
                            closeExpenseSearch()
                        }
                    },
                    onOpenDetail: { record in
                        openExpenseDetail(record)
                    },
                    onDuplicate: { record in
                        duplicateExpense(record)
                    },
                    onSelectArchiveMonth: { month in
                        expenseArchivePath.append(ExpenseArchiveMonth(monthStart: month))
                    }
                )
                .equatable()
            }
            .padding(.top, BuxTokens.tight)
            .buxPadExpenseCardRail()
            .environment(\.textCase, nil)
        }
        .scrollDismissesKeyboard(.interactively)
        .modifier(ExpensePadSplitScrollChromeModifier())
        .buxPadListArrowNavigation(
            enabled: usesPadSplitLayout,
            onPrevious: {
                padNavigationBrain.selectAdjacentExpense(in: filteredRecords, direction: -1)
            },
            onNext: {
                padNavigationBrain.selectAdjacentExpense(in: filteredRecords, direction: 1)
            }
        )
        .animation(.buxSnap, value: isListFocusMode)
    }

    private var iphoneUnifiedExpenseList: some View {
        let display = tabDisplay
        let showHero = !display.sections.isEmpty || display.header.totalSpent != 0
        let showHeroChrome = showHero && !isSearchFocusMode
        let pageCount = expenseHeroPageCount(header: display.header, summary: display.summary)

        return IPhoneUnifiedExpenseListContainer(
            display: display,
            showHeroChrome: showHeroChrome,
            isSearchPresented: isSearchFocusMode,
            pageCount: pageCount,
            heroRowInsets: expenseHeroRowInsets,
            filteredRecords: filteredRecords,
            filtersActive: listModel.filters.isActive,
            recordsById: recordsById,
            expandedExpenseId: $expandedExpenseId,
            activeSheet: $activeSheet,
            categorySheetTransaction: $categorySheetTransaction,
            noteRecord: $noteRecord,
            noteDraft: $noteDraft,
            padDeleteConfirmRecord: $padDeleteConfirmRecord,
            onClearFilters: {
                withAnimation(.buxSnap) {
                    listModel.filters = ExpenseFilterState()
                    listModel.searchScope = .all
                    closeExpenseSearch()
                }
            },
            onOpenDetail: { record in
                openExpenseDetail(record)
            },
            onDuplicate: { record in
                duplicateExpense(record)
            },
            onSelectArchiveMonth: { month in
                expenseArchivePath.append(ExpenseArchiveMonth(monthStart: month))
            },
            onOpenSpendingTrends: { showSpendingTrends = true }
        )
    }

    private func expenseHeroPageCount(header: ExpensesHeaderDisplay, summary: ExpensesSummaryDisplay) -> Int {
        var count = 0
        if header.totalSpent != 0 || !header.sparklinePoints.isEmpty { count += 1 }
        if !summary.categoryBreakdown.isEmpty || !summary.merchantBreakdown.isEmpty { count += 1 }
        return max(count, 1)
    }

    private func openExpenseDetail(_ record: ExpenseRecord) {
        if usesPadSplitLayout {
            padNavigationBrain.selectExpense(record.id)
        } else {
            selectedRecord = record
        }
    }

    private func selectInitialPadExpenseIfNeeded() {
        guard usesPadSplitLayout else { return }
        guard padNavigationBrain.selectedExpenseId == nil else { return }
        guard let first = filteredRecords.first else { return }
        padNavigationBrain.selectExpense(first.id)
    }

    private func applyPendingExpenseFilterIfNeeded() {
        guard let pending = navigationCoordinator.consumePendingExpenseFilter() else { return }
        listModel.filters = pending
    }

    private func closeExpenseSearch(clearText: Bool = false) {
        if clearText {
            listModel.filters.searchText = ""
        }
        isExpenseSearchPresented = false
    }

    private func refreshExpenseListDisplay() {
        expenseTabStore.reload(
            recordsForList: filtersAreActive ? listModel.filteredRecords(from: brain.expenseRecords) : [],
            filtersActive: filtersAreActive,
            currency: appSettingsManager.selectedCurrency
        )
    }

    private func syncWalletFromExpenses() async {
        await BuxFinanceKitManager.shared.syncWalletNow()
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
            refreshExpenseListDisplay()
        } catch {
            print("Category change failed: \(error)")
        }
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
    }
}

// MARK: - iPhone pinned overlay (isolated scroll offsets)

struct IPhoneUnifiedExpenseListContainer: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    let display: ExpenseInteractionDisplay
    let showHeroChrome: Bool
    let isSearchPresented: Bool
    let pageCount: Int
    let heroRowInsets: EdgeInsets
    let filteredRecords: [ExpenseRecord]
    let filtersActive: Bool
    let recordsById: [UUID: ExpenseRecord]

    @Binding var expandedExpenseId: UUID?
    @Binding var activeSheet: ExpenseSheetMode?
    @Binding var categorySheetTransaction: Transaction?
    @Binding var noteRecord: ExpenseRecord?
    @Binding var noteDraft: String
    @Binding var padDeleteConfirmRecord: ExpenseRecord?

    let onClearFilters: () -> Void
    let onOpenDetail: (ExpenseRecord) -> Void
    let onDuplicate: (ExpenseRecord) -> Void
    let onSelectArchiveMonth: (Date) -> Void
    var onOpenSpendingTrends: (() -> Void)? = nil

    @State private var expenseScrollOffset: CGFloat = 0
    @State private var expenseHeroCollapseTrackingPaused = false

    private var isLandscapePhone: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .top) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        Color.clear
                            .frame(height: showHeroChrome ? ExpenseHeroIslandLayout.heroReservedHeight(landscapePhone: isLandscapePhone) : 0)
                            .id("expense_scroll_top")
                            .expenseHeroTrackScrollCollapse(
                                scrollOffset: $expenseScrollOffset,
                                isPaused: expenseHeroCollapseTrackingPaused || isSearchPresented
                            )

                        ExpenseListBodyView(
                            display: display,
                            filteredRecords: filteredRecords,
                            filtersActive: filtersActive,
                            recordsById: recordsById,
                            selectedExpenseId: nil,
                            padNavigationBrain: nil,
                            expandedExpenseId: $expandedExpenseId,
                            activeSheet: $activeSheet,
                            categorySheetTransaction: $categorySheetTransaction,
                            noteRecord: $noteRecord,
                            noteDraft: $noteDraft,
                            padDeleteConfirmRecord: $padDeleteConfirmRecord,
                            onClearFilters: onClearFilters,
                            onOpenDetail: onOpenDetail,
                            onDuplicate: onDuplicate,
                            onSelectArchiveMonth: onSelectArchiveMonth
                        )
                        .equatable()
                        .padding(.top, ExpenseHeroIslandLayout.listBelowHeroSpacing)
                    }
                    .padding(.top, BuxTokens.tight)
                    .buxPadExpenseCardRail()
                    .environment(\.textCase, nil)
                }
                .scrollDismissesKeyboard(.interactively)
                .modifier(ExpensePadSplitScrollChromeModifier())
                .buxScrollCollapseCoordinateSpace()
                .animation(.buxSnap, value: showHeroChrome)
                .onChange(of: isSearchPresented) { _, presented in
                    if presented {
                        expenseScrollOffset = 0
                        expenseHeroCollapseTrackingPaused = true
                    } else {
                        expenseScrollOffset = 0
                        expenseHeroCollapseTrackingPaused = false
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            scrollProxy.scrollTo("expense_scroll_top", anchor: .top)
                        }
                    }
                }

                if showHeroChrome {
                    ExpenseHeroIslandOverlay(
                        scrollOffset: expenseScrollOffset,
                        header: display.header,
                        summary: display.summary,
                        pageCount: pageCount,
                        heroRowInsets: heroRowInsets,
                        onExpand: {
                            expenseScrollOffset = 0
                            expenseHeroCollapseTrackingPaused = true
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                scrollProxy.scrollTo("expense_scroll_top", anchor: .top)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                                expenseHeroCollapseTrackingPaused = false
                            }
                        },
                        onOpenSpendingTrends: onOpenSpendingTrends
                    )
                }
            }
        }
    }
}

// MARK: - Optimized Equatable List Body

struct ExpenseListBodyView: View, Equatable {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry
    @Environment(\.openWindow) private var openWindow
    @Environment(\.buxPadExpenseUsesSplitLayout) private var usesPadSplitLayout

    let display: ExpenseInteractionDisplay
    let filteredRecords: [ExpenseRecord]
    let filtersActive: Bool
    let recordsById: [UUID: ExpenseRecord]
    let selectedExpenseId: UUID?
    let padNavigationBrain: BuxPadNavigationBrain?

    @Binding var expandedExpenseId: UUID?
    @Binding var activeSheet: ExpenseSheetMode?
    @Binding var categorySheetTransaction: Transaction?
    @Binding var noteRecord: ExpenseRecord?
    @Binding var noteDraft: String
    @Binding var padDeleteConfirmRecord: ExpenseRecord?

    let onClearFilters: () -> Void
    let onOpenDetail: (ExpenseRecord) -> Void
    let onDuplicate: (ExpenseRecord) -> Void
    let onSelectArchiveMonth: (Date) -> Void

    @State private var collapsedDays: Set<Date> = []

    private let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .none
        return fmt
    }()

    static func == (lhs: ExpenseListBodyView, rhs: ExpenseListBodyView) -> Bool {
        lhs.selectedExpenseId == rhs.selectedExpenseId &&
        lhs.display.pendingExpenses.map(\.id) == rhs.display.pendingExpenses.map(\.id) &&
        lhs.display.sections.flatMap { $0.expenses }.map { $0.id } == rhs.display.sections.flatMap { $0.expenses }.map { $0.id } &&
        lhs.display.archiveMonths == rhs.display.archiveMonths &&
        (!lhs.filtersActive || lhs.filteredRecords.map(\.id) == rhs.filteredRecords.map(\.id)) &&
        lhs.filtersActive == rhs.filtersActive &&
        lhs.recordsById == rhs.recordsById &&
        lhs.expandedExpenseId == rhs.expandedExpenseId &&
        lhs.activeSheet == rhs.activeSheet &&
        lhs.categorySheetTransaction?.id == rhs.categorySheetTransaction?.id &&
        lhs.noteRecord?.id == rhs.noteRecord?.id &&
        lhs.noteDraft == rhs.noteDraft &&
        lhs.padDeleteConfirmRecord?.id == rhs.padDeleteConfirmRecord?.id
    }

    private var expenseListRowInsets: EdgeInsets {
        EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
    }

    @ViewBuilder
    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let startOfCurrentMonth = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)

        let allDisplayRows = display.sections.flatMap { $0.expenses }
        let groupedRows = Dictionary(grouping: allDisplayRows, by: { calendar.startOfDay(for: $0.date) })
        let sortedDays = groupedRows.keys.sorted(by: >)
        let recentDays = sortedDays.filter { $0 >= startOfCurrentMonth }

        let dayHeaderTitle: (Date) -> String = { date in
            if calendar.isDateInToday(date) {
                return BuxLocalizedString.string("Today", locale: appSettingsManager.interfaceLocale)
            } else if calendar.isDateInYesterday(date) {
                return BuxLocalizedString.string("Yesterday", locale: appSettingsManager.interfaceLocale)
            } else {
                dayFormatter.locale = appSettingsManager.interfaceLocale
                return dayFormatter.string(from: date)
            }
        }

        let dailySpendTotal: (Date, [ExpenseRowDisplay]) -> Double = { _, rows in
            rows.reduce(0.0) { sum, row in
                if let record = recordsById[row.id], record.isSpendingOutflow {
                    return sum + record.spendingAmountDouble
                }
                return sum
            }
        }

        Group {
            HustleSelectorBar()
                .padding(.bottom, 4)

            if filteredRecords.isEmpty, filtersActive {
                expenseNoMatchesState
            }

            if !display.pendingExpenses.isEmpty {
                ExpensePendingWalletSectionView(
                    rows: display.pendingExpenses,
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

            ForEach(recentDays, id: \.self) { day in
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

            if !display.archiveMonths.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.vertical, 16)

                    ForEach(display.archiveMonths) { archive in
                        let monthTitle = BuxDisplayDate.monthYear(
                            from: archive.monthStart,
                            locale: appSettingsManager.interfaceLocale
                        )

                        Button {
                            onSelectArchiveMonth(archive.monthStart)
                        } label: {
                            ExpenseMonthFolderCard(
                                monthTitle: monthTitle,
                                transactionCount: archive.transactionCount
                            )
                        }
                        .buttonStyle(BuxMicroShrinkStyle())
                        .padding(expenseListRowInsets)
                    }
                }
            }
        }
    }

    private var expenseNoMatchesState: some View {
        ContentUnavailableView {
            Label(BuxCatalogLabel.string("No matches", locale: appSettingsManager.interfaceLocale), systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            BuxCatalogText.text("Try a different merchant, note, or filter.")
        } actions: {
            if filtersActive {
                BuxButton(
                    title: "Clear filters",
                    systemImage: "xmark.circle",
                    role: .secondary,
                    size: .regular
                ) {
                    onClearFilters()
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - iPhone hero collapse tracking (immediate response, expand lock)

private struct ExpenseHeroScrollCollapseTracker: ViewModifier {
    @Binding var scrollOffset: CGFloat
    var isPaused: Bool
    let coordinateSpace: String

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geo.frame(in: .named(coordinateSpace)).minY
                    )
                }
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                guard !isPaused else { return }
                let clamped = value < 0 ? max(-BuxScrollCollapse.maxTrackedOffset, value) : 0
                guard abs(clamped - scrollOffset) > 0.5 else { return }
                scrollOffset = clamped
            }
    }
}

private extension View {
    func expenseHeroTrackScrollCollapse(
        scrollOffset: Binding<CGFloat>,
        isPaused: Bool,
        coordinateSpace: String = BuxScrollCollapse.coordinateSpaceName
    ) -> some View {
        modifier(ExpenseHeroScrollCollapseTracker(
            scrollOffset: scrollOffset,
            isPaused: isPaused,
            coordinateSpace: coordinateSpace
        ))
    }
}
