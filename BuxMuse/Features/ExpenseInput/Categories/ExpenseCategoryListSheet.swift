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
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Button("Done") { dismiss() }
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Categories")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Spacer()
                    Button("Add") { showEditor = true }
                        .foregroundColor(themeManager.current.accentColor)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, 20)

                List {
                    ForEach(categories) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(themeManager.current.accentColor)
                            Text(category.name)
                                .font(.system(size: 15, weight: .semibold))
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
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
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
        categories = (try? brain.fetchAllCategoryRecords()) ?? []
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
