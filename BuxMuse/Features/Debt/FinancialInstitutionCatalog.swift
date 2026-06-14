//
//  FinancialInstitutionCatalog.swift
//  BuxMuse
//
//  Curated banks and credit unions — logo fetch only when matched here.
//

import Foundation

struct FinancialInstitutionEntry: Sendable, Equatable {
    let displayName: String
    let domain: String
    let searchNames: [String]
}

enum FinancialInstitutionCatalog {
    static let entries: [FinancialInstitutionEntry] = [
        FinancialInstitutionEntry(displayName: "Chase", domain: "chase.com", searchNames: ["Chase", "JPMorgan Chase", "Chase Bank"]),
        FinancialInstitutionEntry(displayName: "Bank of America", domain: "bankofamerica.com", searchNames: ["Bank of America", "BofA", "BoA"]),
        FinancialInstitutionEntry(displayName: "Wells Fargo", domain: "wellsfargo.com", searchNames: ["Wells Fargo"]),
        FinancialInstitutionEntry(displayName: "Citibank", domain: "citi.com", searchNames: ["Citibank", "Citi", "Citigroup"]),
        FinancialInstitutionEntry(displayName: "Capital One", domain: "capitalone.com", searchNames: ["Capital One"]),
        FinancialInstitutionEntry(displayName: "American Express", domain: "americanexpress.com", searchNames: ["American Express", "Amex", "AMEX"]),
        FinancialInstitutionEntry(displayName: "Discover", domain: "discover.com", searchNames: ["Discover", "Discover Bank"]),
        FinancialInstitutionEntry(displayName: "US Bank", domain: "usbank.com", searchNames: ["US Bank", "U.S. Bank"]),
        FinancialInstitutionEntry(displayName: "PNC", domain: "pnc.com", searchNames: ["PNC", "PNC Bank"]),
        FinancialInstitutionEntry(displayName: "TD Bank", domain: "td.com", searchNames: ["TD Bank", "TD"]),
        FinancialInstitutionEntry(displayName: "Barclays", domain: "barclays.co.uk", searchNames: ["Barclays", "Barclaycard"]),
        FinancialInstitutionEntry(displayName: "HSBC", domain: "hsbc.co.uk", searchNames: ["HSBC", "HSBC UK"]),
        FinancialInstitutionEntry(displayName: "Lloyds", domain: "lloydsbank.com", searchNames: ["Lloyds", "Lloyds Bank"]),
        FinancialInstitutionEntry(displayName: "NatWest", domain: "natwest.com", searchNames: ["NatWest", "Nat West"]),
        FinancialInstitutionEntry(displayName: "Santander", domain: "santander.co.uk", searchNames: ["Santander", "Santander UK"]),
        FinancialInstitutionEntry(displayName: "Monzo", domain: "monzo.com", searchNames: ["Monzo"]),
        FinancialInstitutionEntry(displayName: "Starling", domain: "starlingbank.com", searchNames: ["Starling", "Starling Bank"]),
        FinancialInstitutionEntry(displayName: "Revolut", domain: "revolut.com", searchNames: ["Revolut"]),
        FinancialInstitutionEntry(displayName: "Nationwide", domain: "nationwide.co.uk", searchNames: ["Nationwide", "Nationwide Building Society"]),
        FinancialInstitutionEntry(displayName: "Halifax", domain: "halifax.co.uk", searchNames: ["Halifax"]),
        FinancialInstitutionEntry(displayName: "MBNA", domain: "mbna.co.uk", searchNames: ["MBNA"]),
        FinancialInstitutionEntry(displayName: "Klarna", domain: "klarna.com", searchNames: ["Klarna"]),
        FinancialInstitutionEntry(displayName: "PayPal Credit", domain: "paypal.com", searchNames: ["PayPal Credit", "PayPal"]),
        FinancialInstitutionEntry(displayName: "mBank", domain: "mbank.pl", searchNames: ["mBank", "mBank SA"]),
        FinancialInstitutionEntry(displayName: "PKO BP", domain: "pkobp.pl", searchNames: ["PKO BP", "PKO Bank Polski", "PKO"]),
        FinancialInstitutionEntry(displayName: "ING", domain: "ing.pl", searchNames: ["ING", "ING Bank", "ING Bank Śląski"]),
        FinancialInstitutionEntry(displayName: "Santander Polska", domain: "santander.pl", searchNames: ["Santander Polska", "Santander Bank Polska"]),
        FinancialInstitutionEntry(displayName: "Millennium", domain: "bankmillennium.pl", searchNames: ["Millennium", "Bank Millennium"]),
        FinancialInstitutionEntry(displayName: "Alior Bank", domain: "aliorbank.pl", searchNames: ["Alior Bank", "Alior"]),
        FinancialInstitutionEntry(displayName: "BNP Paribas", domain: "bnpparibas.pl", searchNames: ["BNP Paribas", "BNP"]),
        FinancialInstitutionEntry(displayName: "Credit Agricole", domain: "credit-agricole.pl", searchNames: ["Credit Agricole", "Crédit Agricole"]),
        FinancialInstitutionEntry(displayName: "BBVA", domain: "bbva.com", searchNames: ["BBVA"]),
        FinancialInstitutionEntry(displayName: "CaixaBank", domain: "caixabank.es", searchNames: ["CaixaBank", "La Caixa"]),
        FinancialInstitutionEntry(displayName: "Deutsche Bank", domain: "deutsche-bank.de", searchNames: ["Deutsche Bank"]),
        FinancialInstitutionEntry(displayName: "N26", domain: "n26.com", searchNames: ["N26"]),
        FinancialInstitutionEntry(displayName: "Wise", domain: "wise.com", searchNames: ["Wise", "TransferWise"]),
    ]

    static func domain(for name: String) -> String? {
        let normalized = MerchantLogoEngine.normalizeMerchantName(name)
        guard !normalized.isEmpty else { return nil }
        for entry in entries {
            if entry.searchNames.contains(where: { MerchantLogoEngine.normalizeMerchantName($0) == normalized }) {
                return entry.domain
            }
            if MerchantLogoEngine.normalizeMerchantName(entry.displayName) == normalized {
                return entry.domain
            }
        }
        return entries.first(where: { entry in
            entry.searchNames.contains { normalized.contains(MerchantLogoEngine.normalizeMerchantName($0)) }
                || normalized.contains(MerchantLogoEngine.normalizeMerchantName(entry.displayName))
        })?.domain
    }

    static func hasKnownInstitution(_ name: String) -> Bool {
        domain(for: name) != nil
    }
}
