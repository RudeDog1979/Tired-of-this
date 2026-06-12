//
//  BuxPadSceneBrainRegistryTests.swift
//

import Foundation
import Testing
@testable import BuxMuse

@MainActor
struct BuxPadSceneBrainRegistryTests {

    @Test func primarySession_returnsSharedBrain() {
        let primary = BuxPadNavigationBrain()
        let registry = BuxPadSceneBrainRegistry(primaryBrain: primary)
        #expect(registry.brain(for: nil) === primary)
    }

    @Test func auxiliarySession_getsDistinctBrain() {
        let primary = BuxPadNavigationBrain()
        let registry = BuxPadSceneBrainRegistry(primaryBrain: primary)
        let sessionA = UUID()
        let sessionB = UUID()
        let brainA = registry.brain(for: sessionA)
        let brainB = registry.brain(for: sessionB)
        #expect(brainA !== primary)
        #expect(brainB !== primary)
        #expect(brainA !== brainB)
        #expect(registry.brain(for: sessionA) === brainA)
    }

    @Test func snapshot_roundTrip_preservesSelection() {
        let brain = BuxPadNavigationBrain()
        let expenseId = UUID()
        brain.selectExpense(expenseId)
        brain.selectedStudioDestination = BuxPadStudioDestination.invoices.rawValue

        let snapshot = brain.exportSnapshot()
        let restored = BuxPadNavigationBrain()
        restored.applySnapshot(snapshot)

        #expect(restored.selectedExpenseId == expenseId)
        #expect(restored.selectedStudioDestination == BuxPadStudioDestination.invoices.rawValue)
    }

    @Test func restorationUserInfo_decodesSnapshot() {
        let sessionId = UUID()
        let snapshot = BuxPadNavigationSnapshot(
            selectedExpenseId: UUID(),
            selectedStudioDestination: "invoices",
            selectedSettingsPath: nil
        )
        let info = BuxPadSceneRestoration.userInfo(sessionId: sessionId, snapshot: snapshot)
        #expect(BuxPadSceneRestoration.sessionId(from: info) == sessionId)
        #expect(BuxPadSceneRestoration.snapshot(from: info) == snapshot)
    }
}
