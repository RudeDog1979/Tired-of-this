//
//  DashboardFabPadShortcut.swift
//  BuxMuse — Configurable 3rd iPad expense FAB arc action.
//

import Foundation

public enum DashboardFabPadShortcut: String, CaseIterable, Identifiable, Codable {
    case scanReceipt
    case newInvoice
    case categories
    case themes
    case addIncome

    public var id: String { rawValue }

    public var titleKey: String {
        switch self {
        case .scanReceipt: return "Scan Receipt"
        case .newInvoice: return "New Invoice"
        case .categories: return "Manage Categories"
        case .themes: return "Appearance & Themes"
        case .addIncome: return "Income"
        }
    }

    public var icon: String {
        switch self {
        case .scanReceipt: return "camera.fill"
        case .newInvoice: return "plus.rectangle.fill.on.folder.fill"
        case .categories: return "folder.fill"
        case .themes: return "paintpalette.fill"
        case .addIncome: return "arrow.down.circle.fill"
        }
    }

    public static func availableShortcuts(studioEnabled: Bool) -> [DashboardFabPadShortcut] {
        if studioEnabled {
            return allCases.filter { $0 != .scanReceipt && $0 != .newInvoice }
        }
        return allCases
    }
}
