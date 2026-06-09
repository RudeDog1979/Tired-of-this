//
//  BuxPadStudioDestination.swift
//  BuxMuse — Studio Pro sidebar destinations (iPad only).
//

import SwiftUI

enum BuxPadStudioDestination: String, CaseIterable, Identifiable, Hashable {
    case commandCenter
    case invoices
    case clients
    case projects
    case receipts
    case taxStudio
    case taxSavings
    case cashflow
    case deductions
    case mileage
    case agreements
    case insights
    case businessCard
    case invoiceArchive
    case businessProfile
    case proSearch

    var id: String { rawValue }

    /// English catalog key — use `catalogTitle(locale:)` in UI.
    var title: String {
        switch self {
        case .commandCenter: return "Command Center"
        case .invoices: return "Invoices"
        case .clients: return "Clients"
        case .projects: return "Projects"
        case .receipts: return "Receipts"
        case .taxStudio: return "Tax Studio"
        case .taxSavings: return "Tax savings"
        case .cashflow: return "Cashflow"
        case .deductions: return "Deductions"
        case .mileage: return "Mileage Log"
        case .agreements: return "Agreements"
        case .insights: return "Studio Insights"
        case .businessCard: return "Business Card"
        case .invoiceArchive: return "Backup invoices"
        case .businessProfile: return "Business Profile"
        case .proSearch: return "Pro Search"
        }
    }

    func catalogTitle(locale: Locale) -> String {
        BuxCatalogLabel.string(title, locale: locale)
    }

    var systemImage: String {
        switch self {
        case .commandCenter: return "square.grid.2x2.fill"
        case .invoices: return "doc.text.fill"
        case .clients: return "person.2.fill"
        case .projects: return "folder.fill"
        case .receipts: return "doc.plaintext.fill"
        case .taxStudio: return "percent"
        case .taxSavings: return "banknote.fill"
        case .cashflow: return "chart.line.uptrend.xyaxis"
        case .deductions: return "lightbulb.fill"
        case .mileage: return "car.fill"
        case .agreements: return "signature"
        case .insights: return "chart.bar.xaxis"
        case .businessCard: return "person.crop.rectangle.fill"
        case .invoiceArchive: return "doc.text.image.fill"
        case .businessProfile: return "building.2.fill"
        case .proSearch: return "sparkle.magnifyingglass"
        }
    }

    var tint: Color {
        switch self {
        case .commandCenter: return .blue
        case .invoices: return .green
        case .clients: return .blue
        case .projects: return .purple
        case .receipts: return .teal
        case .taxStudio, .taxSavings: return .red
        case .cashflow: return .orange
        case .deductions: return .yellow
        case .mileage: return .cyan
        case .agreements: return .indigo
        case .insights: return .mint
        case .businessCard: return .pink
        case .invoiceArchive: return .brown
        case .businessProfile: return Color(red: 1, green: 0.37, blue: 0.36)
        case .proSearch: return .purple
        }
    }

    static var overviewSection: [BuxPadStudioDestination] { [.commandCenter] }

    static var workSection: [BuxPadStudioDestination] {
        [.invoices, .clients, .projects, .receipts]
    }

    static var financeSection: [BuxPadStudioDestination] {
        [.taxStudio, .cashflow, .deductions, .mileage, .taxSavings]
    }

    static var toolsSection: [BuxPadStudioDestination] {
        [.agreements, .insights, .businessCard, .invoiceArchive, .businessProfile, .proSearch]
    }
}
