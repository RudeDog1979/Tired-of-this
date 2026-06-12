//
//  BuxPadWindowIDs.swift
//  BuxMuse — Scene identifiers for iPadOS multi-window (Stage Manager).
//

import Foundation

enum BuxPadWindowID {
    static let expense = "buxmuse.pad.expense"
    static let studio = "buxmuse.pad.studio"
    static let presentation = "presentation"
}

enum BuxPadSceneActivity {
    static let expenseWindow = "com.buxmuse.pad.expense-window"
    static let studioWindow = "com.buxmuse.pad.studio-window"
    static let presentationWindow = "com.buxmuse.pad.presentation-window"

    static let sessionKey = "sessionId"
    static let studioDestinationKey = "studioDestination"
    static let presentationKindKey = "presentationKind"
}

enum BuxPadExternalPresentationKind: String, Codable, Hashable, CaseIterable {
    case moneyMap
    case invoicePreview
}

struct BuxPadPresentationPayload: Codable, Hashable, Identifiable {
    var sessionId: UUID
    var kind: BuxPadExternalPresentationKind

    var id: String { sessionId.uuidString }
}
