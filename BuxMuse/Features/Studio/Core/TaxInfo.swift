//
//  TaxInfo.swift
//  BuxMuse
//
//  Country tax reference model — matches buxmuse_tax.json country objects exactly.
//

import Foundation

public struct TaxInfo: Codable, Equatable, Identifiable, Hashable {
    public var id: String { isoCode }

    public let name: String
    public let isoCode: String
    public let currency: String?
    public let region: String?
    public let vat: String
    public let income_tax: String
    public let self_employed_tax: String
    public let notes: String
    public let lastVerified: String

    public var selfEmployedSummary: String {
        "\(income_tax)\n\n\(self_employed_tax)\n\n\(notes)"
    }

    public init(
        name: String,
        isoCode: String,
        currency: String?,
        region: String?,
        vat: String,
        income_tax: String,
        self_employed_tax: String,
        notes: String,
        lastVerified: String
    ) {
        self.name = name
        self.isoCode = isoCode
        self.currency = currency
        self.region = region
        self.vat = vat
        self.income_tax = income_tax
        self.self_employed_tax = self_employed_tax
        self.notes = notes
        self.lastVerified = lastVerified
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isoCode = try container.decode(String.self, forKey: .isoCode)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        region = try container.decodeIfPresent(String.self, forKey: .region)
        vat = try container.decode(String.self, forKey: .vat)
        income_tax = try container.decode(String.self, forKey: .income_tax)
        self_employed_tax = try container.decodeIfPresent(String.self, forKey: .self_employed_tax) ?? ""
        notes = try container.decode(String.self, forKey: .notes)
        lastVerified = try container.decode(String.self, forKey: .lastVerified)
    }
}

struct TaxDatabasePayload: Codable {
    let version: Int
    let updatedAt: String
    let countries: [String: TaxInfo]
}
