//
//  AgreementScratchpadEditorView.swift
//  BuxMuse
//
//  Pro Studio — local agreement draft editor & share.
//

import SwiftUI

struct AgreementScratchpadListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: StudioStore

    @State private var showNewDraft = false

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Agreement drafts") {
                if store.agreementDrafts.isEmpty {
                    Text("No drafts yet. Create one for a client or project before work starts.")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                        .buxFormFieldPadding()
                } else {
                    ForEach(Array(store.agreementDrafts.sorted { $0.updatedAt > $1.updatedAt }.enumerated()), id: \.element.id) { index, draft in
                        NavigationLink {
                            AgreementScratchpadEditorView(draft: draft)
                                .environmentObject(store)
                                .environmentObject(themeManager)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(draft.title)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(draftSubtitle(draft))
                                    .font(.system(size: 11, weight: .medium))
                                    .buxLabelSecondary()
                                    .lineLimit(1)
                            }
                            .buxFormFieldPadding()
                        }
                        if index < store.agreementDrafts.count - 1 {
                            BuxFormRowDivider()
                        }
                    }
                }

                BuxFormRowDivider()
                Button(action: { showNewDraft = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New agreement draft")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                }
                .buxFormFieldPadding()
            }
        }
        .navigationTitle("Agreement drafts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewDraft) {
            NavigationStack {
                AgreementScratchpadEditorView(
                    draft: AgreementDraft(title: "New agreement")
                )
                .environmentObject(store)
                .environmentObject(themeManager)
            }
            .buxStudioSheetContent()
        }
    }

    private func draftSubtitle(_ draft: AgreementDraft) -> String {
        var parts: [String] = []
        if let clientId = draft.clientId,
           let name = store.clients.first(where: { $0.id == clientId })?.name {
            parts.append(name)
        }
        if let projectId = draft.projectId,
           let name = store.projects.first(where: { $0.id == projectId })?.name {
            parts.append(name)
        }
        parts.append(draft.updatedAt.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " · ")
    }
}

struct AgreementScratchpadEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: StudioStore

    @State private var draft: AgreementDraft
    @State private var didSave = false

    init(draft: AgreementDraft) {
        _draft = State(initialValue: draft)
    }

    init(project: StudioProject, existingDraft: AgreementDraft?) {
        if let existingDraft {
            _draft = State(initialValue: existingDraft)
        } else {
            _draft = State(initialValue: AgreementDraft(
                title: "\(project.name) agreement",
                clientId: project.clientId,
                projectId: project.id
            ))
        }
    }

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Basics") {
                TextField("Title", text: $draft.title)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker("Client", selection: clientBinding) {
                    Text("None").tag(UUID?.none)
                    ForEach(store.clients) { client in
                        Text(client.name).tag(Optional(client.id))
                    }
                }
                .pickerStyle(.menu)
                .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker("Project", selection: projectBinding) {
                    Text("None").tag(UUID?.none)
                    ForEach(store.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Scope & deliverables") {
                scratchpadField("What's included (scope bullets)", text: $draft.scopeBullets)
                BuxFormRowDivider()
                scratchpadField("Deliverables", text: $draft.deliverables)
                BuxFormRowDivider()
                scratchpadField("Out of scope", text: $draft.outOfScope)
            }

            BuxFormSection(title: "Sign-off (local record)") {
                TextField("Client name", text: $draft.signOffName)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Toggle(isOn: signOffDateEnabled) {
                    Text("Approval date recorded")
                        .font(.system(size: 15, weight: .semibold))
                }
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()
                if draft.signOffDate != nil {
                    BuxFormRowDivider()
                    DatePicker("Date", selection: signOffDateBinding, displayedComponents: .date)
                        .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Share") {
                ShareLink(item: shareText) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share agreement text")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                }
                .buxFormFieldPadding()
            }
        }
        .navigationTitle("Edit draft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BuxToolbarCancelButton { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                BuxToolbarSaveButton(isDirty: true) {
                    store.upsertAgreementDraft(draft)
                    BuxSaveFeedback.success()
                    didSave = true
                    dismiss()
                }
            }
        }
        .onDisappear {
            if !didSave, hasMeaningfulContent {
                store.upsertAgreementDraft(draft)
            }
        }
    }

    private var hasMeaningfulContent: Bool {
        !draft.scopeBullets.isEmpty
            || !draft.deliverables.isEmpty
            || !draft.outOfScope.isEmpty
            || !draft.signOffName.isEmpty
    }

    private var shareText: String {
        draft.formattedShareText(
            clientName: draft.clientId.flatMap { id in store.clients.first(where: { $0.id == id })?.name },
            projectName: draft.projectId.flatMap { id in store.projects.first(where: { $0.id == id })?.name }
        )
    }

    private var clientBinding: Binding<UUID?> {
        Binding(
            get: { draft.clientId },
            set: { draft.clientId = $0 }
        )
    }

    private var projectBinding: Binding<UUID?> {
        Binding(
            get: { draft.projectId },
            set: { draft.projectId = $0 }
        )
    }

    private var signOffDateEnabled: Binding<Bool> {
        Binding(
            get: { draft.signOffDate != nil },
            set: { enabled in
                if enabled {
                    draft.signOffDate = draft.signOffDate ?? Date()
                } else {
                    draft.signOffDate = nil
                }
            }
        )
    }

    private var signOffDateBinding: Binding<Date> {
        Binding(
            get: { draft.signOffDate ?? Date() },
            set: { draft.signOffDate = $0 }
        )
    }

    private func scratchpadField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .lineLimit(4...12)
            .buxFormFieldPadding()
    }
}
