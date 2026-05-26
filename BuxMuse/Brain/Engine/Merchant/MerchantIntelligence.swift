//
//  MerchantIntelligence.swift
//  BuxMuse
//  Brain/Engine/Merchant/
//
//  Merchant Clustering Algorithms (Levenshtein grouping and name normalization).
//

import Foundation

public struct MerchantIntelligence {
    
    /// Normalizes a merchant name:
    /// - Lowercase
    /// - Trim whitespaces and newlines
    /// - Remove common business suffixes (Ltd, Inc, S.A., LLC, Corp, Co, Incorporated, Limited)
    /// - Remove emojis
    /// - Remove punctuation and special characters
    public static func normalize(_ name: String) -> String {
        var clean = name.lowercased()
        
        // Remove emojis
        clean = clean.filter { !$0.isEmoji }
        
        // Remove business suffixes as whole words
        let suffixes = ["ltd", "inc", "s.a.", "sa", "llc", "corp", "co", "incorporated", "limited"]
        for suffix in suffixes {
            // Match word boundaries: e.g. "apple inc" -> "apple"
            clean = clean.replacingOccurrences(of: "\\b\(suffix)\\b", with: "", options: .regularExpression)
        }
        
        // Strip punctuation and symbols (keeping alphanumeric and spaces)
        clean = clean.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet.whitespaces).inverted).joined()
        
        // Trim edge spaces and collapse multiple consecutive spaces
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return clean
    }
    
    /// Computes the Levenshtein distance between two normalized strings
    public static func levenshteinDistance(between s1: String, and s2: String) -> Int {
        if s1.isEmpty { return s2.count }
        if s2.isEmpty { return s1.count }
        
        let empty = [Int](repeating: 0, count: s2.count + 1)
        var last = [Int](repeating: 0, count: s2.count + 1)
        var current = empty

        for i in 0...s2.count {
            last[i] = i
        }

        for (i, char1) in s1.enumerated() {
            current[0] = i + 1
            for (j, char2) in s2.enumerated() {
                if char1 == char2 {
                    current[j + 1] = last[j]
                } else {
                    current[j + 1] = min(
                        last[j] + 1,      // substitution
                        last[j + 1] + 1,  // deletion
                        current[j] + 1    // insertion
                    )
                }
            }
            last = current
        }

        return last[s2.count]
    }
    
    /// Clusters raw merchant names together.
    /// Merchants with a Levenshtein distance below the threshold are grouped under a canonical title.
    public static func clusterMerchants(_ names: [String], distanceThreshold: Int = 2) -> [MerchantCluster] {
        var clusters: [MerchantCluster] = []
        
        for name in names {
            let normalized = normalize(name)
            guard !normalized.isEmpty else { continue }
            
            // Check if it fits into an existing cluster
            var added = false
            for (idx, cluster) in clusters.enumerated() {
                let canonicalNormalized = normalize(cluster.canonicalName)
                
                // Compare with the canonical name or any names in the cluster
                let distance = levenshteinDistance(between: normalized, and: canonicalNormalized)
                if distance <= distanceThreshold {
                    var updatedNames = cluster.merchantNames
                    if !updatedNames.contains(name) {
                        updatedNames.append(name)
                    }
                    clusters[idx] = MerchantCluster(id: cluster.id, canonicalName: cluster.canonicalName, merchantNames: updatedNames)
                    added = true
                    break
                }
            }
            
            // Create a new cluster if it didn't fit anywhere
            if !added {
                let canonicalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                clusters.append(MerchantCluster(canonicalName: canonicalName, merchantNames: [name]))
            }
        }
        
        return clusters
    }
}

// MARK: - Character Emoji Helper
extension Character {
    fileprivate var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value >= 0x203C || scalar.properties.isEmojiPresentation)
    }
}
