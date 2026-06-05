//
//  StudioTimeEntryEditorSheet.swift
//  BuxMuse
//

import SwiftUI

struct StudioTimeEntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let projectId: UUID
    let entryId: UUID

    @State private var notes: String = ""
    @State private var isBillable: Bool = true
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    init(projectId: UUID, entry: StudioTimeEntry) {
        self.projectId = projectId
        self.entryId = entry.id
        _notes = State(initialValue: entry.notes)
        _isBillable = State(initialValue: entry.isBillable)
        _startTime = State(initialValue: entry.startTime)
        _endTime = State(initialValue: entry.endTime)
    }

    var body: some View {
        NavigationStack {
            BuxThemedCardForm {
                BuxFormSection(title: "Time entry") {
                    TextField(loc("Notes"), text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Toggle(loc("Billable"), isOn: $isBillable)
                        .tint(themeManager.current.accentColor)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    DatePicker(loc("Start"), selection: $startTime)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    DatePicker(loc("End"), selection: $endTime)
                        .buxFormFieldPadding()
                }
            }
            .buxCatalogNavigationTitle("Edit time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarSaveButton(isDirty: endTime > startTime) {
                        save()
                    }
                }
            }
        }
        .buxStudioSheetContent()
    }

    private func save() {
        guard var project = store.project(id: projectId),
              let index = project.timeEntries.firstIndex(where: { $0.id == entryId }) else { return }
        var updated = project.timeEntries[index]
        updated.notes = notes
        updated.isBillable = isBillable
        updated.startTime = startTime
        updated.endTime = endTime
        project.timeEntries[index] = updated
        store.updateProject(project)
        BuxSaveFeedback.success()
        dismiss()
    }
}
