//
//  HouseholdModels.swift
//  BuxMuse
//  Features/Household/
//
//  iCloud household scope, shared expense payloads, and sync status.
//

import Foundation

enum HouseholdScope: String, Codable, CaseIterable, Identifiable {
    case personal
    case shared

    var id: String { rawValue }

    var catalogKey: String {
        switch self {
        case .personal: return "Personal"
        case .shared: return "Shared household"
        }
    }
}

struct SharedExpensePayload: Codable, Equatable, Identifiable {
    let id: UUID
    var merchantName: String
    var amountValue: Decimal
    var currencyCode: String
    var categoryId: UUID?
    var categoryRaw: String
    var date: Date
    var notes: String?
    var paymentMethod: String?
    var splitLines: [ExpenseSplitLineRecord]
    var householdScope: HouseholdScope
    var updatedAt: Date
    var authorDeviceName: String?

    init(from record: ExpenseRecord, authorDeviceName: String? = nil) {
        id = record.id
        merchantName = record.merchantName
        amountValue = record.amountValue
        currencyCode = record.currencyCode
        categoryId = record.categoryId
        categoryRaw = record.categoryRaw
        date = record.date
        notes = record.notes
        paymentMethod = record.paymentMethod
        splitLines = record.splitLines
        householdScope = record.householdScope
        updatedAt = record.updatedAt
        self.authorDeviceName = authorDeviceName
    }

    func toExpenseRecord() -> ExpenseRecord {
        ExpenseRecord(
            id: id,
            name: merchantName,
            amountValue: amountValue,
            currencyCode: currencyCode,
            categoryId: categoryId,
            date: date,
            notes: notes,
            updatedAt: updatedAt,
            categoryRaw: categoryRaw,
            merchantName: merchantName,
            paymentMethod: paymentMethod,
            isCategorySplit: !splitLines.isEmpty,
            splitLines: splitLines,
            householdScope: householdScope
        )
    }
}

struct SharedEnvelopeProfilePayload: Codable, Equatable {
    var profileId: UUID?
    var profileJSON: Data?
    var updatedAt: Date

    init(profileId: UUID?, profileJSON: Data?, updatedAt: Date = Date()) {
        self.profileId = profileId
        self.profileJSON = profileJSON
        self.updatedAt = updatedAt
    }
}

enum HouseholdSyncStatus: Equatable {
    case notConfigured
    case noAccount
    case idle
    case syncing
    case lastSynced(Date)
    case error(String)

    var isActiveHousehold: Bool {
        switch self {
        case .idle, .syncing, .lastSynced:
            return true
        default:
            return false
        }
    }
}

enum HouseholdCloudRecordType {
    static let household = "BuxHousehold"
    static let sharedExpense = "BuxSharedExpense"
    static let envelopeProfile = "BuxHouseholdEnvelope"
}

enum HouseholdCloudField {
    static let displayName = "displayName"
    static let payloadJSON = "payloadJSON"
    static let expenseId = "expenseId"
    static let updatedAt = "updatedAt"
    static let profileId = "profileId"
    static let profileJSON = "profileJSON"
}
