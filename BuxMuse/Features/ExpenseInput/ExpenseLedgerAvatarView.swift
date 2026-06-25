//
//  ExpenseLedgerAvatarView.swift
//  BuxMuse
//
//  Merchant logo when linked; otherwise category icon (income / other-income variants).
//

import SwiftUI

enum IncomeSourceQuickPick: String, CaseIterable, Identifiable {
    case salary
    case paycheck
    case refund
    case gift
    case sold
    case interest
    case cash
    case other

    var id: String { rawValue }

    /// Stable English catalog key (stored in `ExpenseRecord.name` when using quick picks).
    var catalogKey: String {
        switch self {
        case .salary: return "Salary"
        case .paycheck: return "Paycheck"
        case .refund: return "Refund"
        case .gift: return "Gift"
        case .sold: return "Sold something"
        case .interest: return "Interest"
        case .cash: return "Cash received"
        case .other: return "Other income"
        }
    }

    func localizedLabel(locale: Locale) -> String {
        BuxCatalogLabel.string(catalogKey, locale: locale)
    }

    var symbol: String {
        switch self {
        case .salary, .paycheck: return "briefcase.fill"
        case .refund: return "arrow.uturn.backward.circle.fill"
        case .gift: return "gift.fill"
        case .sold: return "tag.fill"
        case .interest: return "percent"
        case .cash: return "banknote.fill"
        case .other: return "arrow.down.circle.fill"
        }
    }

    static func matchingStoredLabel(_ stored: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> IncomeSourceQuickPick? {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return allCases.first { pick in
            if pick.catalogKey.caseInsensitiveCompare(trimmed) == .orderedSame { return true }
            if pick.localizedLabel(locale: locale).caseInsensitiveCompare(trimmed) == .orderedSame { return true }
            return false
        }
    }

    static func localizedDisplayName(for storedLabel: String, locale: Locale) -> String {
        if let pick = matchingStoredLabel(storedLabel, locale: locale) {
            return pick.localizedLabel(locale: locale)
        }
        return storedLabel
    }
}

/// When to show merchant logos vs income/refund/category SF Symbols.
enum ExpenseLedgerAvatarPolicy {
    private static let transferKeywords: [String] = [
        "internet transfer", "online transfer", "online banking", "bank transfer",
        "wire transfer", "faster payment", "faster payments", "fps payment",
        "standing order", "direct debit", "sepa", "ach ", "ach transfer",
        "transfer to", "transfer from", "payment to", "payment from",
        "mobile transfer", "internal transfer", "account transfer",
        "sent you", "sent me", "received from", "money sent", "money received",
        "p2p", "person to person", "remittance", "interac", "eft ",
        "bacs payment", "chaps payment", "wire ", " remit",
    ]

    static func isMoneyTransfer(for record: ExpenseRecord) -> Bool {
        if record.isRefund { return false }
        if IncomeSourceQuickPick.matchingStoredLabel(record.name) != nil { return false }

        let haystack = walletLabelHaystack(for: record)
        guard !haystack.isEmpty else { return false }

        if hasKnownMerchantBrand(for: record, haystack: haystack) { return false }

        let folded = haystack
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let hasTransferKeyword = matchesTransferKeywords(folded)
        let isBank = WalletCategoryLexicon.isFinancialInstitution(folded)

        // Bank-branded movement — keep bank logo (user OK with that).
        if isBank { return false }

        if hasTransferKeyword { return true }

        // Credits from a person (e.g. wife) — money in, not a store.
        if record.amountValue > 0 {
            switch record.transactionCategory {
            case .personal, .other:
                return true
            case .income:
                if SalaryPayrollMatcher.isSalaryTagged(record) { return false }
                if hasTransferKeyword { return true }
                // Wallet credits tagged income but linked to a person, not a retailer.
                if record.merchantId != nil { return true }
                return false
            default:
                break
            }
        }

        // Debits to a person / cash movement without a retail brand.
        if record.amountValue < 0, record.transactionCategory == .personal {
            return true
        }

        return false
    }

