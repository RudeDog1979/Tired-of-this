//
//  PersonalAgreementMediaSync.swift
//  BuxMuse
//
//  Sync agreement PDFs, scans, markup, and annotation sidecars via CloudKit assets.
//

import Foundation

enum PersonalAgreementMediaSync {
    enum FileRole: String, Codable {
        case signedDocument
        case importedSource
        case signedExport
        case markup
        case annotation
    }

    struct FileMetadata: Codable, Equatable {
        var agreementId: UUID
        var role: FileRole
        var relativePath: String?
        var pageIndex: Int?
    }

    static func exportFileRecords(
        for draft: AgreementDraft,
        revision: Date,
        deviceId: String
    ) -> [PersonalSyncEntityRecord] {
        var records: [PersonalSyncEntityRecord] = []

        if let path = draft.signedDocumentPath,
           let record = makeFileRecord(
               agreementId: draft.id,
               role: .signedDocument,
               storedPath: path,
               pageIndex: nil,
               revision: max(revision, draft.updatedAt),
               deviceId: deviceId
           ) {
            records.append(record)
        }

        if let path = draft.importedSourcePath,
           let record = makeFileRecord(
               agreementId: draft.id,
               role: .importedSource,
               storedPath: path,
               pageIndex: nil,
               revision: max(revision, draft.updatedAt),
               deviceId: deviceId
           ) {
            records.append(record)
        }

        if let path = draft.importedSignedExportPath,
           let record = makeFileRecord(
               agreementId: draft.id,
               role: .signedExport,
               storedPath: path,
               pageIndex: nil,
               revision: max(revision, draft.updatedAt),
               deviceId: deviceId
           ) {
            records.append(record)
        }

        let pageCount = AgreementDocumentStore.pageCount(path: draft.importedSourcePath)
        if pageCount > 0 {
            let limit = min(pageCount, AgreementImportedDocumentLimits.maxSignablePages)
            for pageIndex in 0..<limit {
                let markupURL = AgreementImportedMarkupStore.drawingURL(agreementId: draft.id, pageIndex: pageIndex)
                if let data = try? Data(contentsOf: markupURL),
                   let record = makeBinaryRecord(
                       agreementId: draft.id,
                       role: .markup,
                       pageIndex: pageIndex,
                       relativePath: nil,
                       data: data,
                       revision: max(revision, draft.updatedAt),
                       deviceId: deviceId
                   ) {
                    records.append(record)
                }

                let annotationURL = AgreementImportedPageAnnotationStore.annotationURL(
                    agreementId: draft.id,
                    pageIndex: pageIndex
                )
                if let data = try? Data(contentsOf: annotationURL),
                   let record = makeBinaryRecord(
                       agreementId: draft.id,
                       role: .annotation,
                       pageIndex: pageIndex,
                       relativePath: nil,
                       data: data,
                       revision: max(revision, draft.updatedAt),
                       deviceId: deviceId
                   ) {
                    records.append(record)
                }
            }
        }

        return records
    }

    @discardableResult
    static func applyFileRecord(_ record: PersonalSyncEntityRecord) -> Bool {
        guard record.entityKind == PersonalStudioEntityKind.agreementFile.cloudKind else { return false }
        guard let metadata = decodeMetadata(from: record.payloadJSON) else { return false }

        if record.isDeleted {
            deleteLocalFile(for: metadata)
            return true
        }

        guard let data = record.attachmentData, !data.isEmpty else { return false }

        switch metadata.role {
        case .signedDocument, .importedSource, .signedExport:
            guard let relativePath = metadata.relativePath else { return false }
            return AgreementDocumentStore.writeSyncedFile(data: data, relativePath: relativePath)
        case .markup:
            guard let pageIndex = metadata.pageIndex else { return false }
            let url = AgreementImportedMarkupStore.drawingURL(
                agreementId: metadata.agreementId,
                pageIndex: pageIndex
            )
            return writeData(data, to: url)
        case .annotation:
            guard let pageIndex = metadata.pageIndex else { return false }
            let url = AgreementImportedPageAnnotationStore.annotationURL(
                agreementId: metadata.agreementId,
                pageIndex: pageIndex
            )
            return writeData(data, to: url)
        }
    }

    static func entityHasUserData(_ record: PersonalSyncEntityRecord) -> Bool {
        guard record.entityKind == PersonalStudioEntityKind.agreementFile.cloudKind else { return false }
        return record.isDeleted || record.attachmentData != nil || decodeMetadata(from: record.payloadJSON) != nil
    }

    static func recordName(for record: PersonalSyncEntityRecord) -> String {
        "personal-studio-\(record.entityKind)-\(record.entityId)"
    }

    // MARK: - Private

    private static func makeFileRecord(
        agreementId: UUID,
        role: FileRole,
        storedPath: String,
        pageIndex: Int?,
        revision: Date,
        deviceId: String
    ) -> PersonalSyncEntityRecord? {
        guard let data = AgreementDocumentStore.loadData(path: storedPath) else { return nil }
        let relativePath = AgreementDocumentStore.normalizedStoredPath(storedPath)
        return makeBinaryRecord(
            agreementId: agreementId,
            role: role,
            pageIndex: pageIndex,
            relativePath: relativePath,
            data: data,
            revision: revision,
            deviceId: deviceId
        )
    }

    private static func makeBinaryRecord(
        agreementId: UUID,
        role: FileRole,
        pageIndex: Int?,
        relativePath: String?,
        data: Data,
        revision: Date,
        deviceId: String
    ) -> PersonalSyncEntityRecord? {
        let metadata = FileMetadata(
            agreementId: agreementId,
            role: role,
            relativePath: relativePath,
            pageIndex: pageIndex
        )
        guard let metadataJSON = encodeMetadata(metadata) else { return nil }
        let entityId = fileEntityId(agreementId: agreementId, role: role, pageIndex: pageIndex)
        return PersonalSyncEntityRecord(
            entityKind: PersonalStudioEntityKind.agreementFile.cloudKind,
            entityId: entityId,
            payloadJSON: metadataJSON,
            updatedAt: revision,
            deviceId: deviceId,
            contentHash: PersonalSyncContentHash.hash(data: data),
            usesExternalAsset: true,
            attachmentData: data
        )
    }

    private static func fileEntityId(agreementId: UUID, role: FileRole, pageIndex: Int?) -> String {
        if let pageIndex {
            return "\(agreementId.uuidString)-\(role.rawValue)-\(pageIndex)"
        }
        return "\(agreementId.uuidString)-\(role.rawValue)"
    }

    private static func encodeMetadata(_ metadata: FileMetadata) -> String? {
        guard let data = try? JSONEncoder().encode(metadata) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeMetadata(from payloadJSON: String) -> FileMetadata? {
        guard let data = payloadJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FileMetadata.self, from: data)
    }

    private static func deleteLocalFile(for metadata: FileMetadata) {
        switch metadata.role {
        case .signedDocument, .importedSource, .signedExport:
            AgreementDocumentStore.delete(path: metadata.relativePath)
        case .markup:
            if let pageIndex = metadata.pageIndex {
                try? FileManager.default.removeItem(
                    at: AgreementImportedMarkupStore.drawingURL(
                        agreementId: metadata.agreementId,
                        pageIndex: pageIndex
                    )
                )
            }
        case .annotation:
            if let pageIndex = metadata.pageIndex {
                AgreementImportedPageAnnotationStore.deletePage(
                    agreementId: metadata.agreementId,
                    pageIndex: pageIndex
                )
            }
        }
    }

    private static func writeData(_ data: Data, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }
}
