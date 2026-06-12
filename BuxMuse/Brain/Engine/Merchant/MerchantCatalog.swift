//
//  MerchantCatalog.swift
//  BuxMuse
//
//  Offline catalog of well-known retailers for autocomplete + logo domains.
//

import Foundation

struct MerchantCatalogEntry: Sendable, Equatable {
    let displayName: String
    let domain: String
    /// Alternate spellings, abbreviations, and statement labels.
    let searchNames: [String]

    var normalizedKeys: [String] {
        searchNames.map { MerchantLogoEngine.normalizeMerchantName($0) }
    }
}

enum MerchantCatalog {
    /// Curated retailers — UK, PL, and common international brands.
    static let entries: [MerchantCatalogEntry] = [
        // Poland
        MerchantCatalogEntry(displayName: "Biedronka", domain: "biedronka.pl", searchNames: ["Biedronka", "Jeronimo Martins"]),
        MerchantCatalogEntry(displayName: "Lidl", domain: "lidl.pl", searchNames: ["Lidl", "Lidl GB", "Lidl PL"]),
        MerchantCatalogEntry(displayName: "Aldi", domain: "aldi.pl", searchNames: ["Aldi", "Aldi Stores", "Aldi PL"]),
        MerchantCatalogEntry(displayName: "Żabka", domain: "zabka.pl", searchNames: ["Żabka", "Zabka", "Zabka Nano"]),
        MerchantCatalogEntry(displayName: "Kaufland", domain: "kaufland.pl", searchNames: ["Kaufland"]),
        MerchantCatalogEntry(displayName: "Carrefour", domain: "carrefour.pl", searchNames: ["Carrefour", "Carrefour Express"]),
        MerchantCatalogEntry(displayName: "Auchan", domain: "auchan.pl", searchNames: ["Auchan", "Auchan Direct"]),
        MerchantCatalogEntry(displayName: "Pepco", domain: "pepco.pl", searchNames: ["Pepco", "Pepco Poland"]),
        MerchantCatalogEntry(displayName: "Media Expert", domain: "mediaexpert.pl", searchNames: ["Media Expert", "MediaExpert"]),
        MerchantCatalogEntry(displayName: "RTV Euro AGD", domain: "euro.com.pl", searchNames: ["RTV Euro AGD", "Euro RTV AGD", "Euro AGD", "Euro.com.pl"]),
        MerchantCatalogEntry(displayName: "Allegro", domain: "allegro.pl", searchNames: ["Allegro", "Allegro Pay"]),
        MerchantCatalogEntry(displayName: "Orlen", domain: "orlen.pl", searchNames: ["Orlen", "PKN Orlen", "Orlen Pay"]),
        MerchantCatalogEntry(displayName: "BP", domain: "bp.com", searchNames: ["BP", "BP Pulse"]),
        MerchantCatalogEntry(displayName: "Shell", domain: "shell.pl", searchNames: ["Shell", "Shell Select"]),

        // United Kingdom
        MerchantCatalogEntry(displayName: "Argos", domain: "argos.co.uk", searchNames: ["Argos", "Argos Ltd"]),
        MerchantCatalogEntry(displayName: "Currys", domain: "currys.co.uk", searchNames: ["Currys", "Currys PC World", "PC World", "Currys PLC"]),
        MerchantCatalogEntry(displayName: "Tesco", domain: "tesco.com", searchNames: ["Tesco", "Tesco Express", "Tesco Metro", "Tesco Extra"]),
        MerchantCatalogEntry(displayName: "Sainsbury's", domain: "sainsburys.co.uk", searchNames: ["Sainsbury's", "Sainsburys", "Sainsbury", "Sainsbury's Local"]),
        MerchantCatalogEntry(displayName: "ASDA", domain: "asda.com", searchNames: ["ASDA", "Asda", "Asda Superstore"]),
        MerchantCatalogEntry(displayName: "Morrisons", domain: "morrisons.com", searchNames: ["Morrisons", "Morrisons Daily"]),
        MerchantCatalogEntry(displayName: "Marks & Spencer", domain: "marksandspencer.com", searchNames: ["Marks & Spencer", "Marks and Spencer", "M&S", "M&S Simply Food", "Marks & Spencer Simply Food"]),
        MerchantCatalogEntry(displayName: "Boots", domain: "boots.com", searchNames: ["Boots", "Boots Pharmacy", "Boots UK"]),
        MerchantCatalogEntry(displayName: "Primark", domain: "primark.com", searchNames: ["Primark", "Primark Stores"]),
        MerchantCatalogEntry(displayName: "B&M", domain: "bmstores.co.uk", searchNames: ["B&M", "B&M Bargains", "B and M"]),
        MerchantCatalogEntry(displayName: "Wilko", domain: "wilko.com", searchNames: ["Wilko", "Wilkinson"]),
        MerchantCatalogEntry(displayName: "John Lewis", domain: "johnlewis.com", searchNames: ["John Lewis", "John Lewis & Partners"]),
        MerchantCatalogEntry(displayName: "Halfords", domain: "halfords.com", searchNames: ["Halfords", "Halfords Autocentre"]),
        MerchantCatalogEntry(displayName: "Wickes", domain: "wickes.co.uk", searchNames: ["Wickes"]),
        MerchantCatalogEntry(displayName: "B&Q", domain: "diy.com", searchNames: ["B&Q", "B and Q", "BandQ"]),
        MerchantCatalogEntry(displayName: "Screwfix", domain: "screwfix.com", searchNames: ["Screwfix"]),
        MerchantCatalogEntry(displayName: "Waitrose", domain: "waitrose.com", searchNames: ["Waitrose", "Waitrose & Partners"]),
        MerchantCatalogEntry(displayName: "Co-op", domain: "coop.co.uk", searchNames: ["Co-op", "Coop", "The Co-operative"]),
        MerchantCatalogEntry(displayName: "Iceland", domain: "iceland.co.uk", searchNames: ["Iceland", "Iceland Foods"]),
        MerchantCatalogEntry(displayName: "Poundland", domain: "poundland.co.uk", searchNames: ["Poundland"]),
        MerchantCatalogEntry(displayName: "Home Bargains", domain: "homebargains.co.uk", searchNames: ["Home Bargains"]),
        MerchantCatalogEntry(displayName: "Sports Direct", domain: "sportsdirect.com", searchNames: ["Sports Direct", "SportsDirect"]),
        MerchantCatalogEntry(displayName: "JD Sports", domain: "jdsports.co.uk", searchNames: ["JD Sports", "JD"]),
        MerchantCatalogEntry(displayName: "Amazon", domain: "amazon.co.uk", searchNames: ["Amazon", "Amazon UK", "Amazon.co.uk", "AMZN Mktp"]),
        MerchantCatalogEntry(displayName: "Deliveroo", domain: "deliveroo.co.uk", searchNames: ["Deliveroo"]),
        MerchantCatalogEntry(displayName: "Uber Eats", domain: "ubereats.com", searchNames: ["Uber Eats", "UberEats"]),
        MerchantCatalogEntry(displayName: "Greggs", domain: "greggs.co.uk", searchNames: ["Greggs"]),
        MerchantCatalogEntry(displayName: "Costa", domain: "costa.co.uk", searchNames: ["Costa", "Costa Coffee"]),
        MerchantCatalogEntry(displayName: "Nando's", domain: "nandos.co.uk", searchNames: ["Nando's", "Nandos"]),
        MerchantCatalogEntry(displayName: "Pret A Manger", domain: "pret.co.uk", searchNames: ["Pret", "Pret A Manger", "Pret A Manger"]),
        MerchantCatalogEntry(displayName: "Dunelm", domain: "dunelm.com", searchNames: ["Dunelm"]),
        MerchantCatalogEntry(displayName: "Decathlon", domain: "decathlon.co.uk", searchNames: ["Decathlon"]),
        MerchantCatalogEntry(displayName: "PayPal", domain: "paypal.com", searchNames: ["PayPal", "Paypal"]),
        MerchantCatalogEntry(displayName: "Disney+", domain: "disneyplus.com", searchNames: ["Disney+", "Disney Plus", "DisneyPlus"]),
        MerchantCatalogEntry(displayName: "Action", domain: "action.com", searchNames: ["Action"]),
        MerchantCatalogEntry(displayName: "Dino", domain: "marketdino.pl", searchNames: ["Dino", "Dino Polska"]),
        MerchantCatalogEntry(displayName: "Groszek", domain: "groszek.pl", searchNames: ["Groszek"]),
        MerchantCatalogEntry(displayName: "Castorama", domain: "castorama.pl", searchNames: ["Castorama"]),
        MerchantCatalogEntry(displayName: "OBI", domain: "obi.pl", searchNames: ["OBI", "Obi"]),
        MerchantCatalogEntry(displayName: "Ryanair", domain: "ryanair.com", searchNames: ["Ryanair"]),
        MerchantCatalogEntry(displayName: "Wizz Air", domain: "wizzair.com", searchNames: ["Wizz Air", "WizzAir"]),
        MerchantCatalogEntry(displayName: "Booking.com", domain: "booking.com", searchNames: ["Booking.com", "Booking"]),
        MerchantCatalogEntry(displayName: "Airbnb", domain: "airbnb.com", searchNames: ["Airbnb"]),
        MerchantCatalogEntry(displayName: "Just Eat", domain: "just-eat.co.uk", searchNames: ["Just Eat", "JustEat"]),

        // International / subscriptions (logos + quick pick)
        MerchantCatalogEntry(displayName: "Starbucks", domain: "starbucks.com", searchNames: ["Starbucks"]),
        MerchantCatalogEntry(displayName: "Apple", domain: "apple.com", searchNames: ["Apple", "Apple Store", "Apple.com"]),
        MerchantCatalogEntry(displayName: "Netflix", domain: "netflix.com", searchNames: ["Netflix"]),
        MerchantCatalogEntry(displayName: "Spotify", domain: "spotify.com", searchNames: ["Spotify"]),
        MerchantCatalogEntry(displayName: "Uber", domain: "uber.com", searchNames: ["Uber", "Uber Trip"]),
        MerchantCatalogEntry(displayName: "McDonald's", domain: "mcdonalds.com", searchNames: ["McDonald's", "McDonalds", "Mcdonalds"]),
        MerchantCatalogEntry(displayName: "Google", domain: "google.com", searchNames: ["Google", "Google Play", "Google One"]),
        MerchantCatalogEntry(displayName: "Microsoft", domain: "microsoft.com", searchNames: ["Microsoft", "Microsoft 365", "Xbox"]),
        MerchantCatalogEntry(displayName: "IKEA", domain: "ikea.com", searchNames: ["IKEA", "Ikea"]),
        MerchantCatalogEntry(displayName: "H&M", domain: "hm.com", searchNames: ["H&M", "H and M", "HM"]),
        MerchantCatalogEntry(displayName: "Zara", domain: "zara.com", searchNames: ["Zara"]),
        MerchantCatalogEntry(displayName: "Nike", domain: "nike.com", searchNames: ["Nike"]),
        MerchantCatalogEntry(displayName: "Walmart", domain: "walmart.com", searchNames: ["Walmart"]),
        MerchantCatalogEntry(displayName: "Target", domain: "target.com", searchNames: ["Target"]),
    ]