    static func shouldUseMerchantLogo(for record: ExpenseRecord) -> Bool {
        if isMoneyTransfer(for: record) { return false }
        if record.merchantId != nil { return true }
        guard record.amountValue <= 0, record.transactionCategory != .income else { return false }
        if IncomeSourceQuickPick.matchingStoredLabel(record.name) != nil { return false }
        if record.isRefund { return false }
        return resolvedMerchantDisplayName(for: record) != nil
    }

    static func resolvedMerchantDisplayName(for record: ExpenseRecord) -> String? {
        let store = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !store.isEmpty { return store }
        if record.merchantId != nil {
            let label = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return label.isEmpty ? nil : label
        }
        let label = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return nil }
        if IncomeSourceQuickPick.matchingStoredLabel(label) != nil { return nil }
        return label
    }

    static func merchantLogoName(for record: ExpenseRecord, linkedMerchantName: String?) -> String? {
        guard shouldUseMerchantLogo(for: record) else { return nil }
        if let linked = linkedMerchantName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !linked.isEmpty {
            return linked
        }
        return resolvedMerchantDisplayName(for: record)
    }

    static func resolvedStyle(
        for record: ExpenseRecord,
        categoryRecords: [ExpenseCategoryRecord],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> (symbol: String, foreground: Color, background: Color) {
        if isMoneyTransfer(for: record) {
            return moneyTransferStyle(for: record)
        }

        if record.isRefund {
            return quickPickStyle(.refund)
        }

        if record.transactionCategory == .income || record.amountValue > 0 {
            if isOtherIncomePresentation(record, locale: locale) {
                return ("arrow.down.circle.fill", .green, Color.green.opacity(0.18))
            }
            if let pick = IncomeSourceQuickPick.matchingStoredLabel(record.name, locale: locale) {
                return quickPickStyle(pick)
            }
            return ("arrow.down.circle.fill", .green, Color.green.opacity(0.18))
        }

        if let categoryId = record.categoryId,
           let custom = categoryRecords.first(where: { $0.id == categoryId }) {
            return (
                custom.icon,
                ExpenseCategoryStyle.foreground(for: custom.color),
                ExpenseCategoryStyle.background(for: custom.color)
            )
        }

        let raw = record.transactionCategory
        if let def = ExpenseCategoryCatalog.systemDefinitions.first(where: { $0.0 == raw }) {
            return (
                def.icon,
                ExpenseCategoryStyle.foreground(for: def.color),
                ExpenseCategoryStyle.background(for: def.color)
            )
        }

        return ("square.grid.2x2.fill", .gray, Color.gray.opacity(0.14))
    }

    private static func isOtherIncomePresentation(_ record: ExpenseRecord, locale: Locale) -> Bool {
        guard record.transactionCategory == .income || record.amountValue > 0 else { return false }
        if IncomeSourceQuickPick.matchingStoredLabel(record.name, locale: locale) == .other { return true }
        let trimmed = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.localizedCaseInsensitiveCompare("Other income") == .orderedSame
            || trimmed.localizedCaseInsensitiveCompare(IncomeSourceQuickPick.other.catalogKey) == .orderedSame
    }

    private static func quickPickStyle(_ pick: IncomeSourceQuickPick) -> (String, Color, Color) {
        switch pick {
        case .salary, .paycheck:
            return ("briefcase.fill", .mint, Color.mint.opacity(0.2))
        case .refund:
            return ("arrow.uturn.backward.circle.fill", .green, Color.green.opacity(0.18))
        case .gift:
            return ("gift.fill", .pink, Color.pink.opacity(0.18))
        case .sold:
            return ("tag.fill", .indigo, Color.indigo.opacity(0.18))
        case .interest:
            return ("percent", .teal, Color.teal.opacity(0.18))
        case .cash:
            return ("banknote.fill", .green, Color.green.opacity(0.18))
        case .other:
            return ("arrow.down.circle.fill", .green, Color.green.opacity(0.18))
        }
    }

    private static func moneyTransferStyle(for record: ExpenseRecord) -> (String, Color, Color) {
        if record.amountValue > 0 {
            return ("banknote.fill", .green, Color.green.opacity(0.2))
        }
        return ("arrow.up.circle.fill", .orange, Color.orange.opacity(0.2))
    }

    private static func walletLabelHaystack(for record: ExpenseRecord) -> String {
        if let notes = record.notes,
           let raw = WalletStatementIntelligence.rawLabelFromStoredNote(notes),
           !raw.isEmpty {
            return raw
        }
        let merchant = record.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !merchant.isEmpty { return merchant }
        return record.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchesTransferKeywords(_ haystack: String) -> Bool {
        transferKeywords.contains { haystack.contains($0) }
    }

    private static func hasKnownMerchantBrand(for record: ExpenseRecord, haystack: String) -> Bool {
        let country = (
            MerchantDomainResolver.resolveCountryFromCurrency(record.currencyCode)
                ?? MerchantDomainResolver.currentCountryISO()
        ).uppercased()
        if MerchantBrandIndex.resolve(label: haystack, countryISO: country) != nil { return true }
        if MerchantCatalog.domain(for: haystack) != nil { return true }
        return false
    }
}

struct ExpenseLedgerAvatarView: View {
    @EnvironmentObject private var brain: BuxMuseBrain

    let record: ExpenseRecord
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let logoContext = linkedLogoContext {
                AsyncMerchantLogoView(
                    merchantName: logoContext.name,
                    knownDomain: logoContext.knownDomain,
                    merchantRecordId: record.merchantId,
                    size: size
                )
            } else {
                categoryAvatar
            }
        }
        .frame(width: size, height: size)
    }

