//
//  StudioProjectMilestonesEditorSheet.swift
//  BuxMuse
//

import SwiftUI

struct StudioProjectMilestonesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    let projectId: UUID

    @State private var milestones: [StudioProjectMilestone] = []
    @State private var editingMilestone: StudioProjectMilestone?
    @State private var showAddSheet = false

    private var project: StudioProject? { store.project(id: projectId) }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                if milestones.isEmpty {
                    VStack(spacing: BuxTokens.section) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.secondary)
                        BuxCatalogDynamicText(key: "No milestones yet")
                            .font(.system(size: 16, weight: .bold))
                        BuxCatalogDynamicText(key: "Add delivery dates, client reviews, or phase handoffs. They appear on the project planner timeline.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BuxTokens.marginRegular)
                        BuxButton(title: "Add milestone", systemImage: "plus", role: .primary, expands: false) {
                            showAddSheet = true
                        }
                    }
                } else {
                    BuxThemedCardForm {
                        BuxFormSection(title: "Milestones") {
                            ForEach($milestones) { $milestone in
                                milestoneRow(milestone: $milestone)
                                if milestone.id != milestones.last?.id {
                                    BuxFormRowDivider()
                                }
                            }
                        }
                    }
                }
            }
            .buxCatalogNavigationTitle("Planner milestones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarSaveButton(isDirty: project != nil) {
                        persist()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    if !milestones.isEmpty {
                        Button {
                            showAddSheet = true
                        } label: {
                            Label {
                                BuxCatalogDynamicText(key: "Add milestone")
                            } icon: {
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                }
            }
            .onAppear { reloadFromStore() }
            .sheet(isPresented: $showAddSheet) {
                StudioProjectMilestoneFormSheet(milestone: nil, siblingMilestones: milestones) { newMilestone in
                    milestones.append(newMilestone)
                    milestones.sort { $0.dueDate < $1.dueDate }
                }
                .environmentObject(themeManager)
            }
            .sheet(item: $editingMilestone) { item in
                StudioProjectMilestoneFormSheet(
                    milestone: item,
                    siblingMilestones: milestones.filter { $0.id != item.id }
                ) { updated in
                    if let index = milestones.firstIndex(where: { $0.id == updated.id }) {
                        milestones[index] = updated
                        milestones.sort { $0.dueDate < $1.dueDate }
                    }
                }
                .environmentObject(themeManager)
            }
            .buxStudioSheetContent()
        }
    }

    private func milestoneRow(milestone: Binding<StudioProjectMilestone>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                milestone.wrappedValue.isCompleted.toggle()
            } label: {
                Image(systemName: milestone.wrappedValue.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(milestone.wrappedValue.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.wrappedValue.title)
                    .font(.system(size: 14, weight: .bold))
                    .strikethrough(milestone.wrappedValue.isCompleted)
                Text(
                    BuxDisplayDate.monthDay(
                        from: milestone.wrappedValue.dueDate,
                        locale: appSettingsManager.interfaceLocale
                    )
                )
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
                if let dep = milestone.wrappedValue.dependsOnMilestoneId,
                   let parent = milestones.first(where: { $0.id == dep }) {
                    Text(
                        BuxLocalizedString.format(
                            "After: %@",
                            locale: appSettingsManager.interfaceLocale,
                            parent.title
                        )
                    )
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
                if !milestone.wrappedValue.notes.isEmpty {
                    Text(milestone.wrappedValue.notes)
                        .font(.system(size: 10, weight: .medium))
                        .buxLabelSecondary()
                        .lineLimit(2)
                }
            }
            Spacer()
            Button {
                editingMilestone = milestone.wrappedValue
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .buxFormFieldPadding()
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                milestones.removeAll { $0.id == milestone.wrappedValue.id }
            } label: {
                Label(BuxCatalogLabel.string("Delete", locale: appSettingsManager.interfaceLocale), systemImage: "trash")
            }
        }
    }

    private func reloadFromStore() {
        milestones = project?.plannerMilestones ?? []
    }

    private func persist() {
        guard var project else { return }
        project.plannerMilestones = milestones
        store.updateProject(project)
        BuxSaveFeedback.success()
    }
}

