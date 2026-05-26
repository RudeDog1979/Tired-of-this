//
//  MerchantAutocompleteEngine.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Autocomplete Engine bound strictly to BuxMuse Brain.
//

import Foundation

public struct MerchantAutocompleteEngine {
    private let engine: FinancialIntelligenceEngine
    
    public init(engine: FinancialIntelligenceEngine) {
        self.engine = engine
    }
    
    /// Queries the Brain for merchant suggestions matching the query prefix
    public func suggestions(for query: String) -> [String] {
        let normalizedQuery = MerchantLogoEngine.normalizeMerchantName(query)
        guard !normalizedQuery.isEmpty else { return [] }
        
        // 1. Gather all unique raw merchant names from past transactions in the Brain
        let pastNames = engine.allTransactions().map { $0.merchantName }
        
        // 2. Gather canonical names from clusters in the Brain
        let clusterNames = engine.merchantClusters().map { $0.canonicalName }
        
        let allNames = Array(Set(pastNames + clusterNames))
        
        // 3. Filter names where normalized version starts with or contains the query
        return allNames.filter { name in
            let normalized = MerchantLogoEngine.normalizeMerchantName(name)
            return normalized.starts(with: normalizedQuery) || (normalized.contains(normalizedQuery) && normalizedQuery.count >= 2)
        }.sorted { n1, n2 in
            let norm1 = MerchantLogoEngine.normalizeMerchantName(n1)
            let norm2 = MerchantLogoEngine.normalizeMerchantName(n2)
            let p1 = norm1.starts(with: normalizedQuery)
            let p2 = norm2.starts(with: normalizedQuery)
            if p1 != p2 {
                return p1
            }
            return n1.compare(n2, options: .caseInsensitive) == .orderedAscending
        }
    }
}
