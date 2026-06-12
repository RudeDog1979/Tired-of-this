//
//  InvoicePartyModels.swift
//  BuxMuse
//
//  Structured issuer/recipient identity for invoices — additive to legacy name/address fields.
//

import Foundation

// MARK: - Bank account type (invoice payment display)

public enum BankAccountType: String, Codable, CaseIterable, Identifiable, Sendable {
    case iban
    case uk
    case us
    case canada
    case australia
    case generic

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .iban: return "IBAN (International)"
        case .uk: return "UK (Sort code + Account)"
        case .us: return "US (Routing + Account)"
        case .canada: return "Canada (Transit + Institution + Account)"
        case .australia: return "Australia (BSB + Account)"
        case .generic: return "Account number only"
        }
    }
}

// MARK: - Party details

public struct InvoicePartyDetails: Codable, Equatable, Hashable, Sendable {
    public var isOrganization: Bool
    public var organizationName: String
    public var givenNames: String
    public var familyNames: String
    public var additionalNames: String
    public var email: String
    public var phone: String
    public var addressLine1: String
    public var addressLine2: String
    public var countryCode: String
    public var subdivision: String
    public var postalCode: String
    public var businessRegistrationNumber: String
    public var taxRegistrationNumber: String
    public var tradeName: String

    public init(
        isOrganization: Bool = false,
        organizationName: String = "",
        givenNames: String = "",
        familyNames: String = "",
        additionalNames: String = "",
        email: String = "",
        phone: String = "",
        addressLine1: String = "",
        addressLine2: String = "",
        countryCode: String = "",
        subdivision: String = "",
        postalCode: String = "",
        businessRegistrationNumber: String = "",
        taxRegistrationNumber: String = "",
        tradeName: String = ""
    ) {
        self.isOrganization = isOrganization
        self.organizationName = organizationName
        self.givenNames = givenNames
        self.familyNames = familyNames
        self.additionalNames = additionalNames
        self.email = email
        self.phone = phone
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.countryCode = countryCode
        self.subdivision = subdivision
        self.postalCode = postalCode
        self.businessRegistrationNumber = businessRegistrationNumber
        self.taxRegistrationNumber = taxRegistrationNumber
        self.tradeName = tradeName
    }

    public var primaryTitle: String {
        if isOrganization {
            let org = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !org.isEmpty { return org }
        }
        return personFullName
    }

    public var personFullName: String {
        let parts = [givenNames, additionalNames, familyNames]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    public var contactSubtitle: String? {
        guard isOrganization else { return nil }
        let person = personFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return person.isEmpty ? nil : person
    }

    public var isEmpty: Bool {
        primaryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && addressLine1.isEmpty
            && email.isEmpty
            && phone.isEmpty
    }

    /// Lines for CRM detail cards (address + contact).
    public var formattedContactLines: [String] {
        var lines = InvoicePartyEngine.formattedAddressLines(for: self, includeCountry: true)
        if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.append(email) }
        if !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { lines.append(phone) }
        return lines
    }
}

// MARK: - Render displays (brain-built, UI/PDF consume only)

public struct InvoicePartyBlockDisplay: Equatable, Sendable {
    public var heading: String
    public var title: String
    public var subtitle: String?
    public var lines: [String]

    public static let empty = InvoicePartyBlockDisplay(heading: "", title: "—", subtitle: nil, lines: [])

    public init(heading: String, title: String, subtitle: String?, lines: [String]) {
        self.heading = heading
        self.title = title
        self.subtitle = subtitle
        self.lines = lines
    }
}

public struct InvoiceLegalFooterDisplay: Equatable, Sendable {
    public var lines: [String]
    public var isVisible: Bool

    public static let hidden = InvoiceLegalFooterDisplay(lines: [], isVisible: false)

    public init(lines: [String], isVisible: Bool) {
        self.lines = lines
        self.isVisible = isVisible
    }
}

public struct InvoicePaymentLineDisplay: Equatable, Sendable {
    public var label: String
    public var value: String
}

// MARK: - Profile / client resolution

public extension StudioProfile {
    func resolvedPartyDetails() -> InvoicePartyDetails {
        if var party = partyDetails {
            party = Self.hydrateLegacy(into: party, profile: self)
            return party
        }
        return Self.migratedPartyDetails(from: self)
    }

