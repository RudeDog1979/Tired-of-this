//
//  BuxPadExternalDisplayTests.swift
//

import Foundation
import Testing
@testable import BuxMuse

@MainActor
struct BuxPadExternalDisplayTests {

    @Test func externalDisplay_disconnect_preservesPresentationKind() {
        let brain = BuxPadNavigationBrain()
        brain.handleExternalScreensChanged(extraScreenCount: 1)
        brain.requestExternalPresentation(.moneyMap)
        #expect(brain.activeExternalPresentation == .moneyMap)
        brain.handleExternalDisplayDisconnected()
        #expect(brain.externalDisplayConnection == .disconnected)
        #expect(brain.activeExternalPresentation == .moneyMap)
    }

    @Test func externalPresentation_setsSessionId() {
        let brain = BuxPadNavigationBrain()
        brain.requestExternalPresentation(.invoicePreview)
        #expect(brain.externalPresentationSessionId != nil)
        #expect(brain.externalPresentationRevision == 1)
    }

    @Test func invoiceContextUpdate_incrementsRevision() {
        let brain = BuxPadNavigationBrain()
        brain.updateExternalInvoiceContext(nil, targetInvoiceId: UUID())
        #expect(brain.externalPresentationRevision == 1)
    }

    @Test func presentationPayload_roundTripsKind() {
        let payload = BuxPadPresentationPayload(sessionId: UUID(), kind: .moneyMap)
        #expect(payload.kind == .moneyMap)
        #expect(BuxPadExternalPresentationKind(rawValue: "invoicePreview") == .invoicePreview)
    }

    @Test func restorationUserInfo_includesPresentationKind() {
        let info = BuxPadSceneRestoration.userInfo(
            sessionId: UUID(),
            snapshot: BuxPadNavigationSnapshot(),
            presentationKind: BuxPadExternalPresentationKind.moneyMap.rawValue
        )
        #expect(BuxPadSceneRestoration.presentationKind(from: info) == "moneyMap")
    }
}
