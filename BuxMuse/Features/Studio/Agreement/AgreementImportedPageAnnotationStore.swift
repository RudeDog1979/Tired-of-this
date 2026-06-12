//
//  AgreementImportedPageAnnotationStore.swift
//  BuxMuse — Per-page layout + draggable signature placements (sidecar, no model changes).
//

import CoreGraphics
import Foundation

struct AgreementImportedSignaturePlacement: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var role: String
    var normalizedRect: AgreementImportedNormalizedRect
    var rotationDegrees: Double

    var signatureRole: AgreementSignatureRole? {
        AgreementImportedPageAnnotationStore.role(from: role)
    }

    init(
        id: UUID,
        role: String,
        normalizedRect: AgreementImportedNormalizedRect,
        rotationDegrees: Double = 0
    ) {
        self.id = id
        self.role = role
        self.normalizedRect = normalizedRect
        self.rotationDegrees = rotationDegrees
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(String.self, forKey: .role)
        normalizedRect = try container.decode(AgreementImportedNormalizedRect.self, forKey: .normalizedRect)
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case normalizedRect
        case rotationDegrees
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(normalizedRect, forKey: .normalizedRect)
        try container.encode(rotationDegrees, forKey: .rotationDegrees)
    }
}

struct AgreementImportedPageAnnotation: Codable, Equatable, Sendable {
    var pageWidth: Double
    var pageHeight: Double
    var markupCanvasWidth: Double?
    var markupCanvasHeight: Double?
    var signaturePlacements: [AgreementImportedSignaturePlacement]

    var pageSize: CGSize {
        CGSize(width: pageWidth, height: pageHeight)
    }

    var markupCanvasSize: CGSize? {
        guard let markupCanvasWidth, let markupCanvasHeight else { return nil }
        return CGSize(width: markupCanvasWidth, height: markupCanvasHeight)
    }

    init(
        pageSize: CGSize,
        markupCanvasSize: CGSize? = nil,
        signaturePlacements: [AgreementImportedSignaturePlacement] = []
    ) {
        pageWidth = Double(pageSize.width)
        pageHeight = Double(pageSize.height)
        markupCanvasWidth = markupCanvasSize.map { Double($0.width) }
        markupCanvasHeight = markupCanvasSize.map { Double($0.height) }
        self.signaturePlacements = signaturePlacements
    }
}

enum AgreementImportedPageAnnotationStore {
    private static let folderName = "StudioAgreementAnnotations"

    static func annotationURL(agreementId: UUID, pageIndex: Int) -> URL {
        annotationDirectory().appendingPathComponent("\(agreementId.uuidString)-page-\(pageIndex).annotations.json")
    }

    static func load(agreementId: UUID, pageIndex: Int) -> AgreementImportedPageAnnotation? {
        let url = annotationURL(agreementId: agreementId, pageIndex: pageIndex)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AgreementImportedPageAnnotation.self, from: data)
    }

    static func loadOrDefault(agreementId: UUID, pageIndex: Int, pageSize: CGSize) -> AgreementImportedPageAnnotation {
        load(agreementId: agreementId, pageIndex: pageIndex)
            ?? AgreementImportedPageAnnotation(pageSize: pageSize)
    }

    @discardableResult
    static func save(_ annotation: AgreementImportedPageAnnotation, agreementId: UUID, pageIndex: Int) -> Bool {
        let url = annotationURL(agreementId: agreementId, pageIndex: pageIndex)
        do {
            try ensureDirectory()
            let hasContent = !annotation.signaturePlacements.isEmpty
                || annotation.markupCanvasSize != nil
            if !hasContent {
                try? FileManager.default.removeItem(at: url)
                return true
            }
            let data = try JSONEncoder().encode(annotation)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func hasPlacements(for agreementId: UUID, pageIndex: Int) -> Bool {
        !(load(agreementId: agreementId, pageIndex: pageIndex)?.signaturePlacements.isEmpty ?? true)
    }

    static func deletePage(agreementId: UUID, pageIndex: Int) {
        try? FileManager.default.removeItem(at: annotationURL(agreementId: agreementId, pageIndex: pageIndex))
    }

    static func deleteAll(for agreementId: UUID, pageCount: Int) {
        let limit = min(pageCount, AgreementImportedDocumentLimits.maxSignablePages)
        for index in 0..<limit {
            deletePage(agreementId: agreementId, pageIndex: index)
        }
    }

    static func role(from key: String) -> AgreementSignatureRole? {
        switch key {
        case AgreementSignatureRole.provider.storageKey: return .provider
        case AgreementSignatureRole.client.storageKey: return .client
        default: return nil
        }
    }

    private static func annotationDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    private static func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: annotationDirectory(),
            withIntermediateDirectories: true
        )
    }
}

extension AgreementSignatureRole {
    var storageKey: String {
        switch self {
        case .provider: "provider"
        case .client: "client"
        }
    }
}
