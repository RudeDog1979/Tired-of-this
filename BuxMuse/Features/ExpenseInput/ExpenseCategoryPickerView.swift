//
//  ExpenseCategoryPickerView.swift
//  BuxMuse
//
//  System + custom categories with inline creation.
//

import SwiftUI

struct ExpenseCategoryPickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain

    @Binding var selectedCategoryId: UUID?
    @Binding var selectedCategory: TransactionCategory
    var emphasizeOnAppear: Bool = false
    /// When false, Income is hidden from the expense picker (still available when logging income).
    var includesIncome: Bool = false

    @State private var categories: [ExpenseCategoryRecord] = []
    @State private var showCreateCategory = false
    @State private var emphasisPulse = false
    @Namespace private var pillNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { cat in
                        categoryChip(cat)
                    }
                    newCategoryChip
                }
                .padding(.horizontal, 4)
            }
            .buxHorizontalScrollEdgeFade(background: themeManager.cardFill(for: colorScheme))
        }
        .padding(.vertical, emphasizeOnAppear && emphasisPulse ? 4 : 0)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeManager.current.accentColor.opacity(emphasisPulse ? 0.45 : 0), lineWidth: 2)
        )
        .onAppear {
            reload()
            guard emphasizeOnAppear else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatCount(2, autoreverses: true)) {
                emphasisPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { emphasisPulse = false }
            }
        }
        .onChange(of: showCreateCategory) { _, isPresented in
            if !isPresented { reload() }
        }
        .sheet(isPresented: $showCreateCategory) {
            ExpenseCategoryEditorSheet { name, icon, color in
                if let created = try? brain.createCategory(name: name, icon: icon, color: color) {
                    reload()
                    select(created)
                }
            }
            .environmentObject(themeManager)
            .buxThemedSheetContent()
        }
    }

    private func categoryChip(_ cat: ExpenseCategoryRecord) -> some View {
        let isSelected = selectedCategoryId == cat.id
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                select(cat)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(cat.name)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? themeManager.current.accentColor : themeManager.labelSecondary(for: colorScheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(themeManager.pillActiveChipFill(for: colorScheme))
                            .matchedGeometryEffect(id: "expense_cat_pill", in: pillNamespace)
                    } else {
                        Capsule()
                            .fill(themeManager.pillTrackFill(for: colorScheme))
                    }
                }
            )
        }
        .buttonStyle(MorphingPillButtonStyle())
    }

    private var newCategoryChip: some View {
        Button {
            showCreateCategory = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("New")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(themeManager.current.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .stroke(themeManager.current.accentColor.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(MorphingPillButtonStyle())
    }

    private func select(_ cat: ExpenseCategoryRecord) {
        selectedCategoryId = cat.id
        if let raw = cat.systemCategoryRaw, let tc = TransactionCategory(rawValue: raw) {
            selectedCategory = tc
        } else {
            selectedCategory = .other
        }
    }

    private func reload() {
        let all = (try? brain.fetchAllCategoryRecords()) ?? []
        let systemOrder = ExpenseCategoryCatalog.systemDefinitions.map(\.0.rawValue)

        let system = all
            .filter { !$0.isCustom }
            .sorted { lhs, rhs in
                let left = systemOrder.firstIndex(of: lhs.systemCategoryRaw ?? "") ?? Int.max
                let right = systemOrder.firstIndex(of: rhs.systemCategoryRaw ?? "") ?? Int.max
                if left != right { return left < right }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        let custom = all
            .filter(\.isCustom)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var merged = system + custom
        if !includesIncome {
            merged.removeAll { $0.systemCategoryRaw == TransactionCategory.income.rawValue }
        }
        categories = merged

        if selectedCategoryId == nil,
           let match = categories.first(where: { $0.systemCategoryRaw == selectedCategory.rawValue }) {
            selectedCategoryId = match.id
        } else if let selectedCategoryId,
                  !categories.contains(where: { $0.id == selectedCategoryId }),
                  let fallback = categories.first(where: { $0.systemCategoryRaw == TransactionCategory.other.rawValue }) {
            select(fallback)
        }
    }
}
