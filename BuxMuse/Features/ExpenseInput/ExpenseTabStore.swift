//
//  ExpenseTabStore.swift
//  BuxMuse
//
//  Expenses-tab-only display state — isolated from BuxMuseBrain @Published churn.
//

import Combine
import Foundation

@MainActor
final class ExpenseTabStore: ObservableObject {
    @Published private(set) var display: ExpenseInteractionDisplay = .empty
    @Published private(set) var recordsById: [UUID: ExpenseRecord] = [:]
    @Published private(set) var displayRevision: Int = 0

    private let brain: BuxMuseBrain
    private let appSettings: AppSettingsManager
    private var reloadTask: Task<Void, Never>?
    private var lastReloadToken: String?
    private var pinnedFilteredDisplay = false
    private var ledgerRefreshWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    init(brain: BuxMuseBrain, appSettings: AppSettingsManager) {
        self.brain = brain
        self.appSettings = appSettings
        wireReloadTriggers()
    }

    func reloadFromLedger(currency: CurrencySetting) {
        reload(recordsForList: [], filtersActive: false, currency: currency)
    }

    /// Bypasses reload dedupe — used after Apple Wallet sync updates pending rows in GRDB.
    func forceReloadFromLedger(currency: CurrencySetting) {
        lastReloadToken = nil
        reload(recordsForList: [], filtersActive: false, currency: currency)
    }

    func reload(recordsForList: [ExpenseRecord], filtersActive: Bool, currency: CurrencySetting) {
        pinnedFilteredDisplay = filtersActive

        let token = [
            "\(brain.expenseDataRevision)",
            HustleManager.shared.selectedHustleId?.uuidString ?? "all",
            currency.id,
            filtersActive ? "filtered" : "scoped",
            filtersActive ? recordsForList.map(\.id.uuidString).joined(separator: ",") : "scoped"
        ].joined(separator: "|")

        if token == lastReloadToken {
            return
        }

        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            await self?.performReload(
                recordsForList: recordsForList,
                filtersActive: filtersActive,
                currency: currency,
                token: token
            )
        }
    }

    private func performReload(
        recordsForList: [ExpenseRecord],
        filtersActive: Bool,
        currency: CurrencySetting,
        token: String
    ) async {
        let built: ExpenseInteractionDisplay
        let mapRecords: [ExpenseRecord]
        if filtersActive {
            built = brain.buildExpenseInteractionDisplay(from: recordsForList, currency: currency)
            mapRecords = recordsForList
        } else if let scoped = await brain.fetchScopedExpenseTabContent(currency: currency) {
            built = scoped.display
            mapRecords = scoped.listRecords
        } else {
            built = .empty
            mapRecords = []
        }
        guard !Task.isCancelled else { return }

        if filtersActive || !pinnedFilteredDisplay {
            display = built
            recordsById = Dictionary(uniqueKeysWithValues: mapRecords.map { ($0.id, $0) })
            lastReloadToken = token
            displayRevision += 1
            brain.publishExpenseInteractionDisplay(built)
        } else {
            var patched = display
            patched.header = built.header
            display = patched
            displayRevision += 1
            brain.publishExpenseInteractionDisplay(patched)
        }
    }

    private func wireReloadTriggers() {
        brain.$expenseDataRevision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLedgerFromExpenses()
            }
            .store(in: &cancellables)

        brain.$isHydrated
            .filter { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLedgerFromExpenses(forceDisplay: true)
            }
            .store(in: &cancellables)

        HustleManager.shared.$selectedHustleId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLedgerFromExpenses(forceDisplay: true)
            }
            .store(in: &cancellables)

        SettingsStore.shared.$showUnassignedExpensesInWorkspace
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLedgerFromExpenses(forceDisplay: true)
            }
            .store(in: &cancellables)

        SettingsStore.shared.$sideHustleMatrixEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLedgerFromExpenses(forceDisplay: true)
            }
            .store(in: &cancellables)

        appSettings.$selectedCurrency
            .receive(on: DispatchQueue.main)
            .sink { [weak self] currency in
                self?.refreshLedgerFromExpenses(forceDisplay: true, currency: currency)
            }
            .store(in: &cancellables)

        appSettings.$interfaceLanguage
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLedgerFromExpenses(forceDisplay: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .buxMuseWalletSyncDidComplete)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.forceReloadFromLedger(currency: self.appSettings.selectedCurrency)
            }
            .store(in: &cancellables)
    }

    /// Keeps dashboard wallet balance in sync with the Expenses SQL pipeline without clobbering filtered tab lists.
    private func refreshLedgerFromExpenses(forceDisplay: Bool = false, currency: CurrencySetting? = nil) {
        ledgerRefreshWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.performLedgerRefresh(forceDisplay: forceDisplay, currency: currency ?? self.appSettings.selectedCurrency)
        }
        ledgerRefreshWorkItem = work
        let delay: TimeInterval = (forceDisplay && displayRevision == 0) ? 0 : 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func performLedgerRefresh(forceDisplay: Bool, currency: CurrencySetting) {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            guard let self else { return }
            guard let scoped = await self.brain.fetchScopedExpenseTabContent(currency: currency) else { return }
            guard !Task.isCancelled else { return }

            let shouldRefreshDisplay = forceDisplay || !self.pinnedFilteredDisplay
            if shouldRefreshDisplay {
                self.display = scoped.display
                self.recordsById = Dictionary(uniqueKeysWithValues: scoped.listRecords.map { ($0.id, $0) })
                self.lastReloadToken = [
                    "\(self.brain.expenseDataRevision)",
                    HustleManager.shared.selectedHustleId?.uuidString ?? "all",
                    currency.id,
                    "scoped",
                    "scoped"
                ].joined(separator: "|")
                self.displayRevision += 1
                self.brain.publishExpenseInteractionDisplay(scoped.display)
            } else {
                var patched = self.display
                patched.header = scoped.display.header
                self.display = patched
                self.displayRevision += 1
                self.brain.publishExpenseInteractionDisplay(patched)
            }
        }
    }
}
