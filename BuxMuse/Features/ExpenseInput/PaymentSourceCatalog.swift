//
//  PaymentSourceCatalog.swift
//  BuxMuse
//
//  Searchable payment provider catalog for optional expense attribution.
//

import Foundation

enum PaymentSourceKind: String, Codable, CaseIterable {
    case debit
    case credit
    case bankTransfer
    case digitalWallet
    case bnpl
    case storeCredit
    case cash
    case other
}

struct PaymentSourceOption: Identifiable, Hashable {
    let id: String
    let label: String
    let kind: PaymentSourceKind
    let systemImage: String

    var isCreditLike: Bool {
        switch kind {
        case .credit, .bnpl, .storeCredit: return true
        default: return false
        }
    }
}

enum PaymentSourceCatalog {
    static let all: [PaymentSourceOption] = [
        .init(id: "visa", label: "Visa", kind: .credit, systemImage: "creditcard.fill"),
        .init(id: "mastercard", label: "Mastercard", kind: .credit, systemImage: "creditcard.fill"),
        .init(id: "amex", label: "American Express", kind: .credit, systemImage: "creditcard.fill"),
        .init(id: "discover", label: "Discover", kind: .credit, systemImage: "creditcard.fill"),
        .init(id: "debit_card", label: "Debit card", kind: .debit, systemImage: "creditcard"),
        .init(id: "bank_transfer", label: "Bank transfer", kind: .bankTransfer, systemImage: "building.columns.fill"),
        .init(id: "apple_pay", label: "Apple Pay", kind: .digitalWallet, systemImage: "apple.logo"),
        .init(id: "google_pay", label: "Google Pay", kind: .digitalWallet, systemImage: "g.circle.fill"),
        .init(id: "paypal", label: "PayPal", kind: .digitalWallet, systemImage: "p.circle.fill"),
        .init(id: "paypal_credit", label: "PayPal Credit", kind: .credit, systemImage: "p.circle.fill"),
        .init(id: "venmo", label: "Venmo", kind: .digitalWallet, systemImage: "v.circle.fill"),
        .init(id: "cash_app", label: "Cash App", kind: .digitalWallet, systemImage: "dollarsign.circle.fill"),
        .init(id: "klarna", label: "Klarna", kind: .bnpl, systemImage: "clock.badge.exclamationmark.fill"),
        .init(id: "affirm", label: "Affirm", kind: .bnpl, systemImage: "clock.badge.exclamationmark.fill"),
        .init(id: "afterpay", label: "Afterpay", kind: .bnpl, systemImage: "clock.badge.exclamationmark.fill"),
        .init(id: "zip", label: "Zip / Quadpay", kind: .bnpl, systemImage: "clock.badge.exclamationmark.fill"),
        .init(id: "store_credit", label: "Store credit", kind: .storeCredit, systemImage: "giftcard.fill"),
        .init(id: "other", label: "Other", kind: .other, systemImage: "ellipsis.circle.fill")
    ]

    static func option(matching storedValue: String?) -> PaymentSourceOption? {
        guard let storedValue, !storedValue.isEmpty else { return nil }
        if storedValue.hasPrefix("Cash (") { return nil }
        if storedValue == "Barter" { return nil }
        return all.first { $0.label.caseInsensitiveCompare(storedValue) == .orderedSame }
            ?? all.first { $0.id == storedValue }
    }

    static func kind(for storedValue: String?) -> PaymentSourceKind? {
        option(matching: storedValue)?.kind
    }

    static func isCreditLike(_ storedValue: String?) -> Bool {
        option(matching: storedValue)?.isCreditLike ?? false
    }

    static func search(_ query: String) -> [PaymentSourceOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.label.localizedCaseInsensitiveContains(trimmed)
                || $0.kind.rawValue.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
