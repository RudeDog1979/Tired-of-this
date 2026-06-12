//
//  AgreementImportedSignStudioPresentation.swift
//  BuxMuse — Reliable full-screen sign studio presentation token.
//

import CoreGraphics
import Foundation

struct AgreementImportedSignStudioPresentation: Identifiable {
    let id = UUID()
    var initialRole: AgreementSignatureRole = .client
    var pendingTapCenter: CGPoint?

    static func openDocument() -> AgreementImportedSignStudioPresentation {
        AgreementImportedSignStudioPresentation()
    }

    static func signAs(_ role: AgreementSignatureRole) -> AgreementImportedSignStudioPresentation {
        AgreementImportedSignStudioPresentation(initialRole: role)
    }
}
