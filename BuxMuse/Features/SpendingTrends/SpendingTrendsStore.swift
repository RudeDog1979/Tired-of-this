//
//  SpendingTrendsStore.swift
//  BuxMuse
//

import Combine
import Foundation

@MainActor
final class SpendingTrendsStore: ObservableObject {
    @Published private(set) var period: SpendingTrendsPeriod = .month
    @Published private(set) var anchors: [SpendingTrendsAnchor] = []
    @Published private(set) var selectedAnchorId: String?
    @Published private(set) var displays: [String: SpendingTrendsDisplay] = [:]

    private var cacheOrder: [String] = []
    private let cacheLimit = 18
    private var bootstrapToken = UUID()
    private var loadTasks: [String: Task<Void, Never>] = [:]
    private var dataRefreshTask: Task<Void, Never>?

    var selectedAnchor: SpendingTrendsAnchor? {
        guard let selectedAnchorId else { return anchors.last }
        return anchors.first { $0.id == selectedAnchorId } ?? anchors.last
    }

    func bootstrap(brain: BuxMuseBrain, locale: Locale, initialMonthStart: Date? = nil) async {
        let token = UUID()
        bootstrapToken = token

        let discovered = await brain.discoverSpendingTrendsAnchors(period: period)
        guard bootstrapToken == token else { return }

        anchors = discovered
        selectedAnchorId = resolveInitialAnchorId(
            in: discovered,
            initialMonthStart: initialMonthStart
        )

        guard let anchor = selectedAnchor else { return }
        await loadDisplay(for: anchor, brain: brain, locale: locale, force: false)
        prefetchNeighbors(around: anchor, brain: brain, locale: locale)
    }

    func setPeriod(_ newPeriod: SpendingTrendsPeriod, brain: BuxMuseBrain, locale: Locale) async {
        guard newPeriod != period else { return }
        period = newPeriod
        displays = [:]
        cacheOrder = []
        loadTasks.values.forEach { $0.cancel() }
        loadTasks = [:]
        await bootstrap(brain: brain, locale: locale)
    }

    func selectAnchor(_ anchorId: String, brain: BuxMuseBrain, locale: Locale) {
        guard selectedAnchorId != anchorId else { return }
        selectedAnchorId = anchorId
        guard let anchor = anchors.first(where: { $0.id == anchorId }) else { return }
        prefetchNeighbors(around: anchor, brain: brain, locale: locale)
        if displays[anchor.id] == nil {
            Task {
                await loadDisplay(for: anchor, brain: brain, locale: locale, force: false)
            }
        }
    }

    func loadDisplay(
        for anchor: SpendingTrendsAnchor,
        brain: BuxMuseBrain,
        locale: Locale,
        force: Bool
    ) async {
        if !force, displays[anchor.id] != nil { return }
        if let existing = loadTasks[anchor.id] {
            await existing.value
            return
        }

        let task = Task {
            guard let display = await brain.fetchSpendingTrendsDisplay(anchor: anchor, locale: locale) else { return }
            guard !Task.isCancelled else { return }
            displays[anchor.id] = display
            touchCache(anchor.id)
        }
        loadTasks[anchor.id] = task
        await task.value
        loadTasks[anchor.id] = nil
    }

    func scheduleDataRefresh(brain: BuxMuseBrain, locale: Locale) {
        dataRefreshTask?.cancel()
        dataRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            await refreshCachedDisplaysSilently(brain: brain, locale: locale)
        }
    }

    private func refreshCachedDisplaysSilently(brain: BuxMuseBrain, locale: Locale) async {
        let keys = cacheOrder
        for key in keys {
            guard let anchor = anchors.first(where: { $0.id == key }) else { continue }
            guard let display = await brain.fetchSpendingTrendsDisplay(anchor: anchor, locale: locale) else { continue }
            guard !Task.isCancelled else { return }
            displays[key] = display
        }
    }

    private func resolveInitialAnchorId(
        in discovered: [SpendingTrendsAnchor],
        initialMonthStart: Date?
    ) -> String? {
        guard !discovered.isEmpty else { return nil }
        if let initialMonthStart, period == .month {
            let calendar = Calendar.current
            if let match = discovered.last(where: {
                calendar.isDate($0.start, equalTo: initialMonthStart, toGranularity: .month)
            }) {
                return match.id
            }
        }
        return discovered.last?.id
    }

    private func prefetchNeighbors(around anchor: SpendingTrendsAnchor, brain: BuxMuseBrain, locale: Locale) {
        guard let index = anchors.firstIndex(of: anchor) else { return }
        // Ascending: lower index = older (left), higher index = newer (right).
        let neighbors = [index - 1, index + 1].compactMap { anchors[safe: $0] }
        for neighbor in neighbors where displays[neighbor.id] == nil {
            Task {
                await loadDisplay(for: neighbor, brain: brain, locale: locale, force: false)
            }
        }
    }

    private func touchCache(_ key: String) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.insert(key, at: 0)
        while cacheOrder.count > cacheLimit {
            let removed = cacheOrder.removeLast()
            displays[removed] = nil
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