private struct StudioProjectMilestoneFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let milestone: StudioProjectMilestone?
    let siblingMilestones: [StudioProjectMilestone]
    let onSave: (StudioProjectMilestone) -> Void

    @State private var title = ""
    @State private var dueDate = Date()
    @State private var isCompleted = false
    @State private var notes = ""
    @State private var dependsOnId: UUID?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        NavigationStack {
            BuxThemedCardForm {
                BuxFormSection(title: "Milestone") {
                    TextField(loc("Title"), text: $title)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    DatePicker(loc("Due date"), selection: $dueDate, displayedComponents: .date)
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Toggle(loc("Completed"), isOn: $isCompleted)
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField(loc("Notes (optional)"), text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .buxFormFieldPadding()
                    if !siblingMilestones.isEmpty {
                        BuxFormRowDivider()
                        Picker(loc("Depends on"), selection: $dependsOnId) {
                            BuxCatalogDynamicText(key: "None").tag(UUID?.none)
                            ForEach(siblingMilestones.sorted(by: { $0.dueDate < $1.dueDate })) { s in
                                Text(s.title).tag(Optional(s.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle(milestone == nil ? "New milestone" : "Edit milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarSaveButton(isDirty: canSave) {
                        let item = StudioProjectMilestone(
                            id: milestone?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            dueDate: dueDate,
                            isCompleted: isCompleted,
                            notes: notes,
                            dependsOnMilestoneId: dependsOnId
                        )
                        onSave(item)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let milestone {
                    title = milestone.title
                    dueDate = milestone.dueDate
                    isCompleted = milestone.isCompleted
                    notes = milestone.notes
                    dependsOnId = milestone.dependsOnMilestoneId
                }
            }
            .buxStudioSheetContent()
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Milestone editor for a project being created (not yet in `StudioStore`).
struct StudioProjectMilestonesDraftEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var milestones: [StudioProjectMilestone]

    @State private var editingMilestone: StudioProjectMilestone?
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                if milestones.isEmpty {
                    VStack(spacing: BuxTokens.section) {
                        BuxCatalogDynamicText(key: "Add milestones before saving the project.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BuxTokens.marginRegular)
                        BuxButton(title: "Add milestone", systemImage: "plus", role: .primary, expands: false) {
                            showAddSheet = true
                        }
                    }
                } else {
                    BuxThemedCardForm {
                        BuxFormSection(title: "Milestones") {
                            ForEach($milestones) { $milestone in
                                draftMilestoneRow(milestone: $milestone)
                                if milestone.id != milestones.last?.id {
                                    BuxFormRowDivider()
                                }
                            }
                        }
                    }
                }
            }
            .buxCatalogNavigationTitle("Planner milestones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarSaveButton(isDirty: true) { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                StudioProjectMilestoneFormSheet(milestone: nil, siblingMilestones: milestones) { newMilestone in
                    milestones.append(newMilestone)
                    milestones.sort { $0.dueDate < $1.dueDate }
                }
                .environmentObject(themeManager)
            }
            .sheet(item: $editingMilestone) { item in
                StudioProjectMilestoneFormSheet(
                    milestone: item,
                    siblingMilestones: milestones.filter { $0.id != item.id }
                ) { updated in
                    if let index = milestones.firstIndex(where: { $0.id == updated.id }) {
                        milestones[index] = updated
                        milestones.sort { $0.dueDate < $1.dueDate }
                    }
                }
                .environmentObject(themeManager)
            }
            .buxStudioSheetContent()
        }
    }

    private func draftMilestoneRow(milestone: Binding<StudioProjectMilestone>) -> some View {
        HStack {
            Text(milestone.wrappedValue.title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(
                BuxDisplayDate.monthDay(
                    from: milestone.wrappedValue.dueDate,
                    locale: appSettingsManager.interfaceLocale
                )
            )
                .font(.system(size: 11, weight: .medium))
                .buxLabelSecondary()
        }
        .buxFormFieldPadding()
        .onTapGesture { editingMilestone = milestone.wrappedValue }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                milestones.removeAll { $0.id == milestone.wrappedValue.id }
            } label: {
                Label(BuxCatalogLabel.string("Delete", locale: appSettingsManager.interfaceLocale), systemImage: "trash")
            }
        }
    }
}