    private var linkedLogoContext: (name: String, knownDomain: String?)? {
        guard ExpenseLedgerAvatarPolicy.shouldUseMerchantLogo(for: record) else { return nil }
        let context = brain.merchantLogoContext(for: record)
        guard let name = ExpenseLedgerAvatarPolicy.merchantLogoName(
            for: record,
            linkedMerchantName: context?.name
        ) else { return nil }
        return (name, context?.knownDomain)
    }

    private var categoryAvatar: some View {
        let style = ExpenseLedgerAvatarPolicy.resolvedStyle(
            for: record,
            categoryRecords: brain.categoryRecords
        )
        return ZStack {
            Circle()
                .fill(style.background)
                .frame(width: size, height: size)
            Image(systemName: style.symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(style.foreground)
        }
    }
}

enum ExpenseCategoryStyle {
    static func foreground(for name: String) -> Color {
        switch name.lowercased() {
        case "mint", "green": return .mint
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "brown": return .brown
        case "pink": return .pink
        case "indigo": return .indigo
        case "red": return .red
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "teal": return .teal
        default: return .gray
        }
    }

    static func background(for name: String) -> Color {
        foreground(for: name).opacity(0.18)
    }
}

/// Live preview while composing an income entry (sheet).
struct IncomeLedgerAvatarPreview: View {
    @EnvironmentObject private var brain: BuxMuseBrain

    let label: String
    let linkedStoreName: String
    let merchantId: UUID?
    let categoryId: UUID?
    let categoryRaw: String
    var size: CGFloat = 44

    var body: some View {
        ExpenseLedgerAvatarView(record: previewRecord, size: size)
            .environmentObject(brain)
    }

    private var previewRecord: ExpenseRecord {
        let displayLabel = label.isEmpty ? "Income" : label
        let store = linkedStoreName.trimmingCharacters(in: .whitespacesAndNewlines)
        let merchantField: String
        if merchantId != nil, !store.isEmpty {
            merchantField = store
        } else {
            merchantField = displayLabel
        }
        return ExpenseRecord(
            name: displayLabel,
            amountValue: 1,
            currencyCode: "USD",
            categoryId: categoryId,
            merchantId: merchantId,
            date: Date(),
            categoryRaw: categoryRaw,
            merchantName: merchantField
        )
    }
}
