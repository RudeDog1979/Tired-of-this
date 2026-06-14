//
//  ExpenseCategorySplitEditor.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Split one expense across 2–5 categories with amount validation.
//

import SwiftUI

struct ExpenseCategorySplitEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var isEnabled: Bool
    @Binding var lines: [ExpenseCategorySplitLine]
    let totalAmountString: String
    let validationMessage: String?

    @State private var categories: [ExpenseCategoryRecord] = []

    private var accent: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Toggle(isOn: $isEnabled.animation(.buxSnap)) {
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogText.text("Split across categories")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    BuxCatalogText.text("Divide this purchase into 2–5 category lines.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(accent)
            .onChange(of: isEnabled) { _, enabled in
                if enabled, lines.count < 2 {
                    seedDefaultLines()
                } else if !enabled {
                    lines = []
                }
            }

            if isEnabled {
                VStack(spacing: 10) {
                    ForEach($lines) { $line in
                        splitLineRow(line: $line)
                    }

                    if lines.count < 5 {
                        Button {
                            addLine()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                BuxCatalogText.text("Add line")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    }

                    splitSummaryRow
                }
                .padding(.top, 4)
            }
        }
        .padding(BuxLayout.section)
        .expensesThemedCardChrome(cornerRadius: 20)
        .onAppear { reloadCategories() }
    }

    @ViewBuilder
    private func splitLineRow(line: Binding<ExpenseCategorySplitLine>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                categoryMenu(for: line)

                TextField(
                    BuxCatalogLabel.string("Amount", locale: locale),
                    text: line.amountString
                )
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .multilineTextAlignment(.trailing)
                .frame(width: 88)

                if lines.count > 2 {
                    Button {
                        removeLine(id: line.wrappedValue.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(themeManager.cardFill(for: colorScheme).opacity(0.65))
        )
    }

    private func categoryMenu(for line: Binding<ExpenseCategorySplitLine>) -> some View {
        Menu {
            ForEach(systemCategories, id: \.rawValue) { category in
                Button(category.localizedDisplayName(locale: locale)) {
                    line.wrappedValue.categoryRaw = category.rawValue
                    line.wrappedValue.categoryId = try? brain.categoryId(for: category)
                }
            }
            if !customCategories.isEmpty {
                Divider()
                ForEach(customCategories) { tag in
                    Button(tag.localizedDisplayName(locale: locale)) {
                        line.wrappedValue.categoryId = tag.id
                        line.wrappedValue.categoryRaw = tag.systemCategoryRaw ?? TransactionCategory.other.rawValue
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon(for: line.wrappedValue))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                Text(label(for: line.wrappedValue))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var splitSummaryRow: some View {
        let total = parsedTotal
        let allocated = lines.compactMap(\.amountDecimal).reduce(0, +)
        let delta = total - allocated
        let isBalanced = abs(NSDecimalNumber(decimal: delta).doubleValue) < 0.01

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                BuxCatalogText.text("Allocated")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                Spacer()
                Text(formatCurrency(allocated))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isBalanced ? Color.green : themeManager.labelPrimary(for: colorScheme))
            }
            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
            } else if !isBalanced, total > 0 {
                Text(
                    BuxLocalizedString.format(
                        "%@ remaining",
                        locale: locale,
                        formatCurrency(delta)
                    )
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
            }
        }
    }

    private var parsedTotal: Decimal {
        let cleaned = totalAmountString.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned) ?? 0
    }

    private var systemCategories: [TransactionCategory] {
        TransactionCategory.allCases.filter { $0 != .income }
    }

    private var customCategories: [ExpenseCategoryRecord] {
        categories.filter(\.isCustom)
    }

    private func reloadCategories() {
        categories = (try? brain.fetchAllCategoryRecords()) ?? []
    }

    private func seedDefaultLines() {
        let otherId = try? brain.categoryId(for: .other)
        lines = [
            ExpenseCategorySplitLine(categoryId: selectedCategoryIdFallback(), categoryRaw: TransactionCategory.groceries.rawValue, amountString: ""),
            ExpenseCategorySplitLine(categoryId: otherId, categoryRaw: TransactionCategory.other.rawValue, amountString: "")
        ]
    }

    private func selectedCategoryIdFallback() -> UUID? {
        try? brain.categoryId(for: .groceries)
    }

    private func addLine() {
        guard lines.count < 5 else { return }
        let otherId = try? brain.categoryId(for: .other)
        lines.append(ExpenseCategorySplitLine(categoryId: otherId, categoryRaw: TransactionCategory.other.rawValue))
    }

    private func removeLine(id: UUID) {
        guard lines.count > 2 else { return }
        lines.removeAll { $0.id == id }
    }

    private func label(for line: ExpenseCategorySplitLine) -> String {
        if let categoryId = line.categoryId,
           let tag = categories.first(where: { $0.id == categoryId }) {
            return tag.localizedDisplayName(locale: locale)
        }
        return line.transactionCategory.localizedDisplayName(locale: locale)
    }

    private func icon(for line: ExpenseCategorySplitLine) -> String {
        if let categoryId = line.categoryId,
           let tag = categories.first(where: { $0.id == categoryId }) {
            return tag.icon
        }
        return ExpenseCategoryCatalog.icon(forDisplayName: line.transactionCategory.displayName, customCategories: categories, locale: locale)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        appSettingsManager.format(value)
    }
}
