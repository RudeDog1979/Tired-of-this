//
//  ExpenseCategoryListSheet.swift
//  BuxMuse
//

import SwiftUI

struct ExpenseCategoryListSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @State private var categories: [ExpenseCategoryRecord] = []
    @State private var showEditor = false
    @State private var mergeSource: ExpenseCategoryRecord?

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                List {
                    ForEach(categories) { category in
                        HStack(spacing: 14) {
                            BuxContentGlassIcon(systemName: category.icon, diameter: 34, pointSize: 15)

                            Text(category.localizedDisplayName(locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                            Spacer()

                            if category.isCustom {
                                Menu {
                                    Button("Merge…") { mergeSource = category }
                                    Button("Delete", role: .destructive) {
                                        _ = try? brain.deleteCategory(id: category.id)
                                        reload()
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .buxListContentMargins()
                .buxSoftScrollChrome()
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarDoneButton { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    BuxNavIconButton(
                        systemName: "plus",
                        accessibilityLabel: "Add category",
                        action: { showEditor = true }
                    )
                }
            }
            .buxDetailNavigationChrome()
        }
        .buxMeshSheetPresentation()
        .onAppear(perform: reload)
        .sheet(isPresented: $showEditor) {
            ExpenseCategoryEditorSheet { name, icon, color in
                _ = try? brain.createCategory(name: name, icon: icon, color: color)
                reload()
            }
            .environmentObject(themeManager)
        }
        .sheet(item: $mergeSource) { source in
            ExpenseCategoryMergeSheet(source: source, targets: categories.filter { $0.id != source.id }) { target in
                _ = try? brain.mergeCategories(sourceId: source.id, into: target.id)
                reload()
            }
            .environmentObject(themeManager)
            .buxThemedSheetContent()
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

        categories = system + custom
    }
}

struct ExpenseCategoryEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var color = "blue"
    @State private var iconManuallyChosen = false
    let onSave: (String, String, String) -> Void

    private let iconColumns = Array(
        repeating: GridItem(.flexible(minimum: 44), spacing: 8),
        count: 5
    )
    private let colorColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 6
    )

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxLayout.section) {
                        previewSection
                        nameSection
                        iconSection
                        colorSection
                    }
                    .buxScreenContentMargins()
                    .padding(.top, BuxLayout.tight)
                    .padding(.bottom, 48)
                }
                .buxDetailScrollChrome()
                .scrollDismissesKeyboard(.interactively)
            }
            .buxCatalogNavigationTitle("New category")
            .navigationBarTitleDisplayMode(.inline)
            .buxInterfaceLocale()
            .buxThemedPresentation()
            .buxDetailNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: "Save",
                        isEnabled: !trimmedName.isEmpty
                    ) {
                        onSave(trimmedName, icon, color)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(themeManager.current.accentColor)
    }

    private var previewSection: some View {
        previewChip
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Name")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            TextField("Name", text: $name)
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
                .onChange(of: name) { _, newValue in
                    guard !iconManuallyChosen else { return }
                    icon = ExpenseCategoryIconCatalog.suggestedIcon(for: newValue)
                }
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Choose icon")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            iconPickerGrid
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Color")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            colorPickerGrid
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var iconPickerGrid: some View {
        LazyVGrid(columns: iconColumns, spacing: 8) {
            ForEach(ExpenseCategoryIconCatalog.pickerIcons, id: \.self) { symbol in
                Button {
                    iconManuallyChosen = true
                    icon = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            icon == symbol
                                ? themeManager.current.accentColor
                                : themeManager.labelSecondary(for: colorScheme)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    icon == symbol
                                        ? themeManager.current.accentColor.opacity(0.14)
                                        : themeManager.pillTrackFill(for: colorScheme)
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colorPickerGrid: some View {
        LazyVGrid(columns: colorColumns, spacing: 12) {
            ForEach(ExpenseCategoryIconCatalog.pickerColors, id: \.self) { tone in
                Button {
                    color = tone
                } label: {
                    Circle()
                        .fill(ExpenseCategoryStyle.foreground(for: tone))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if color == tone {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .padding(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewChip: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ExpenseCategoryStyle.foreground(for: color))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(ExpenseCategoryStyle.background(for: color))
                }
            Text(name.isEmpty ? "Preview" : name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(themeManager.pillTrackFill(for: colorScheme))
        }
    }
}

struct ExpenseCategoryMergeSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let source: ExpenseCategoryRecord
    let targets: [ExpenseCategoryRecord]
    let onMerge: (ExpenseCategoryRecord) -> Void

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    BuxLocalizedString.format(
                        "Merge %@ into…",
                        locale: appSettingsManager.interfaceLocale,
                        source.localizedDisplayName(locale: appSettingsManager.interfaceLocale)
                    )
                )
                    .font(.system(size: 17, weight: .bold))
                    .padding(.top, 24)
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                List(targets) { target in
                    Button(target.name) {
                        onMerge(target)
                        dismiss()
                    }
                }
                .listStyle(.plain)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
