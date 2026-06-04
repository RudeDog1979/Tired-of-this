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

struct ExpenseLedgerAvatarView: View {
    @EnvironmentObject private var brain: BuxMuseBrain

    let record: ExpenseRecord
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let storeName = linkedStoreDisplayName {
                AsyncMerchantLogoView(merchantName: storeName, size: size)
            } else {
                categoryAvatar
            }
        }
        .frame(width: size, height: size)
    }

    private var linkedStoreDisplayName: String? {
        guard let name = brain.merchantLogoName(for: record)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        return name
    }

    private var categoryAvatar: some View {
        let style = resolvedCategoryStyle()
        return ZStack {
            Circle()
                .fill(style.background)
                .frame(width: size, height: size)
            Image(systemName: style.symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(style.foreground)
        }
    }

    private func resolvedCategoryStyle() -> (symbol: String, foreground: Color, background: Color) {
        if isOtherIncomePresentation {
            return ("arrow.down.circle.fill", .green, Color.green.opacity(0.18))
        }

        if let pick = IncomeSourceQuickPick.matchingStoredLabel(record.name) {
            return quickPickStyle(pick)
        }

        if let categoryId = record.categoryId,
           let custom = (try? brain.fetchAllCategoryRecords())?.first(where: { $0.id == categoryId }) {
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

    private var isOtherIncomePresentation: Bool {
        guard record.transactionCategory == .income || record.amountValue > 0 else { return false }
        if IncomeSourceQuickPick.matchingStoredLabel(record.name) == .other { return true }
        if record.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("Other income") == .orderedSame
            || record.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(
                IncomeSourceQuickPick.other.catalogKey
            ) == .orderedSame {
            return true
        }
        return false
    }

    private func quickPickStyle(_ pick: IncomeSourceQuickPick) -> (String, Color, Color) {
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
