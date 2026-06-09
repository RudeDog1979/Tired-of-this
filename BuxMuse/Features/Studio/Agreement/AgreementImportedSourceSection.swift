//
//  AgreementImportedSourceSection.swift
//  BuxMuse — Pro Studio imported agreement source (PDF / image).
//

import SwiftUI
import UniformTypeIdentifiers

struct AgreementImportedSourceSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var draft: AgreementDraft
    var onPersist: () -> Void
    var onOpenSignStudio: (AgreementImportedSignStudioPresentation) -> Void

    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var signedExportShareURL: URL?

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var pageCount: Int {
        AgreementDocumentStore.pageCount(path: draft.importedSourcePath)
    }

    var body: some View {
        BuxFormSection(title: "Your agreement document") {
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

            if draft.hasImportedSource {
                importedDocumentSummary
            } else {
                BuxFormRowDivider()
                Button {
                    showFileImporter = true
                } label: {
                    Label(
                        StudioAgreementL10n.line("Import PDF or photo", locale: locale),
                        systemImage: "doc.badge.plus"
                    )
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buxFormFieldPadding()
            }
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
    private var importedDocumentSummary: some View {
        BuxFormRowDivider()

        if let preview = firstPagePreview {
            Image(uiImage: preview)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .buxFormFieldPadding()
            BuxFormRowDivider()
        }

        VStack(alignment: .leading, spacing: 4) {
            Text(draft.importedSourceFilename ?? "Imported document")
                .font(.system(size: 15, weight: .semibold))
            Text(documentSubtitle)
                .font(.system(size: 11, weight: .medium))
                .buxLabelSecondary()
        }
        .buxFormFieldPadding()

        BuxFormRowDivider()
        Button {
            onOpenSignStudio(.openDocument())
        } label: {
            Label(
                StudioAgreementL10n.line("Sign & mark up document", locale: locale),
                systemImage: "pencil.and.scribble"
            )
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
        }
        .buxFormFieldPadding()

        BuxFormRowDivider()
        signatureActionRow(
            title: draft.providerSignatoryName.isEmpty
                ? StudioAgreementL10n.line("Your signature", locale: locale)
                : draft.providerSignatoryName,
            hasSignature: draft.providerSignaturePNG != nil,
            role: .provider
        )

        BuxFormRowDivider()
        signatureActionRow(
            title: draft.signOffName.isEmpty
                ? StudioAgreementL10n.line("Client signature", locale: locale)
                : draft.signOffName,
            hasSignature: draft.clientSignaturePNG != nil,
            role: .client
        )

        BuxFormRowDivider()
        Button {
            exportSignedPDF()
        } label: {
            Label(
                StudioAgreementL10n.line("Generate signed PDF", locale: locale),
                systemImage: "doc.richtext.fill"
            )
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
        }
        .buxFormFieldPadding()

        if let signedExportShareURL {
            BuxFormRowDivider()
            ShareLink(item: signedExportShareURL) {
                Label(
                    StudioAgreementL10n.line("Share signed PDF", locale: locale),
                    systemImage: "square.and.arrow.up"
                )
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .buxFormFieldPadding()
        }

        BuxFormRowDivider()
        Button {
            showFileImporter = true
        } label: {
            Label(
                StudioAgreementL10n.line("Replace document", locale: locale),
                systemImage: "arrow.triangle.2.circlepath"
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
        }
        .buxFormFieldPadding()

        BuxFormRowDivider()
        Button(role: .destructive) {
            removeImportedSource()
        } label: {
            BuxCatalogDynamicText(key: "Remove imported document")
                .font(.system(size: 14, weight: .semibold))
        }
        .buxFormFieldPadding()
    }

    private var documentSubtitle: String {
        let kindLabel = draft.importedSourceKindValue == .pdf ? "PDF" : "Photo"
        if pageCount <= 1 {
            return kindLabel
        }
        return "\(kindLabel) · \(pageCount) pages"
    }

    private var firstPagePreview: UIImage? {
        guard draft.hasImportedSource else { return nil }
        if AgreementImportedMarkupStore.hasAnyMarkup(for: draft.id, pageCount: pageCount)
            || hasAnyPlacements
            || draft.providerSignaturePNG != nil
            || draft.clientSignaturePNG != nil {
            return AgreementImportedPDFExporter.previewPageImage(draft: draft, pageIndex: 0, scale: 1.2)
        }
        guard let path = draft.importedSourcePath else { return nil }
        if draft.importedSourceKindValue == .pdf {
            return AgreementDocumentStore.renderPageImage(path: path, pageIndex: 0, scale: 1.5)
        }
        return AgreementDocumentStore.loadPreviewImage(path: path)
    }

    private var hasAnyPlacements: Bool {
        let limit = min(pageCount, AgreementImportedDocumentLimits.maxSignablePages)
        guard limit > 0 else { return false }
        for index in 0..<limit where AgreementImportedPageAnnotationStore.hasPlacements(for: draft.id, pageIndex: index) {
            return true
        }
        return false
    }

    private func signatureActionRow(
        title: String,
        hasSignature: Bool,
        role: AgreementSignatureRole
    ) -> some View {
        Button {
            onOpenSignStudio(.signAs(role))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(
                        hasSignature
                            ? StudioAgreementL10n.line("Captured — open Sign & mark up and tap where to place it", locale: locale)
                            : StudioAgreementL10n.line("Opens full-screen signing", locale: locale)
                    )
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
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

    private func handleImport(_ result: Result<[URL], Error>) {
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

        guard let saved = AgreementDocumentStore.saveImportedSource(at: url, agreementId: draft.id) else {
            importError = StudioAgreementL10n.line(
                "Could not import this file. Use a PDF or photo.",
                locale: locale
            )
            return
        }

        if let oldPath = draft.importedSourcePath {
            AgreementDocumentStore.delete(path: oldPath)
            AgreementImportedMarkupStore.deleteAllMarkups(
                for: draft.id,
                pageCount: AgreementDocumentStore.pageCount(path: oldPath)
            )
        }
        if let oldExport = draft.importedSignedExportPath {
            AgreementDocumentStore.delete(path: oldExport)
        }

        draft.importedSourcePath = saved.path
        draft.importedSourceKind = saved.kind.rawValue
        draft.importedSourceFilename = url.lastPathComponent
        draft.importedSignedExportPath = nil
        signedExportShareURL = nil
        draft.updatedAt = Date()
        onPersist()
    }

    private func exportSignedPDF() {
        guard let data = AgreementImportedPDFExporter.exportSignedPDF(draft: draft) else { return }
        if let old = draft.importedSignedExportPath {
            AgreementDocumentStore.delete(path: old)
        }
        draft.importedSignedExportPath = AgreementDocumentStore.saveSignedExport(data: data, agreementId: draft.id)
        draft.updatedAt = Date()
        onPersist()

        let slug = (draft.importedSourceFilename ?? draft.title)
            .replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let name = (slug.isEmpty ? "signed-agreement" : slug) + "-signed.pdf"
        signedExportShareURL = StudioAgreementPDFRenderer.temporaryFileURL(data: data, filename: name)
    }

    private func removeImportedSource() {
        if let path = draft.importedSourcePath {
            AgreementImportedMarkupStore.deleteAllMarkups(
                for: draft.id,
                pageCount: AgreementDocumentStore.pageCount(path: path)
            )
            AgreementDocumentStore.delete(path: path)
        }
        if let exportPath = draft.importedSignedExportPath {
            AgreementDocumentStore.delete(path: exportPath)
        }
        draft.importedSourcePath = nil
        draft.importedSourceKind = nil
        draft.importedSourceFilename = nil
        draft.importedSignedExportPath = nil
        signedExportShareURL = nil
        draft.updatedAt = Date()
        onPersist()
    }
}
