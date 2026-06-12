//
//  TaxCoverageTier.swift
//  BuxMuse
//
//  Tax Engine v2 — coverage confidence per country (Phase 0).
//

import Foundation

/// How deeply BuxMuse can compute tax for a jurisdiction.
public enum TaxCoverageTier: String, Codable, Sendable, CaseIterable {
    /// Country module + golden tests (GB, US, ES, DR, FR, PL, …).
    case verified = "T1"
    /// Structured brackets + VAT from catalog; generic kernel.
    case structured = "T2"
    /// Prose reference + user manual % override (legacy path).
    case manualOverride = "T3"

    public var catalogLabelKey: String {
        switch self {
        case .verified: return "Tax rules verified"
        case .structured: return "Tax rules structured estimate"
        case .manualOverride: return "Tax rules manual override"
        }
    }
}

public enum TaxEngineIncomePath: String, Codable, Sendable, CaseIterable, Hashable {
    case selfEmployed
    case gig
    case employedHypothetical
    case mixed
}
