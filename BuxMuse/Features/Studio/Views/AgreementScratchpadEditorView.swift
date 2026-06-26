//
//  AgreementScratchpadEditorView.swift
//  BuxMuse
//
//  Pro Studio — agreement drafts, signatures, PDF export.
//

import SwiftUI

struct AgreementScratchpadListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    @State private var showNewDraft = false
    @State private var showImportImporter = false
    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?
    @State private var importError: String?
    @State private var importedDraftSheet: AgreementDraft?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        StudioThemedListBackdrop {
            BuxThemedCardForm {
                StudioProToolScreenHeader(titleKey: "Agreements")
                    .studioProToolScrollPlacementEmbedded()

                BuxFormSection(title: "Import your agreement") {
                    Text(AgreementImportedDocumentLimits.limitsNotice(locale: locale))
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                        .buxFormFieldPadding()

                    if let importError {
                        BuxFormRowDivider()
                        Text(importError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .buxFormFieldPadding()
                    }

                    BuxFormRowDivider()
                    Button {
                        guard StudioFeatureGate.isPro else {
                            proUpsellFeature = .agreementScratchpad
                            return
                        }
                        importError = nil
                        showImportImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.arrow.up.fill")
                            BuxCatalogDynamicText(key: "Import PDF or photo")
                            if !StudioFeatureGate.isPro {
                                Spacer(minLength: 8)
                                ProFeatureBadge()
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .buxFormFieldPadding()
                }

                BuxFormSection(title: "Agreement drafts") {
                    if store.agreementDrafts.isEmpty {
                        BuxCatalogDynamicText(key: "No drafts yet. Create one for a client or project before work starts.")
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
                                    .environmentObject(appSettingsManager)
                                    .environmentObject(simpleStudioStore)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(draft.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                                        Spacer(minLength: 8)
                                        agreementStatusChip(draft)
                                    }
                                    Text(draftSubtitle(draft))
                                        .font(.system(size: 11, weight: .medium))
                                        .buxLabelSecondary()
                                        .lineLimit(1)
                                    if draft.hasImportedSource {
                                        BuxCatalogDynamicText(key: "Imported document")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                    }
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
                            BuxCatalogDynamicText(key: "New agreement draft")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .buxFormFieldPadding()
                }
            }
            .studioProToolScrollTopInset()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .sheet(isPresented: $showNewDraft) {
            NavigationStack {
                AgreementScratchpadEditorView(
                    draft: AgreementDraft(
                        title: BuxCatalogLabel.string(
                            "New agreement",
                            locale: BuxInterfaceLocale.currentInterfaceLocale
                        )
                    )
                )
                .environmentObject(store)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(simpleStudioStore)
            }
            .buxStudioSheetContent()
        }
        .sheet(item: $importedDraftSheet) { draft in
            NavigationStack {
                AgreementScratchpadEditorView(draft: draft)
                    .environmentObject(store)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(simpleStudioStore)
            }
            .buxStudioSheetContent()
        }
        .sheet(item: $proUpsellFeature) { feature in
            StudioProUpsellSheet(feature: feature)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
                .environmentObject(simpleStudioStore)
        }
        .fileImporter(
            isPresented: $showImportImporter,
            allowedContentTypes: AgreementDocumentStore.importContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleListImport(result)
        }
    }

    private func handleListImport(_ result: Result<[URL], Error>) {
        importError = nil
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let exceeded = AgreementDocumentStore.importedSourcePageCountExceeded(at: url) {
            importError = AgreementImportedDocumentLimits.pageCountExceededMessage(
                pageCount: exceeded,
                locale: locale
            )
            return
        }

        var draft = AgreementDraft(
            title: url.deletingPathExtension().lastPathComponent.isEmpty
                ? StudioAgreementL10n.line("Imported agreement", locale: locale)
                : url.deletingPathExtension().lastPathComponent
        )

        guard let saved = AgreementDocumentStore.saveImportedSource(at: url, agreementId: draft.id) else {
            importError = StudioAgreementL10n.line(
                "Could not import this file. Use a PDF or photo.",
                locale: locale
            )
            return
        }

        draft.importedSourcePath = saved.path
        draft.importedSourceKind = saved.kind.rawValue
        draft.importedSourceFilename = url.lastPathComponent
        draft.updatedAt = Date()
        store.upsertAgreementDraft(draft, simpleStore: simpleStudioStore)
        importedDraftSheet = draft
        BuxSaveFeedback.success()
    }

    @ViewBuilder
    private func agreementStatusChip(_ draft: AgreementDraft) -> some View {
        Text(
            StudioAgreementL10n.line(
                draft.hasApprovalProof
                    ? "OK"
                    : (draft.agreementSentAt != nil ? "Sent" : "Draft"),
                locale: locale
            )
        )
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background((draft.hasApprovalProof ? Color.green : Color.orange).opacity(0.15))
            .foregroundColor(draft.hasApprovalProof ? .green : .orange)
            .clipShape(Capsule())
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
        parts.append(BuxDisplayDate.monthDay(from: draft.updatedAt, locale: locale))
        return parts.joined(separator: " · ")
    }
}

struct AgreementScratchpadEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    @State private var draft: AgreementDraft
    @State private var didSave = false
    @State private var showGuidedBuilder = false
    @State private var showImportSheet = false
    @State private var showTermsEditor = false
    @State private var signatureRole: AgreementSignatureRole?
    @State private var pdfShareURL: URL?
    @State private var importedSignStudio: AgreementImportedSignStudioPresentation?

    private let linkedProject: StudioProject?
    private let linkedJob: SimpleStudioEntry?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    init(draft: AgreementDraft) {
        _draft = State(initialValue: draft)
        linkedProject = nil
        linkedJob = nil
    }

    init(project: StudioProject, existingDraft: AgreementDraft?) {
        linkedProject = project
        linkedJob = nil
        if let existingDraft {
            _draft = State(initialValue: existingDraft)
        } else {
            let locale = BuxInterfaceLocale.currentInterfaceLocale
            _draft = State(initialValue: AgreementDraft(
                title: StudioAgreementL10n.format("%@ agreement", locale: locale, project.name),
                clientId: project.clientId,
                projectId: project.id
            ))
        }
    }

    init(job: SimpleStudioEntry, existingDraft: AgreementDraft?) {
        linkedProject = nil
        linkedJob = job
        if let existingDraft {
            _draft = State(initialValue: existingDraft)
        } else {
            let locale = BuxInterfaceLocale.currentInterfaceLocale
            let titleBase = job.jobLabel ?? job.customerName
            _draft = State(initialValue: AgreementDraft(
                title: StudioAgreementL10n.format("%@ agreement", locale: locale, titleBase),
                linkedJobEntryId: job.id
            ))
        }
    }

    var body: some View {
        StudioThemedListBackdrop {
            BuxThemedCardForm {
                statusBanner

                if StudioFeatureGate.isPro {
                    AgreementImportedSourceSection(
                        draft: $draft,
                        onPersist: persistDraft,
                        onOpenSignStudio: { importedSignStudio = $0 }
                    )
                }

                BuxFormSection(title: "Basics") {
                TextField(BuxCatalogLabel.string("Title", locale: appSettingsManager.interfaceLocale), text: $draft.title)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                if linkedProject != nil || linkedJob != nil {
                    Button {
                        showImportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text(
                                BuxLocalizedString.string(
                                    String.LocalizationValue(
                                        stringLiteral: linkedJob != nil ? "Fill from job" : "Fill from project"
                                    ),
                                    locale: appSettingsManager.interfaceLocale
                                )
                            )
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .buxLabelSecondary()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                }
                Button {
                    showGuidedBuilder = true
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                        BuxCatalogDynamicText(key: "Guided setup")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker(loc("Client"), selection: clientBinding) {
                    BuxCatalogDynamicText(key: "None").tag(UUID?.none)
                    ForEach(store.clients) { client in
                        Text(client.name).tag(Optional(client.id))
                    }
                }
                .pickerStyle(.menu)
                .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker(loc("Project"), selection: projectBinding) {
                    BuxCatalogDynamicText(key: "None").tag(UUID?.none)
                    ForEach(store.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
                .pickerStyle(.menu)
                .buxFormFieldPadding()
                BuxFormRowDivider()
                Picker(loc("Linked invoice"), selection: invoiceBinding) {
                    BuxCatalogDynamicText(key: "None").tag(UUID?.none)
                    ForEach(linkedInvoiceCandidates) { invoice in
                        Text(invoicePickerLabel(invoice)).tag(Optional(invoice.id))
                    }
                }
                .pickerStyle(.menu)
                .buxFormFieldPadding()
                if !simpleStudioStore.entries.filter({ $0.kind == .job }).isEmpty {
                    BuxFormRowDivider()
                    Picker(loc("Linked job"), selection: jobBinding) {
                        BuxCatalogDynamicText(key: "None").tag(UUID?.none)
                        ForEach(simpleStudioStore.entries.filter { $0.kind == .job }) { job in
                            Text(job.jobLabel ?? job.customerName).tag(Optional(job.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .buxFormFieldPadding()
                }
            }

            StudioAgreementApprovalSection(
                draft: $draft,
                workAlreadyStarted: workAlreadyStarted,
                onExportAgreementPDF: draft.hasImportedSource ? nil : { exportPDF() }
            )

            if !draft.hasImportedSource {
            BuxFormSection(title: "Scope & deliverables") {
                scratchpadField("What's included (scope bullets)", text: $draft.scopeBullets)
                BuxFormRowDivider()
                scratchpadField("Deliverables", text: $draft.deliverables)
                BuxFormRowDivider()
                scratchpadField("Out of scope", text: $draft.outOfScope)
            }

            BuxFormSection(title: "Money & timing") {
                scratchpadField("Price or rate", text: $draft.paymentAmountNotes)
                BuxFormRowDivider()
                scratchpadField("Payment terms", text: $draft.paymentTerms)
                BuxFormRowDivider()
                scratchpadField("Timeline & milestones", text: $draft.timelineNotes)
            }

            BuxFormSection(title: "Terms & conditions") {
                Text(termsSummary)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Button { showTermsEditor = true } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        BuxCatalogDynamicText(key: "Edit terms & conditions")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Your signature (worker)") {
                BuxCatalogDynamicText(key: "Sign anytime — included when you export a PDF. Client approval uses the channel you chose above.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                signatureRow(
                    title: draft.providerSignatoryName.isEmpty ? loc("Your signature") : draft.providerSignatoryName,
                    hasSignature: draft.providerSignaturePNG != nil,
                    signedAt: draft.providerSignedAt,
                    action: { signatureRole = .provider }
                )
                BuxFormRowDivider()
                TextField(BuxCatalogLabel.string("Your name on agreement", locale: appSettingsManager.interfaceLocale), text: $draft.providerSignatoryName)
                    .buxFormFieldPadding()
                if draft.providerSignaturePNG != nil {
                    BuxFormRowDivider()
                    Button(role: .destructive) {
                        clearProviderSignature()
                    } label: {
                        BuxCatalogDynamicText(key: "Clear your signature")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buxFormFieldPadding()
                }
            }

            if showsClientInPersonSignature {
                BuxFormSection(title: "Client signature (in person only)") {
                    BuxCatalogDynamicText(key: "Only when the client is with you. For PDF, text, or print-back approval, use Client approval above — not this pad.")
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    signatureRow(
                        title: draft.signOffName.isEmpty ? loc("Client") : draft.signOffName,
                        hasSignature: draft.clientSignaturePNG != nil,
                        signedAt: draft.clientSignedAt,
                        action: { signatureRole = .client }
                    )
                    if draft.clientSignaturePNG != nil {
                        BuxFormRowDivider()
                        Button(role: .destructive) {
                            clearClientSignature()
                        } label: {
                            BuxCatalogDynamicText(key: "Clear client signature")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buxFormFieldPadding()
                    }
                }
            }

            BuxFormSection(title: "Sign-off note (optional)") {
                TextField(BuxCatalogLabel.string("Client name", locale: appSettingsManager.interfaceLocale), text: $draft.signOffName)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Toggle(isOn: signOffDateEnabled) {
                    BuxCatalogDynamicText(key: "Approval date recorded")
                        .font(.system(size: 15, weight: .semibold))
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()
                if draft.signOffDate != nil {
                    BuxFormRowDivider()
                    DatePicker(loc("Date"), selection: signOffDateBinding, displayedComponents: .date)
                        .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Export & share") {
                if let pdfShareURL {
                    ShareLink(item: pdfShareURL) {
                        exportRowLabel("Share agreement PDF", systemImage: "doc.richtext.fill")
                    }
                    .buxFormFieldPadding()
                    BuxFormRowDivider()
                }
                Button {
                    exportPDF()
                } label: {
                    exportRowLabel("Generate PDF", systemImage: "doc.fill")
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
                ShareLink(item: shareText) {
                    exportRowLabel("Share agreement text", systemImage: "square.and.arrow.up")
                }
                .buxFormFieldPadding()
            }
            }
            }
        }
        .buxCatalogNavigationTitle("Agreement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BuxToolbarCancelButton { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                BuxToolbarSaveButton(isDirty: true) {
                    persistDraft()
                    didSave = true
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showGuidedBuilder) {
            StudioAgreementBuilderView(draft: $draft)
                .environmentObject(store)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showImportSheet) {
            StudioAgreementImportSheet(
                draft: $draft,
                simpleStore: simpleStudioStore,
                project: linkedProject,
                job: linkedJob ?? linkedJobFromPicker
            )
            .environmentObject(store)
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showTermsEditor) {
            StudioAgreementTermsEditorView(
                enabledClauseIds: $draft.enabledTermsClauseIds,
                clauseOverrides: $draft.termsClauseOverrides,
                customText: $draft.termsCustomText,
                showSaveAsDefaults: true
            )
            .environmentObject(themeManager)
        }
        .onAppear {
            draft.applyDefaultTermsFromSettings()
        }
        .fullScreenCover(item: $importedSignStudio) { presentation in
            if let path = draft.importedSourcePath,
               let kind = draft.importedSourceKindValue {
                let count = AgreementDocumentStore.pageCount(path: path)
                if count > 0 {
                    AgreementImportedDocumentSignSheet(
                        draft: $draft,
                        sourcePath: path,
                        sourceKind: kind,
                        pageCount: count,
                        initialRole: presentation.initialRole,
                        onPersist: persistDraft
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxInterfaceLocale()
                }
            }
        }
        .sheet(item: $signatureRole) { role in
            Group {
                if BuxPadIdiom.isPad {
                    BuxPadAgreementSignatureCaptureSheet(role: role) { png in
                        applySignature(png, role: role)
                    }
                } else {
                    AgreementSignatureCaptureSheet(role: role) { png in
                        applySignature(png, role: role)
                    }
                }
            }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
        }
        .onDisappear {
            if !didSave, hasMeaningfulContent {
                persistDraft()
            }
        }
    }

    private var statusBanner: some View {
        BuxFormSection(title: "Status") {
            HStack {
                Text(loc(draft.statusDisplayLabel))
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                if draft.hasClientApprovalProof {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                } else if draft.hasProviderSignature {
                    Image(systemName: "signature")
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
            }
            .buxFormFieldPadding()
        }
    }

    private var linkedInvoiceCandidates: [StudioInvoice] {
        store.invoices
            .filter { invoice in
                guard let clientId = draft.clientId else { return true }
                return invoice.clientId == clientId
            }
            .sorted { $0.issueDate > $1.issueDate }
    }

    private func invoicePickerLabel(_ invoice: StudioInvoice) -> String {
        let number = invoice.invoiceNumber.isEmpty ? "Draft" : invoice.invoiceNumber
        return "\(number) · \(BuxDisplayDate.monthDay(from: invoice.issueDate, locale: appSettingsManager.interfaceLocale))"
    }

    private var workAlreadyStarted: Bool {
        if let job = linkedJob ?? linkedJobFromPicker { return job.hasWorkStarted }
        if let projectId = draft.projectId,
           let project = store.projects.first(where: { $0.id == projectId }) {
            return !project.timeEntries.isEmpty
        }
        return false
    }

    private var linkedJobFromPicker: SimpleStudioEntry? {
        guard let id = draft.linkedJobEntryId else { return nil }
        return simpleStudioStore.entry(id: id)
    }

    private var showsClientInPersonSignature: Bool {
        draft.approvalChannel == .inPerson
    }

    private var hasMeaningfulContent: Bool {
        draft.hasImportedSource
            || !draft.scopeBullets.isEmpty
            || !draft.deliverables.isEmpty
            || !draft.outOfScope.isEmpty
            || !draft.signOffName.isEmpty
            || !draft.paymentTerms.isEmpty
            || !draft.paymentAmountNotes.isEmpty
            || draft.clientSignaturePNG != nil
            || draft.providerSignaturePNG != nil
            || draft.hasApprovalProof
            || draft.approvalChannel != nil
            || draft.hasTermsContent
    }

    private var termsSummary: String {
        if !draft.hasTermsContent {
            return loc("No terms yet. Add deposits, cancellations, liability, and your own policies.")
        }
        let count = draft.enabledTermsClauseIds.count
        let custom = !draft.termsCustomText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if count == 0, custom { return loc("Custom terms only") }
        if custom {
            return StudioAgreementL10n.format(
                "%d clauses + your custom terms",
                locale: locale,
                count
            )
        }
        if count == 1 {
            return loc("1 clause included in PDF & share")
        }
        return StudioAgreementL10n.format(
            "%d clauses included in PDF & share",
            locale: locale,
            count
        )
    }

    private var shareText: String {
        draft.formattedShareText(
            clientName: draft.clientId.flatMap { id in store.clients.first(where: { $0.id == id })?.name },
            projectName: draft.projectId.flatMap { id in store.projects.first(where: { $0.id == id })?.name },
            providerName: resolvedProviderName,
            locale: locale
        )
    }

    private var resolvedProviderName: String? {
        let custom = draft.providerSignatoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        let business = store.profile.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !business.isEmpty { return business }
        let display = store.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return display.isEmpty ? nil : display
    }

    private func persistDraft() {
        draft.refreshAgreementStatus()
        store.upsertAgreementDraft(draft, simpleStore: simpleStudioStore)
        BuxSaveFeedback.success()
    }

    private var jobBinding: Binding<UUID?> {
        Binding(
            get: { draft.linkedJobEntryId },
            set: { newId in
                draft.linkedJobEntryId = newId
                if let newId, let job = simpleStudioStore.entry(id: newId) {
                    if draft.signOffName.isEmpty { draft.signOffName = job.customerName }
                }
            }
        )
    }

    private func exportPDF() {
        guard let data = StudioAgreementPDFRenderer.generatePDF(
            draft: draft,
            clientName: draft.clientId.flatMap { id in store.clients.first(where: { $0.id == id })?.name },
            projectName: draft.projectId.flatMap { id in store.projects.first(where: { $0.id == id })?.name },
            providerName: resolvedProviderName,
            locale: appSettingsManager.interfaceLocale
        ) else { return }
        let slug = draft.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let name = (slug.isEmpty ? "agreement" : slug) + ".pdf"
        pdfShareURL = StudioAgreementPDFRenderer.temporaryFileURL(data: data, filename: name)
    }

    private func applySignature(_ png: Data, role: AgreementSignatureRole) {
        switch role {
        case .client:
            draft.clientSignaturePNG = png
            draft.clientSignedAt = Date()
        case .provider:
            draft.providerSignaturePNG = png
            draft.providerSignedAt = Date()
        }
        if role == .client, draft.approvalChannel != .inPerson {
            draft.approvalChannel = .inPerson
        }
        draft.refreshAgreementStatus()
    }

    private func clearProviderSignature() {
        draft.providerSignaturePNG = nil
        draft.providerSignedAt = nil
        draft.refreshAgreementStatus()
    }

    private func clearClientSignature() {
        draft.clientSignaturePNG = nil
        draft.clientSignedAt = nil
        draft.refreshAgreementStatus()
    }

    private var clientBinding: Binding<UUID?> {
        Binding(get: { draft.clientId }, set: { draft.clientId = $0 })
    }

    private var projectBinding: Binding<UUID?> {
        Binding(
            get: { draft.projectId },
            set: { newId in
                draft.projectId = newId
                if let newId,
                   let project = store.projects.first(where: { $0.id == newId }),
                   draft.clientId == nil {
                    draft.clientId = project.clientId
                }
            }
        )
    }

    private var invoiceBinding: Binding<UUID?> {
        Binding(get: { draft.linkedInvoiceId }, set: { draft.linkedInvoiceId = $0 })
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
        TextField(BuxCatalogLabel.string(placeholder, locale: appSettingsManager.interfaceLocale), text: text, axis: .vertical)
            .lineLimit(4...12)
            .buxFormFieldPadding()
    }

    private func signatureRow(
        title: String,
        hasSignature: Bool,
        signedAt: Date?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    if hasSignature, let signedAt {
                        Text(
                            BuxLocalizedString.format(
                                "Signed · %@",
                                locale: appSettingsManager.interfaceLocale,
                                BuxDisplayDate.monthDay(from: signedAt, locale: appSettingsManager.interfaceLocale)
                            )
                        )
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    } else {
                        BuxCatalogDynamicText(key: "Tap to capture signature")
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    }
                }
                Spacer()
                Image(systemName: hasSignature ? "signature" : "pencil.and.scribble")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .buxFormFieldPadding()
        }
        .buttonStyle(.plain)
    }

    private func exportRowLabel(_ titleKey: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
            BuxCatalogDynamicText(key: titleKey)
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
    }
}

extension AgreementSignatureRole: Identifiable {
    var id: String {
        switch self {
        case .client: "client"
        case .provider: "provider"
        }
    }
}
