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
    @State private var recordsById: [UUID: ExpenseRecord] = [:]

    private var allRecords: [ExpenseRecord] {
        brain.expenseRecords
    }

    private var filteredRecords: [ExpenseRecord] {
        listModel.filteredRecords(from: allRecords)
    }

    private var expenseDataToken: String {
        brain.expenseRecords.map { "\($0.id.uuidString)-\($0.updatedAt.timeIntervalSince1970)" }.joined(separator: "|")
    }

    /// Stable fingerprint for carousel replays — tied to records, not rebuilt chart snapshots.
    private var carouselDataToken: String {
        [
            expenseDataToken,
            HustleManager.shared.selectedHustleId?.uuidString ?? "all",
            appSettingsManager.selectedCurrency.id,
            listModel.filters.isActive ? "filtered" : "all"
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
            .tutorialAnchor(.expensesTabHeader, coordinator: tutorialCoordinator)
            .buxPadExpenseSplitNavigationChrome()
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
            navigationCoordinator.isExpenseSearchPresented = true
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
                        Label(BuxCatalogLabel.string("No expenses logged yet", locale: appSettingsManager.interfaceLocale), systemImage: "creditcard")
                    } description: {
                        BuxCatalogText.text("Your financial details are kept strictly offline and secure inside the BuxMuse Brain.")
                    } actions: {
                        addExpenseButton
                    }
                }
            }
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
        let display = brain.expenseInteractionSnapshot
        let showHero = !display.sections.isEmpty || display.header.totalSpent != 0

        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if showHero, !isListFocusMode {
                    ExpensesHeroCarouselHost(
                        header: display.header,
                        summary: display.summary,
                        formatAmount: { appSettingsManager.format($0) },
                        playRequest: expenseCarouselSession.playRequest
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
                            navigationCoordinator.dismissExpenseSearch()
                        }
                    },
                    onOpenDetail: { record in
                        openExpenseDetail(record)
                    },
                    onDuplicate: { record in
                        duplicateExpense(record)
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
        let display = brain.expenseInteractionSnapshot
        let showHero = !display.sections.isEmpty || display.header.totalSpent != 0
        let showHeroChrome = showHero && !isListFocusMode
        let pageCount = expenseHeroPageCount(header: display.header, summary: display.summary)

        return IPhoneUnifiedExpenseListContainer(
            display: display,
            showHeroChrome: showHeroChrome,
            pageCount: pageCount,
            heroRowInsets: expenseHeroRowInsets,
            isListFocusMode: isListFocusMode,
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
                    navigationCoordinator.dismissExpenseSearch()
                }
            },
            onOpenDetail: { record in
                openExpenseDetail(record)
            },
            onDuplicate: { record in
                duplicateExpense(record)
            }
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

    private func refreshExpenseListDisplay() {
        let filtered = filteredRecords
        recordsById = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
        brain.updateExpenseInteractionSnapshot(
            records: filtered,
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

// MARK: - iPhone pinned overlay (isolated scroll offsets)

struct IPhoneUnifiedExpenseListContainer: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator

    let display: ExpenseInteractionDisplay
    let showHeroChrome: Bool
    let pageCount: Int
    let heroRowInsets: EdgeInsets
    let isListFocusMode: Bool
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

    @State private var expenseScrollOffset: CGFloat = 0
    @State private var expenseHeroCollapseTrackingPaused = false

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack(alignment: .top) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        Color.clear
                            .frame(height: showHeroChrome ? ExpenseHeroIslandLayout.heroReservedHeight : 0)
                            .id("expense_scroll_top")
                            .expenseHeroTrackScrollCollapse(
                                scrollOffset: $expenseScrollOffset,
                                isPaused: expenseHeroCollapseTrackingPaused
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
                            onDuplicate: onDuplicate
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
                .animation(.buxSnap, value: isListFocusMode)
                .onChange(of: isListFocusMode) { _, _ in
                    expenseScrollOffset = 0
                    expenseHeroCollapseTrackingPaused = false
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
                        }
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

    static func == (lhs: ExpenseListBodyView, rhs: ExpenseListBodyView) -> Bool {
        lhs.selectedExpenseId == rhs.selectedExpenseId &&
        lhs.display.sections.map { $0.id } == rhs.display.sections.map { $0.id } &&
        lhs.display.sections.flatMap { $0.expenses }.map { $0.id } == rhs.display.sections.flatMap { $0.expenses }.map { $0.id } &&
        lhs.filteredRecords.map { $0.id } == rhs.filteredRecords.map { $0.id } &&
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

    var body: some View {
        HustleSelectorBar()
            .padding(.bottom, 4)

        if filteredRecords.isEmpty, filtersActive {
            expenseNoMatchesState
        }

        ForEach(display.sections) { section in
            HStack {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                    .textCase(nil)

                Spacer()

                if let insight = section.microInsight {
                    InlineInsightView(text: insight)
                }
            }
            .padding(.vertical, 8)

            ForEach(section.expenses) { expense in
                if let record = recordsById[expense.id] {
                    expenseRowContent(expense: expense, record: record)
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

    @ViewBuilder
    private func expenseRowContent(expense: ExpenseRowDisplay, record: ExpenseRecord) -> some View {
        ExpandableExpenseCard(
            expense: expense,
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
        .padding(expenseListRowInsets)
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