    mutating func applyPartyDetails(_ details: InvoicePartyDetails) {
        partyDetails = details
        syncLegacyFields(from: details)
    }

    mutating func syncLegacyFields(from details: InvoicePartyDetails) {
        if details.isOrganization {
            let org = details.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !org.isEmpty { businessName = org }
            let person = details.personFullName
            if !person.isEmpty { displayName = person }
        } else {
            let person = details.personFullName
            if !person.isEmpty {
                displayName = person
                if businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    businessName = person
                }
            }
        }
        if !details.countryCode.isEmpty { countryCode = details.countryCode }
    }

    private static func hydrateLegacy(into party: InvoicePartyDetails, profile: StudioProfile) -> InvoicePartyDetails {
        var p = party
        if p.primaryTitle.isEmpty {
            if !profile.businessName.isEmpty {
                p.isOrganization = true
                p.organizationName = profile.businessName
            } else if !profile.displayName.isEmpty {
                p.givenNames = profile.displayName
            }
        }
        if p.addressLine1.isEmpty, let raw = profile.businessAddress, !raw.isEmpty {
            p.addressLine1 = raw
        }
        if p.countryCode.isEmpty { p.countryCode = profile.countryCode }
        return p
    }

    static func migratedPartyDetails(from profile: StudioProfile) -> InvoicePartyDetails {
        var party = InvoicePartyDetails(countryCode: profile.countryCode)
        if !profile.businessName.isEmpty {
            party.isOrganization = true
            party.organizationName = profile.businessName
            if !profile.displayName.isEmpty, profile.displayName != profile.businessName {
                let parts = profile.displayName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                party.givenNames = parts.first.map(String.init) ?? profile.displayName
                if parts.count > 1 { party.familyNames = String(parts[1]) }
            }
        } else if !profile.displayName.isEmpty {
            let parts = profile.displayName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            party.givenNames = parts.first.map(String.init) ?? profile.displayName
            if parts.count > 1 { party.familyNames = String(parts[1]) }
        }
        if let raw = profile.businessAddress, !raw.isEmpty {
            party.addressLine1 = raw
        }
        return party
    }
}

public extension StudioClient {
    func resolvedPartyDetails() -> InvoicePartyDetails {
        if var party = partyDetails {
            party = Self.hydrateLegacy(into: party, client: self)
            return party
        }
        return Self.migratedPartyDetails(from: self)
    }

    mutating func applyPartyDetails(_ details: InvoicePartyDetails) {
        partyDetails = details
        syncLegacyFields(from: details)
    }

    mutating func syncLegacyFields(from details: InvoicePartyDetails) {
        let title = details.primaryTitle
        if !title.isEmpty { name = title }
        if !details.email.isEmpty { email = details.email }
        if !details.phone.isEmpty { phone = details.phone }
    }

    private static func hydrateLegacy(into party: InvoicePartyDetails, client: StudioClient) -> InvoicePartyDetails {
        var p = party
        if p.primaryTitle.isEmpty, !client.name.isEmpty {
            if client.name.contains(" Ltd") || client.name.contains(" LLC") || client.name.contains(" Inc") {
                p.isOrganization = true
                p.organizationName = client.name
            } else {
                let parts = client.name.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                p.givenNames = parts.first.map(String.init) ?? client.name
                if parts.count > 1 { p.familyNames = String(parts[1]) }
            }
        }
        if p.addressLine1.isEmpty, !client.address.isEmpty { p.addressLine1 = client.address }
        if p.email.isEmpty { p.email = client.email }
        if p.phone.isEmpty { p.phone = client.phone }
        return p
    }

    static func migratedPartyDetails(from client: StudioClient) -> InvoicePartyDetails {
        var party = InvoicePartyDetails(email: client.email, phone: client.phone)
        if !client.name.isEmpty {
            let parts = client.name.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            party.givenNames = parts.first.map(String.init) ?? client.name
            if parts.count > 1 { party.familyNames = String(parts[1]) }
        }
        if !client.address.isEmpty { party.addressLine1 = client.address }
        return party
    }
}
