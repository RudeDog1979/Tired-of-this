//
//  BuxPadCustomAgreementUploadRoadmap.swift
//  BuxMuse — Post-release: customer-uploaded agreements (Word/PDF/image) + signing.
//
//  Planned flow (not implemented):
//  1. Import via Files / Photos / document picker into Agreements sandbox.
//  2. Render PDF pages or rasterized DOCX preview on iPad.
//  3. Overlay Pencil signature + export signed PDF.
//  4. Keep sidecar storage — avoid breaking existing AgreementDraft Codable payloads.
//

import Foundation

enum BuxPadCustomAgreementUploadRoadmap {
    static let plannedReleaseNote = "Customer agreement upload (Word, PDF, photo) is planned for a post-release update."
}
