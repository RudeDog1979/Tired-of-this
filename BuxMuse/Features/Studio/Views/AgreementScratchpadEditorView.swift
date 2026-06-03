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
                                HStack {
                                    Text(draft.title)
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer(minLength: 8)
                                    agreementStatusChip(draft.agreementStatus)
                                }
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
        .navigationTitle("Agreements")
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

    @ViewBuilder
    private func agreementStatusChip(_ status: StudioAgreementStatus) -> some View {
        Text(status == .signed ? "Signed" : (status == .awaitingSignatures ? "Signing" : "Draft"))
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(chipColor(status).opacity(0.15))
            .foregroundColor(chipColor(status))
            .clipShape(Capsule())
    }

    private func chipColor(_ status: StudioAgreementStatus) -> Color {
        switch status {
        case .draft: .secondary
        case .awaitingSignatures: .orange
        case .signed: .green
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
    @State private var showGuidedBuilder = false
    @State private var signatureRole: AgreementSignatureRole?
    @State private var pdfShareURL: URL?

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
            statusBanner

            BuxFormSection(title: "Basics") {
                TextField("Title", text: $draft.title)
                    .buxFormFieldPadding()
                BuxFormRowDivider()
                Button {
                    showGuidedBuilder = true
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                        Text("Guided setup")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.current.accentColor)
                }
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
                BuxFormRowDivider()
                Picker("Linked invoice", selection: invoiceBinding) {
                    Text("None").tag(UUID?.none)
                    ForEach(linkedInvoiceCandidates) { invoice in
                        Text(invoicePickerLabel(invoice)).tag(Optional(invoice.id))
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

            BuxFormSection(title: "Money & timing") {
                scratchpadField("Price or rate", text: $draft.paymentAmountNotes)
                BuxFormRowDivider()
                scratchpadField("Payment terms", text: $draft.paymentTerms)
                BuxFormRowDivider()
                scratchpadField("Timeline & milestones", text: $draft.timelineNotes)
            }

            BuxFormSection(title: "Signatures") {
                signatureRow(
                    title: "Client",
                    hasSignature: draft.clientSignaturePNG != nil,
                    signedAt: draft.clientSignedAt,
                    action: { signatureRole = .client }
                )
                BuxFormRowDivider()
                signatureRow(
                    title: draft.providerSignatoryName.isEmpty ? "Your signature" : draft.providerSignatoryName,
                    hasSignature: draft.providerSignaturePNG != nil,
                    signedAt: draft.providerSignedAt,
                    action: { signatureRole = .provider }
                )
                BuxFormRowDivider()
                TextField("Your name on agreement", text: $draft.providerSignatoryName)
                    .buxFormFieldPadding()
                if draft.clientSignaturePNG != nil || draft.providerSignaturePNG != nil {
                    BuxFormRowDivider()
                    Button(role: .destructive) {
                        clearAllSignatures()
                    } label: {
                        Text("Clear all signatures")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Sign-off note (optional)") {
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
        .navigationTitle("Agreement")
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
        .sheet(item: $signatureRole) { role in
            AgreementSignatureCaptureSheet(role: role) { png in
                applySignature(png, role: role)
            }
            .environmentObject(themeManager)
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
                Text(draft.statusDisplayLabel)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                if draft.isFullySigned {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
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
        return "\(number) · \(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var hasMeaningfulContent: Bool {
        !draft.scopeBullets.isEmpty
            || !draft.deliverables.isEmpty
            || !draft.outOfScope.isEmpty
            || !draft.signOffName.isEmpty
            || !draft.paymentTerms.isEmpty
            || !draft.paymentAmountNotes.isEmpty
            || draft.clientSignaturePNG != nil
            || draft.providerSignaturePNG != nil
    }

    private var shareText: String {
        draft.formattedShareText(
            clientName: draft.clientId.flatMap { id in store.clients.first(where: { $0.id == id })?.name },
            projectName: draft.projectId.flatMap { id in store.projects.first(where: { $0.id == id })?.name },
            providerName: resolvedProviderName
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
        store.upsertAgreementDraft(draft)
        BuxSaveFeedback.success()
    }

    private func exportPDF() {
        guard let data = StudioAgreementPDFRenderer.generatePDF(
            draft: draft,
            clientName: draft.clientId.flatMap { id in store.clients.first(where: { $0.id == id })?.name },
            projectName: draft.projectId.flatMap { id in store.projects.first(where: { $0.id == id })?.name },
            providerName: resolvedProviderName
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
        draft.refreshAgreementStatus()
    }

    private func clearAllSignatures() {
        draft.clientSignaturePNG = nil
        draft.providerSignaturePNG = nil
        draft.clientSignedAt = nil
        draft.providerSignedAt = nil
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
        TextField(placeholder, text: text, axis: .vertical)
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
                        Text("Signed · \(signedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    } else {
                        Text("Tap to capture signature")
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    }
                }
                Spacer()
                Image(systemName: hasSignature ? "signature" : "pencil.and.scribble")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.current.accentColor)
            }
            .buxFormFieldPadding()
        }
        .buttonStyle(.plain)
    }

    private func exportRowLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(themeManager.current.accentColor)
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