    private static let byNormalizedName: [String: MerchantCatalogEntry] = {
        var map: [String: MerchantCatalogEntry] = [:]
        for entry in entries {
            for key in entry.normalizedKeys where !key.isEmpty {
                map[key] = entry
            }
        }
        return map
    }()

    /// Best domain for logo fetch — exact catalog hit first, then fuzzy name match.
    static func domain(for merchantName: String) -> String? {
        let normalized = MerchantLogoEngine.normalizeMerchantName(merchantName)
        guard !normalized.isEmpty else { return nil }
        if let hit = byNormalizedName[normalized] { return hit.domain }
        if let fuzzy = matchingEntries(for: merchantName, limit: 1).first { return fuzzy.domain }
        return nil
    }

    /// Autocomplete — prefix, contains, word-start, and fuzzy (typo-tolerant).
    static func matchingEntries(for query: String, limit: Int = 12) -> [MerchantCatalogEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = MerchantLogoEngine.normalizeMerchantName(trimmed)
        guard !normalizedQuery.isEmpty else { return [] }

        let compactQuery = normalizedQuery.replacingOccurrences(of: " ", with: "")
        let queryWords = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        var scored: [(entry: MerchantCatalogEntry, rank: Int, label: String)] = []

        for entry in entries {
            var bestRank: Int?
            for name in entry.searchNames + [entry.displayName] {
                let norm = MerchantLogoEngine.normalizeMerchantName(name)
                let compact = norm.replacingOccurrences(of: " ", with: "")
                let rank: Int?
                if norm.hasPrefix(normalizedQuery) || compact.hasPrefix(compactQuery) {
                    rank = 0
                } else if matchesWordPrefixes(queryWords, in: name) {
                    rank = 1
                } else if normalizedQuery.count >= 1, norm.contains(normalizedQuery) || compact.contains(compactQuery) {
                    rank = 2
                } else if name.localizedCaseInsensitiveContains(trimmed) {
                    rank = 3
                } else if normalizedQuery.count >= 3 {
                    let distance = MerchantIntelligence.levenshteinDistance(between: normalizedQuery, and: norm)
                    rank = distance <= 2 ? 4 : nil
                } else {
                    rank = nil
                }
                if let rank, bestRank == nil || rank < bestRank! {
                    bestRank = rank
                }
            }
            if let bestRank {
                scored.append((entry, bestRank, entry.displayName))
            }
        }

        scored.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }

