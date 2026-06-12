//
//  StudioAgreementDealViews.swift
//  BuxMuse
//
//  Approval channels, import prefill, privacy notice, proof attachments.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - External signing privacy

struct StudioAgreementExternalPrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BuxTokens.section) {
                    BuxCatalogDynamicText(key: "Signing outside BuxMuse")
                        .font(.system(size: 20, weight: .bold))
                    BuxCatalogDynamicText(key: "DocuSign, email, WhatsApp, and similar services may process your client's name, contact details, and document on their servers—not only on your device.")
                    .font(.system(size: 14, weight: .medium))
                    .buxLabelSecondary()
                    BuxCatalogDynamicText(key: "BuxMuse stores what you bring back (for example a signed PDF you upload). For maximum privacy, use in-app signing or attach a file you already received.")
                    .font(.system(size: 14, weight: .medium))
                    .buxLabelSecondary()
                }
                .padding(BuxTokens.marginRegular)
            }
            .buxCatalogNavigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        StudioAgreementApprovalSection.markPrivacySeen()
                        dismiss()
                    } label: {
                        BuxCatalogDynamicText(key: "Done")
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .buxStudioSheetContent()
    }
}

// MARK: - Import prefill

struct StudioAgreementImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var draft: AgreementDraft
    var simpleStore: SimpleStudioStore?

    let project: StudioProject?
    let job: SimpleStudioEntry?

    @State private var options: StudioAgreementPrefillOptions = .all

    var body: some View {
        NavigationStack {
            BuxThemedCardForm {
                BuxFormSection(title: "Import into agreement") {
                    Text(importSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    toggleRow("Scope & notes", option: .scope)
                    BuxFormRowDivider()
                    toggleRow("Deliverables", option: .deliverables)
                    BuxFormRowDivider()
                    toggleRow("Money", option: .money)
                    BuxFormRowDivider()
                    toggleRow("Timeline", option: .timeline)
                    BuxFormRowDivider()
                    toggleRow("Link client / job / project", option: .links)
                }
            }
            .buxCatalogNavigationTitle("Fill from…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(StudioAgreementL10n.line("Apply", locale: appSettingsManager.interfaceLocale)) {
                        applyImport()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .buxStudioSheetContent()
    }

    private var importSubtitle: String {
        let locale = appSettingsManager.interfaceLocale
        if let project {
            return StudioAgreementL10n.format("Pull fields from project “%@”.", locale: locale, project.name)
        }
        if let job {
            let label = job.jobLabel ?? job.customerName
            return StudioAgreementL10n.format("Pull fields from job “%@”.", locale: locale, label)
        }
        return StudioAgreementL10n.line("Choose sections to copy.", locale: locale)
    }

    private func toggleRow(_ title: String, option: StudioAgreementPrefillOptions) -> some View {
        Toggle(isOn: binding(for: option)) {
            Text(StudioAgreementL10n.line(title, locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 15, weight: .semibold))
        }
        .tint(themeManager.contrastAccentColor(for: colorScheme))
        .buxFormFieldPadding()
    }

    private func binding(for option: StudioAgreementPrefillOptions) -> Binding<Bool> {
        Binding(
            get: { options.contains(option) },
            set: { on in
                if on { options.insert(option) } else { options.remove(option) }
            }
        )
    }

    private func applyImport() {
        guard !options.isEmpty else { return }
        if let project {
            StudioAgreementPrefillEngine.applyProject(project, options: options, to: &draft, store: store)
        }
        if let job, let simpleStore {
            StudioAgreementPrefillEngine.applyJob(
                job,
                options: options,
                to: &draft,
                studioStore: store,
                simpleStore: simpleStore
            )
        }
        draft.refreshAgreementStatus()
    }
}

// MARK: - Approval channel + proof

struct StudioAgreementApprovalSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var draft: AgreementDraft
    var workAlreadyStarted: Bool
    var onMarkSent: (() -> Void)?
    var onExportAgreementPDF: (() -> Void)?

    @State private var showPrivacy = false
    @State private var showFileImporter = false
    @State private var attachedShareURL: URL?

    var body: some View {
        BuxFormSection(title: "Client approval") {
            if workAlreadyStarted {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    BuxCatalogDynamicText(key: "Work may have already started. Capture client approval now and attach their signed copy if you have it.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
            }

            Picker(StudioAgreementL10n.line("How did the client approve?", locale: appSettingsManager.interfaceLocale), selection: channelBinding) {
                BuxCatalogDynamicText(key: "Choose…").tag(StudioAgreementApprovalChannel?.none)
                ForEach(StudioAgreementApprovalChannel.allCases) { channel in
                    Text(channel.shortTitle).tag(Optional(channel))
                }
            }
            .pickerStyle(.menu)
            .buxFormFieldPadding()
            .onChange(of: draft.approvalChannel) { _, new in
                if new?.needsExternalPrivacyNotice == true,
                   !UserDefaults.standard.bool(forKey: Self.privacyDismissedKey) {
                    showPrivacy = true
                }
            }

            if draft.agreementSentAt == nil {
                BuxFormRowDivider()
                Button {
                    draft.agreementSentAt = Date()
                    onMarkSent?()
                } label: {
                    Label(
                        StudioAgreementL10n.line("Mark terms sent to client", locale: appSettingsManager.interfaceLocale),
                        systemImage: "paperplane"
                    )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buxFormFieldPadding()
            } else {
                BuxFormRowDivider()
                HStack {
                    BuxCatalogDynamicText(key: "Sent")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                    Spacer()
                    Text(draft.agreementSentAt!.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13, weight: .semibold))
                }
                .buxFormFieldPadding()
            }

            channelSpecificContent
        }
        .sheet(isPresented: $showPrivacy) {
            StudioAgreementExternalPrivacySheet()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: AgreementDocumentStore.importContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }

    @ViewBuilder
    private var channelSpecificContent: some View {
        switch draft.approvalChannel {
        case .clearToProceed:
            BuxFormRowDivider()
            Toggle(isOn: $draft.clientClearToProceed) {
                BuxCatalogDynamicText(key: "Client clear to go ahead")
                    .font(.system(size: 15, weight: .semibold))
            }
            .tint(themeManager.contrastAccentColor(for: colorScheme))
            .buxFormFieldPadding()
            .onChange(of: draft.clientClearToProceed) { _, on in
                if on, draft.clientClearAt == nil { draft.clientClearAt = Date() }
                draft.refreshAgreementStatus()
            }
            BuxFormRowDivider()
            TextField(StudioAgreementL10n.line("How they approved (text, call, etc.)", locale: appSettingsManager.interfaceLocale), text: $draft.clientClearNote, axis: .vertical)
                .lineLimit(2...4)
                .buxFormFieldPadding()
        case .returnedPDF, .printedScanned, .externalService:
            if draft.approvalChannel == .externalService {
                BuxFormRowDivider()
                TextField(StudioAgreementL10n.line("Service name (DocuSign, email…)", locale: appSettingsManager.interfaceLocale), text: $draft.externalServiceName)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Button {
                    showPrivacy = true
                } label: {
                    BuxCatalogDynamicText(key: "Privacy notice")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buxFormFieldPadding()
                if let onExportAgreementPDF {
                    BuxFormRowDivider()
                    Button(action: onExportAgreementPDF) {
                        Label(
                            StudioAgreementL10n.line("Export PDF for external signing", locale: appSettingsManager.interfaceLocale),
                            systemImage: "square.and.arrow.up"
                        )
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .buxFormFieldPadding()
                }
            }
            BuxFormRowDivider()
            uploadProofBlock
        case .inPerson:
            BuxFormRowDivider()
            BuxCatalogDynamicText(key: "Scroll to Client signature (in person only) below to capture the client's finger signature on this device.")
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
                .buxFormFieldPadding()
        case nil:
            EmptyView()
        }
    }

    private var uploadProofBlock: some View {
        Group {
            if draft.hasUploadedSignedDocument {
                if let image = AgreementDocumentStore.loadPreviewImage(path: draft.signedDocumentPath),
                   !AgreementDocumentStore.isPDF(path: draft.signedDocumentPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .buxFormFieldPadding()
                } else {
                    Label(
                        StudioAgreementL10n.line("Signed document attached", locale: appSettingsManager.interfaceLocale),
                        systemImage: "doc.fill"
                    )
                        .font(.system(size: 14, weight: .semibold))
                        .buxFormFieldPadding()
                }
                if let url = attachedShareURL ?? shareURLForAttachment() {
                    BuxFormRowDivider()
                    ShareLink(item: url) {
                        Label(
                            StudioAgreementL10n.line("Share attached file", locale: appSettingsManager.interfaceLocale),
                            systemImage: "square.and.arrow.up"
                        )
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .buxFormFieldPadding()
                }
                BuxFormRowDivider()
                Button(role: .destructive) {
                    removeAttachment()
                } label: {
                    BuxCatalogDynamicText(key: "Remove attachment")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buxFormFieldPadding()
            }
            Button {
                showFileImporter = true
            } label: {
                Label(
                    draft.hasUploadedSignedDocument ? "Replace signed file" : "Attach signed PDF or photo",
                    systemImage: "doc.badge.plus"
                )
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .buxFormFieldPadding()
        }
    }

    private var channelBinding: Binding<StudioAgreementApprovalChannel?> {
        Binding(
            get: { draft.approvalChannel },
            set: { new in
                draft.approvalChannel = new
                if new == .inPerson {
                    draft.clientClearToProceed = false
                } else if new != nil {
                    draft.clientSignaturePNG = nil
                    draft.clientSignedAt = nil
                }
                if new == .clearToProceed {
                    draft.signedDocumentPath = nil
                }
                draft.refreshAgreementStatus()
            }
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let path = AgreementDocumentStore.saveImportedFile(at: url, agreementId: draft.id) {
            if let old = draft.signedDocumentPath { AgreementDocumentStore.delete(path: old) }
            draft.signedDocumentPath = path
            draft.proofRecordedAt = Date()
            draft.refreshAgreementStatus()
            attachedShareURL = AgreementDocumentStore.resolveURL(for: path)
            BuxSaveFeedback.success()
        }
    }

    private func removeAttachment() {
        AgreementDocumentStore.delete(path: draft.signedDocumentPath)
        draft.signedDocumentPath = nil
        attachedShareURL = nil
        draft.refreshAgreementStatus()
    }

    private func shareURLForAttachment() -> URL? {
        AgreementDocumentStore.resolveURL(for: draft.signedDocumentPath)
    }

    private static let privacyDismissedKey = "studio.agreement.externalPrivacySeen"

    static func markPrivacySeen() {
        UserDefaults.standard.set(true, forKey: privacyDismissedKey)
    }
}

// MARK: - Job detail summary

struct StudioJobAgreementSummarySection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    let job: SimpleStudioEntry

    private var locale: Locale { appSettingsManager.interfaceLocale }

    @State private var showAgreementEditor = false

    private var draft: AgreementDraft? {
        if let id = job.linkedAgreementId {
            return studioStore.agreementDraft(id: id)
        }
        return studioStore.agreementDraft(forJobEntryId: job.id)
    }

    var body: some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    BuxCatalogDynamicText(key: "AGREEMENT")
                        .font(.system(size: 11, weight: .bold))
                        .buxLabelSecondary()
                    Spacer()
                    if let draft {
                        Text(StudioAgreementL10n.line(draft.statusDisplayLabel, locale: locale))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((draft.hasApprovalProof ? Color.green : Color.orange).opacity(0.15))
                            .foregroundColor(draft.hasApprovalProof ? .green : .orange)
                            .clipShape(Capsule())
                    }
                }

                if let draft {
                    Text(draft.title)
                        .font(.system(size: 14, weight: .semibold))
                    if job.hasWorkStarted, !draft.hasApprovalProof {
                        BuxCatalogDynamicText(key: "Time is on this job — get client approval when you can.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                } else {
                    BuxCatalogDynamicText(key: "Link terms and client approval to this job.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }

                Button {
                    showAgreementEditor = true
                } label: {
                    Label(
                        draft == nil ? "Set up agreement" : "Edit agreement",
                        systemImage: "signature"
                    )
                    .font(.system(size: 12, weight: .bold))
                }
            }
        }
        .sheet(isPresented: $showAgreementEditor) {
            NavigationStack {
                AgreementScratchpadEditorView(
                    job: job,
                    existingDraft: draft
                )
                .environmentObject(studioStore)
                .environmentObject(themeManager)
                .environmentObject(simpleStudioStore)
            }
            .buxStudioSheetContent()
        }
    }
}
