//
//  HustleWorkspaceFilter.swift
//  BuxMuse
//
//  Shared workspace (Side-Hustle Matrix) filtering for expenses and Studio data.
//

import Foundation

@MainActor
enum HustleWorkspaceFilter {
    static var isMatrixEnabled: Bool {
        SettingsStore.shared.sideHustleMatrixEnabled
    }

    static var showUnassignedWhenFiltered: Bool {
        SettingsStore.shared.showUnassignedExpensesInWorkspace
    }

    static var selectedHustleId: UUID? {
        guard isMatrixEnabled else { return nil }
        return HustleManager.shared.selectedHustleId
    }

    static var isFilteringActive: Bool {
        selectedHustleId != nil
    }

    static func matchesWorkspace(hustleId: UUID?) -> Bool {
        guard isMatrixEnabled, let selectedId = selectedHustleId else { return true }
        if hustleId == selectedId { return true }
        if hustleId == nil, showUnassignedWhenFiltered { return true }
        return false
    }

    static func filter<T>(_ items: [T], hustleId: (T) -> UUID?) -> [T] {
        guard isMatrixEnabled, let selectedId = selectedHustleId else { return items }
        return items.filter { item in
            let id = hustleId(item)
            if id == selectedId { return true }
            if id == nil, showUnassignedWhenFiltered { return true }
            return false
        }
    }

    static func isUnassigned(_ hustleId: UUID?) -> Bool {
        hustleId == nil
    }

    static func activeWorkspaceLabel() -> String? {
        guard isMatrixEnabled, let selectedId = selectedHustleId else { return nil }
        return HustleManager.shared.hustles.first(where: { $0.id == selectedId })?.name
    }
}