        var seen = Set<String>()
        var results: [MerchantCatalogEntry] = []
        for item in scored {
            let key = MerchantLogoEngine.normalizeMerchantName(item.entry.displayName)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            results.append(item.entry)
            if results.count >= limit { break }
        }
        return results
    }

    private static func matchesWordPrefixes(_ queryWords: [String], in name: String) -> Bool {
        guard !queryWords.isEmpty else { return false }
        let nameWords = name.split(whereSeparator: { $0.isWhitespace || !$0.isLetter }).map { String($0).lowercased() }
        guard !nameWords.isEmpty else { return false }

        var nameIndex = 0
        for rawWord in queryWords {
            let word = rawWord.lowercased()
            guard !word.isEmpty else { continue }
            var matched = false
            while nameIndex < nameWords.count {
                if nameWords[nameIndex].hasPrefix(word) {
                    nameIndex += 1
                    matched = true
                    break
                }
                nameIndex += 1
            }
            if !matched { return false }
        }
        return true
    }

    /// Alternate labels for the same retailer (e.g. M&S ↔ Marks & Spencer).
    static func alternateLabels(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let normalizedQuery = MerchantLogoEngine.normalizeMerchantName(trimmed)

        for entry in entries {
            let groupMatches = entry.searchNames.contains { name in
                let norm = MerchantLogoEngine.normalizeMerchantName(name)
                return norm.hasPrefix(normalizedQuery)
                    || normalizedQuery.hasPrefix(norm)
                    || (normalizedQuery.count >= 2 && norm.contains(normalizedQuery))
                    || name.localizedCaseInsensitiveContains(trimmed)
            }
            if groupMatches {
                return entry.searchNames
            }
        }
        return []
    }
}
