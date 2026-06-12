//
//  SynergyBridgeModels.swift
//  BuxMuse
//
//  Linked ledger entries across workspaces (splits + dividend transfers).
//

import Foundation

public enum SynergyBridgeKind: String, Codable, Equatable {
    case split
    case dividendTransfer
}

public enum SynergyBridgeRole: String, Codable, Equatable {
    case splitPrimary
    case splitSecondary
    case transferOut
    case transferIn
}

public enum SynergyBridgeEntryMode: String, CaseIterable, Identifiable {
    case standard
    case split
    case dividendTransfer

    public var id: String { rawValue }
}

public struct SynergyBridgeMetadata: Equatable {
    public var bridgeGroupId: UUID?
    public var bridgeKind: SynergyBridgeKind?
    public var bridgeRole: SynergyBridgeRole?
    public var bridgeSharePercent: Double?
    public var bridgePeerExpenseId: UUID?
    public var bridgeCounterpartyHustleId: UUID?
}
