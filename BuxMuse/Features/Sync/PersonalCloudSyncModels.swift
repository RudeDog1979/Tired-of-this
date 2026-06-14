//
//  PersonalCloudSyncModels.swift
//  BuxMuse
//
//  iCloud private-database payloads for cross-device personal sync.
//

import Foundation

struct PersonalExpensePayload: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var amountValue: Decimal
    var currencyCode: String
    var categoryId: UUID?
    var merchantId: UUID?
    var date: Date
    var notes: String?
    var isRecurring: Bool
    var isSubscriptionLike: Bool
    var categoryRaw: String
    var merchantName: String
    var hustleId: UUID?
    var paymentMethod: String?
    var isCategorySplit: Bool
    var splitLines: [ExpenseSplitLineRecord]
    var householdScope: HouseholdScope
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool

    init(from record: ExpenseRecord, isDeleted: Bool = false) {
        id = record.id
        name = record.name
        amountValue = record.amountValue
        currencyCode = record.currencyCode
        categoryId = record.categoryId
        merchantId = record.merchantId
        date = record.date
        notes = record.notes
        isRecurring = record.isRecurring
        isSubscriptionLike = record.isSubscriptionLike
        categoryRaw = record.categoryRaw
        merchantName = record.merchantName
        hustleId = record.hustleId
        paymentMethod = record.paymentMethod
        isCategorySplit = record.isCategorySplit
        splitLines = record.splitLines
        householdScope = record.householdScope
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        self.isDeleted = isDeleted
    }

    func toExpenseRecord() -> ExpenseRecord {
        ExpenseRecord(
            id: id,
            name: name,
            amountValue: amountValue,
            currencyCode: currencyCode,
            categoryId: categoryId,
            merchantId: merchantId,
            date: date,
            notes: notes,
            isRecurring: isRecurring,
            isSubscriptionLike: isSubscriptionLike,
            createdAt: createdAt,
            updatedAt: updatedAt,
            categoryRaw: categoryRaw,
            merchantName: merchantName,
            hustleId: hustleId,
            paymentMethod: paymentMethod,
            isCategorySplit: isCategorySplit,
            splitLines: splitLines,
            householdScope: householdScope
        )
    }
}

struct PersonalSettingsPayload: Codable, Equatable {
    var settingsData: Data
    var updatedAt: Date
}

struct PersonalStudioPayload: Codable, Equatable {
    var snapshot: StudioSnapshot
    var updatedAt: Date
}

struct PersonalSimpleStudioPayload: Codable, Equatable {
    var snapshot: SimpleStudioSnapshot
    var updatedAt: Date
}

struct PersonalHustlesPayload: Codable, Equatable {
    var hustles: [Hustle]
    var selectedHustleId: UUID?
    var updatedAt: Date
}

enum PersonalSyncStatus: Equatable {
    case disabled
    case noAccount
    case idle
    case syncing
    case lastSynced(Date)
    case error(String)
}

enum PersonalCloudSyncError: LocalizedError {
    case noAccount
    case disabled

    var errorDescription: String? {
        switch self {
        case .noAccount: return "Sign in to iCloud with Apple to sync across your iPhone and iPad."
        case .disabled: return "iCloud sync is turned off."
        }
    }
}
