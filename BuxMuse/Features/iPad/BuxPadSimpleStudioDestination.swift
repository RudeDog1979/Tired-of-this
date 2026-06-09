//
//  BuxPadSimpleStudioDestination.swift
//  BuxMuse — Simple Studio sidebar destinations (iPad only).
//

import SwiftUI

enum BuxPadSimpleStudioDestination: String, CaseIterable, Identifiable, Hashable {
    case home
    case myMoney
    case people
    case search
    case workClock
    case mileage
    case invoiceArchive
    case taxSavings
    case businessCard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .myMoney: return "My money"
        case .people: return "People"
        case .search: return "Search"
        case .workClock: return "Work clock"
        case .mileage: return "Mileage Log"
        case .invoiceArchive: return "Backup invoices"
        case .taxSavings: return "Tax savings"
        case .businessCard: return "Business card"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .myMoney: return "chart.pie.fill"
        case .people: return "person.2.fill"
        case .search: return "magnifyingglass"
        case .workClock: return "stopwatch.fill"
        case .mileage: return "car.fill"
        case .invoiceArchive: return "doc.text.image.fill"
        case .taxSavings: return "banknote.fill"
        case .businessCard: return "person.crop.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .home: return .blue
        case .myMoney: return .green
        case .people: return .indigo
        case .search: return .purple
        case .workClock: return .orange
        case .mileage: return .cyan
        case .invoiceArchive: return .brown
        case .taxSavings: return .red
        case .businessCard: return .pink
        }
    }

    static var overviewSection: [BuxPadSimpleStudioDestination] { [.home] }

    static var workSection: [BuxPadSimpleStudioDestination] {
        [.people, .search, .workClock]
    }

    static var moneySection: [BuxPadSimpleStudioDestination] {
        [.myMoney, .taxSavings]
    }

    static var toolsSection: [BuxPadSimpleStudioDestination] {
        [.mileage, .invoiceArchive, .businessCard]
    }
}
