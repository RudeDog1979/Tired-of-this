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

                            Text(category.name)
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
            .buxThemedSheetContent()
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
    let onSave: (String, String, String) -> Void

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("New category")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.top, 24)
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                Button("Save") {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onSave(name, icon, color)
                    dismiss()
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(themeManager.current.accentColor)
                Spacer()
            }
        }
        .presentationDetents([.medium])
    }
}

struct ExpenseCategoryMergeSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let source: ExpenseCategoryRecord
    let targets: [ExpenseCategoryRecord]
    let onMerge: (ExpenseCategoryRecord) -> Void

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("Merge \(source.name) into…")
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
