//
//  StudioAgreementTermsEditorView.swift
//  BuxMuse
//

import SwiftUI

/// Edit pre-made + custom terms for one agreement or Settings defaults.
struct StudioAgreementTermsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var enabledClauseIds: [String]
    @Binding var clauseOverrides: [String: String]
    @Binding var customText: String

    var navigationTitle: String = "Terms & conditions"
    var showSaveAsDefaults: Bool = false

    @State private var editingClause: StudioAgreementTermsClause?
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            BuxThemedCardForm {
                packsSection
                clausesSection
                customSection
                previewSection
                if showSaveAsDefaults {
                    defaultsSection
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .sheet(item: $editingClause) { clause in
                StudioAgreementTermsClauseEditSheet(
                    clause: clause,
                    overrideText: overrideBinding(for: clause.id)
                )
                .environmentObject(themeManager)
            }
            .sheet(isPresented: $showPreview) {
                StudioAgreementTermsPreviewSheet(text: previewText)
            }
        }
        .buxStudioSheetContent()
    }

    private var previewText: String {
        StudioAgreementTermsComposer.composedText(
            enabledClauseIds: enabledClauseIds,
            overrides: clauseOverrides,
            customText: customText,
            locale: appSettingsManager.interfaceLocale
        )
    }

    private var packsSection: some View {
        BuxFormSection(title: "Quick packs") {
            BuxCatalogDynamicText(key: "Start from a set, then turn clauses on/off or edit wording.")
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
                .buxFormFieldPadding()
            ForEach(Array(StudioAgreementTermsPack.allCases.enumerated()), id: \.element.id) { index, pack in
                if index > 0 { BuxFormRowDivider() }
                packRow(pack, replace: true)
                BuxFormRowDivider()
                packRow(pack, replace: false)
            }
        }
    }

    private func packRow(_ pack: StudioAgreementTermsPack, replace: Bool) -> some View {
        let locale = appSettingsManager.interfaceLocale
        return Button {
            applyPack(pack, replace: replace)
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        replace
                            ? StudioAgreementL10n.format("Use %@", locale: locale, pack.catalogTitle(locale: locale))
                            : StudioAgreementL10n.format("Add %@", locale: locale, pack.catalogTitle(locale: locale))
                    )
                        .font(.system(size: 14, weight: .semibold))
                    Text(pack.catalogSubtitle(locale: locale))
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: replace ? "arrow.triangle.2.circlepath" : "plus.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .buxFormFieldPadding()
        }
        .buttonStyle(.plain)
    }

    private var clausesSection: some View {
        BuxFormSection(
            title: StudioAgreementL10n.format(
                "Clauses (%lld on)",
                locale: appSettingsManager.interfaceLocale,
                Int64(enabledClauseIds.count)
            )
        ) {
            ForEach(StudioAgreementTermsCategory.allCases, id: \.self) { category in
                let clauses = StudioAgreementTermsLibrary.allClauses.filter { $0.category == category }
                if !clauses.isEmpty {
                    categoryHeader(category.catalogLabel(locale: appSettingsManager.interfaceLocale))
                    ForEach(clauses) { clause in
                        BuxFormRowDivider()
                        clauseRow(clause)
                    }
                }
            }
        }
    }

    private func categoryHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .buxLabelSecondary()
            .buxFormFieldPadding()
    }

    private func clauseRow(_ clause: StudioAgreementTermsClause) -> some View {
        let isOn = enabledClauseIds.contains(clause.id)
        let isEdited = !(clauseOverrides[clause.id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: toggleBinding(for: clause.id))
                .labelsHidden()
                .tint(themeManager.contrastAccentColor(for: colorScheme))
            VStack(alignment: .leading, spacing: 4) {
                Text(clause.catalogTitle(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 14, weight: .semibold))
                if isEdited {
                    BuxCatalogDynamicText(key: "Custom wording")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            Spacer(minLength: 8)
            if isOn {
                Button("Edit") { editingClause = clause }
                    .font(.system(size: 13, weight: .bold))
            }
        }
        .buxFormFieldPadding()
    }

    private var customSection: some View {
        BuxFormSection(title: "Your own terms") {
            BuxCatalogDynamicText(key: "Added at the end — policies, fees, or language from your lawyer.")
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
                .buxFormFieldPadding()
            BuxFormRowDivider()
            TextField(BuxCatalogLabel.string("Custom terms & conditions", locale: appSettingsManager.interfaceLocale), text: $customText, axis: .vertical)
                .lineLimit(4...16)
                .buxFormFieldPadding()
        }
    }

    private var previewSection: some View {
        BuxFormSection(title: "Preview") {
            Button { showPreview = true } label: {
                Label("Preview full terms", systemImage: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .buxFormFieldPadding()
            BuxFormRowDivider()
            BuxCatalogDynamicText(key: StudioAgreementTermsLibrary.disclaimer)
                .font(.system(size: 11, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
                .buxFormFieldPadding()
        }
    }

    private var defaultsSection: some View {
        BuxFormSection(title: "Defaults for new agreements") {
            Button {
                let settings = SettingsStore.shared
                settings.agreementDefaultEnabledClauseIds = enabledClauseIds
                settings.agreementDefaultCustomTerms = customText
                BuxSaveFeedback.success()
            } label: {
                Label("Save as my default terms", systemImage: "bookmark.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .buxFormFieldPadding()
        }
    }

    private func applyPack(_ pack: StudioAgreementTermsPack, replace: Bool) {
        let ids = StudioAgreementTermsLibrary.clauseIds(for: pack)
        if replace {
            enabledClauseIds = ids
            clauseOverrides = [:]
        } else {
            var set = Set(enabledClauseIds)
            set.formUnion(ids)
            enabledClauseIds = StudioAgreementTermsLibrary.allClauses.map(\.id).filter { set.contains($0) }
        }
    }

    private func toggleBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { enabledClauseIds.contains(id) },
            set: { on in
                if on {
                    if !enabledClauseIds.contains(id) { enabledClauseIds.append(id) }
                } else {
                    enabledClauseIds.removeAll { $0 == id }
                }
            }
        )
    }

    private func overrideBinding(for id: String) -> Binding<String> {
        Binding(
            get: { clauseOverrides[id] ?? "" },
            set: { new in
                let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    clauseOverrides.removeValue(forKey: id)
                } else {
                    clauseOverrides[id] = new
                }
            }
        )
    }
}

private struct StudioAgreementTermsClauseEditSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let clause: StudioAgreementTermsClause
    @Binding var overrideText: String

    @State private var draftText: String = ""

    var body: some View {
        NavigationStack {
            BuxThemedCardForm {
                BuxFormSection(title: clause.title) {
                    BuxCatalogDynamicText(key: "Edit for this agreement only. Leave blank to restore the template.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    TextField(BuxCatalogLabel.string("Clause text", locale: appSettingsManager.interfaceLocale), text: $draftText, axis: .vertical)
                        .lineLimit(6...20)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Button(BuxCatalogLabel.string("Restore template", locale: appSettingsManager.interfaceLocale)) {
                        draftText = ""
                        overrideText = ""
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                }
            }
            .buxCatalogNavigationTitle("Edit clause")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        overrideText = draftText
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
            .onAppear {
                draftText = overrideText.isEmpty ? clause.defaultBody : overrideText
            }
        }
        .buxStudioSheetContent()
    }
}

private struct StudioAgreementTermsPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let text: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(size: 13, weight: .regular))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BuxTokens.marginRegular)
            }
            .buxCatalogNavigationTitle("Terms preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .buxStudioSheetContent()
    }
}

/// Settings — default terms for new drafts.
struct StudioAgreementDefaultTermsSettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        StudioAgreementTermsEditorView(
            enabledClauseIds: $settings.agreementDefaultEnabledClauseIds,
            clauseOverrides: .constant([:]),
            customText: $settings.agreementDefaultCustomTerms,
            navigationTitle: "Default terms",
            showSaveAsDefaults: false
        )
        .environmentObject(themeManager)
    }
}
