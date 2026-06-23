//
//  WalletCategoryIntelligenceTests.swift
//  BuxMuseTests
//
//  Worldwide wallet categorization fixtures — no FinanceKit required.
//

import XCTest
@testable import BuxMuse

final class WalletCategoryIntelligenceTests: XCTestCase {
    private struct Fixture {
        let rawLabel: String
        let displayName: String
        let amountValue: Decimal
        let mccCode: Int?
        let userMemory: TransactionCategory?
        let expected: TransactionCategory
        let file: StaticString
        let line: UInt

        init(
            _ rawLabel: String,
            displayName: String? = nil,
            amountValue: Decimal = -12.34,
            mccCode: Int? = nil,
            userMemory: TransactionCategory? = nil,
            expected: TransactionCategory,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            self.rawLabel = rawLabel
            self.displayName = displayName ?? rawLabel
            self.amountValue = amountValue
            self.mccCode = mccCode
            self.userMemory = userMemory
            self.expected = expected
            self.file = file
            self.line = line
        }
    }

    private func classify(_ fixture: Fixture) -> WalletCategoryDecision {
        let input = WalletCategoryInput(
            rawLabel: fixture.rawLabel,
            displayName: fixture.displayName,
            isCredit: fixture.amountValue > 0,
            transactionKind: inferredKind(from: fixture.rawLabel),
            mccCode: fixture.mccCode,
            userMemoryCategory: fixture.userMemory
        )
        return WalletCategoryIntelligence.classify(input)
    }

    private func inferredKind(from rawLabel: String) -> WalletTransactionKind {
        WalletCategoryIntelligence.input(
            rawLabel: rawLabel,
            displayName: rawLabel,
            amountValue: -1
        ).transactionKind
    }

    private func assertFixture(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) {
        let decision = classify(fixture)
        XCTAssertEqual(
            decision.category,
            fixture.expected,
            "Expected \(fixture.expected) for '\(fixture.rawLabel)' but got \(decision.category) via \(decision.source)",
            file: file,
            line: line
        )
        XCTAssertNotEqual(
            decision.category,
            .other,
            "Fixture '\(fixture.rawLabel)' must not land in Other",
            file: file,
            line: line
        )
    }

    // MARK: - Worldwide purchase fixtures

    func testWorldwidePurchaseFixtures() {
        let fixtures: [Fixture] = [
            // UK
            Fixture("SAINSBURY'S LONDON", expected: .groceries),
            Fixture("TESCO STORES 3456", expected: .groceries),
            Fixture("MARKS & SPENCER", expected: .groceries),
            Fixture("PRET A MANGER", expected: .restaurants),
            Fixture("DELIVEROO", expected: .restaurants),
            // US
            Fixture("WHOLE FOODS MARKET", expected: .groceries),
            Fixture("TRADER JOE'S #123", expected: .groceries),
            Fixture("STARBUCKS STORE 9912", expected: .restaurants),
            Fixture("TARGET T-1234", expected: .shopping),
            // EU / LATAM
            Fixture("CARREFOUR MARKET", expected: .groceries),
            Fixture("MERCADONA VALENCIA", expected: .groceries),
            Fixture("LIDL SAGUNTO", expected: .groceries),
            Fixture("ZARA HOME", expected: .shopping),
            // Global processors
            Fixture("PAYPAL *AMAZON", expected: .shopping),
            Fixture("PAYPAL *NETFLIX", expected: .subscriptions),
            Fixture("SQ *BLUE BOTTLE COFFEE", expected: .restaurants),
            Fixture("UBER *TRIP", expected: .transport),
            Fixture("UBER *EATS", expected: .restaurants),
            // Transport & fuel
            Fixture("SHELL GARAGE M4", expected: .transport),
            Fixture("TFL TRAVEL CHARGE", expected: .transport),
            // Subscriptions
            Fixture("SPOTIFY AB", expected: .subscriptions),
            Fixture("APPLE.COM/BILL", expected: .subscriptions),
            // Health
            Fixture("BOOTS PHARMACY", expected: .health),
            // Travel
            Fixture("RYANAIR BOOKING", expected: .travel),
            Fixture("BOOKING.COM HOTEL", expected: .travel),
            Fixture("SUPERMERCADO LA ESQUINA", expected: .groceries),
            Fixture("NTUC FAIRPRICE", expected: .groceries),
            Fixture("DMART", expected: .groceries),
        ]
        for fixture in fixtures {
            assertFixture(fixture)
        }
    }

    // MARK: - Bank movement (spend, not excluded)

    func testBankTransfersAndATMClassifyAsPersonalOrTargeted() {
        let personalFixtures: [Fixture] = [
            Fixture("HSBC TRANSFER", expected: .personal),
            Fixture("CHASE ACH P2P", expected: .personal),
            Fixture("SEPA ÜBERWEISUNG", expected: .personal),
            Fixture("FASTER PAYMENT JOHN SMITH", expected: .personal),
            Fixture("MONZO TRANSFER", expected: .personal),
            Fixture("ATM WITHDRAWAL", expected: .personal),
            Fixture("CASH WITHDRAWAL NATWEST", expected: .personal),
            Fixture("REVOLUT TRANSFER", expected: .personal),
        ]
        for fixture in personalFixtures {
            assertFixture(fixture)
        }

        let housing = classify(Fixture("STANDING ORDER RENT PAYMENT", expected: .housing))
        XCTAssertEqual(housing.category, .housing)

        let utilities = classify(Fixture("DIRECT DEBIT BRITISH GAS", expected: .utilities))
        XCTAssertEqual(utilities.category, .utilities)
    }

    func testFinancialInstitutionsAreNeverRetail() {
        let banks: [Fixture] = [
            Fixture("ZOPA BANK", expected: .personal),
            Fixture("ZOPA BANK", mccCode: 5411, expected: .personal),
            Fixture("ATOM BANK", expected: .personal),
            Fixture("CHIP APP", expected: .personal),
            Fixture("MARCUS BY GOLDMAN SACHS", expected: .personal),
            Fixture("METRO BANK PAYMENT", expected: .personal),
            Fixture("STARLING BANK", expected: .personal),
            Fixture("NATIONWIDE BUILDING SOCIETY", expected: .personal),
            Fixture("BANCO SANTANDER", expected: .personal),
            Fixture("DEUTSCHE BANK AG", expected: .personal),
        ]
        for fixture in banks {
            let decision = classify(fixture)
            XCTAssertEqual(
                decision.category,
                fixture.expected,
                "'\(fixture.rawLabel)' must not be retail; got \(decision.category) via \(decision.source)"
            )
            XCTAssertNotEqual(decision.category, .groceries)
            XCTAssertNotEqual(decision.category, .shopping)
        }
    }

    func testShouldRefreshWhenClassifierCategoryChanged() {
        let classification = WalletTransactionClassification(
            rawLabel: "ZOPA BANK",
            displayName: "Zopa Bank",
            resolution: WalletStatementResolution(
                canonicalName: "Zopa Bank",
                domain: nil,
                matchedMerchantId: nil,
                confidence: .high,
                rawLabel: "ZOPA BANK",
                matchSource: .tokenHeuristic
            ),
            decision: WalletCategoryDecision(category: .personal, confidence: .high, source: .paymentProcessor),
            userMemoryCategory: nil
        )
        let wrongGroceries = WalletCategoryRefreshSnapshot(
            categoryRaw: TransactionCategory.groceries.rawValue,
            walletCategoryUserConfirmed: false,
            walletCategoryConfidence: "high",
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: "ZOPA BANK")
        )
        XCTAssertTrue(
            WalletTransactionClassifier.shouldRefreshCategory(
                existing: wrongGroceries,
                classification: classification
            )
        )
    }

    // MARK: - MCC

    func testMCCGroceriesAndRestaurants() {
        let groceries = classify(Fixture("POS PURCHASE", mccCode: 5411, expected: .groceries))
        XCTAssertEqual(groceries.category, .groceries)
        XCTAssertEqual(groceries.source, .merchantCategoryCode)

        let restaurants = classify(Fixture("CARD PAYMENT", mccCode: 5812, expected: .restaurants))
        XCTAssertEqual(restaurants.category, .restaurants)
    }

    // MARK: - User memory (tier 2)

    func testUserMemoryOverridesClassifier() {
        let decision = classify(
            Fixture(
                "UNKNOWN MERCHANT XYZ",
                userMemory: .groceries,
                expected: .groceries
            )
        )
        XCTAssertEqual(decision.category, .groceries)
        XCTAssertEqual(decision.source, .userMemory)
    }

    // MARK: - Income / credit

    func testCreditTransactionsClassifyAsIncome() {
        let input = WalletCategoryInput(
            rawLabel: "EMPLOYER PAYROLL",
            displayName: "Employer Payroll",
            isCredit: true,
            transactionKind: .purchase,
            mccCode: nil
        )
        let decision = WalletCategoryIntelligence.classify(input)
        XCTAssertEqual(decision.category, .income)
    }

    // MARK: - True unknown → Other only as fallback

    func testTrulyUnknownMerchantFallsBackToOther() {
        let decision = classify(
            Fixture("ZZZZ UNKNOWN TOKEN QXJ99", expected: .other)
        )
        XCTAssertEqual(decision.category, .other)
        XCTAssertEqual(decision.source, .fallback)
    }

    // MARK: - Wallet import notes (language-neutral storage)

    func testWalletImportNoteRoundTrip() {
        let stored = WalletStatementIntelligence.walletImportNotes(rawLabel: "SAINSBURY'S")
        XCTAssertEqual(stored, "wallet_import:SAINSBURY'S")
        XCTAssertEqual(WalletStatementIntelligence.rawLabelFromStoredNote(stored), "SAINSBURY'S")
        XCTAssertTrue(WalletStatementIntelligence.isWalletImportNote(stored))
    }

    func testLegacyEnglishWalletImportNoteStillParses() {
        let legacy = "Imported from Apple Wallet · WHOLE FOODS"
        XCTAssertTrue(WalletStatementIntelligence.isWalletImportNote(legacy))
        XCTAssertEqual(WalletStatementIntelligence.rawLabelFromStoredNote(legacy), "WHOLE FOODS")
    }

    func testLocalizedWalletImportNoteUsesCatalog() {
        let stored = WalletStatementIntelligence.walletImportNotes(rawLabel: "TESCO")
        let english = WalletStatementIntelligence.localizedWalletImportNote(
            stored: stored,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(english, "Imported from Apple Wallet · TESCO")

        let spanish = WalletStatementIntelligence.localizedWalletImportNote(
            stored: stored,
            locale: Locale(identifier: "es-419")
        )
        XCTAssertEqual(spanish, "Importado desde Apple Wallet · TESCO")
    }

    // MARK: - Refresh rules

    func testShouldRefreshCategoryForOtherAndUserMemory() {
        let classification = WalletTransactionClassification(
            rawLabel: "SAINSBURY'S",
            displayName: "Sainsbury's",
            resolution: WalletStatementResolution(
                canonicalName: "Sainsbury's",
                domain: nil,
                matchedMerchantId: nil,
                confidence: .high,
                rawLabel: "SAINSBURY'S",
                matchSource: .tokenHeuristic
            ),
            decision: WalletCategoryDecision(category: .groceries, confidence: .high, source: .brandLexicon),
            userMemoryCategory: nil
        )

        let otherSnapshot = WalletCategoryRefreshSnapshot(
            categoryRaw: TransactionCategory.other.rawValue,
            walletCategoryUserConfirmed: false,
            walletCategoryConfidence: "low",
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: "SAINSBURY'S")
        )
        XCTAssertTrue(
            WalletTransactionClassifier.shouldRefreshCategory(
                existing: otherSnapshot,
                classification: classification
            )
        )

        let confirmedSnapshot = WalletCategoryRefreshSnapshot(
            categoryRaw: TransactionCategory.groceries.rawValue,
            walletCategoryUserConfirmed: true,
            walletCategoryConfidence: "high",
            notes: WalletStatementIntelligence.walletImportNotes(rawLabel: "SAINSBURY'S")
        )
        XCTAssertFalse(
            WalletTransactionClassifier.shouldRefreshCategory(
                existing: confirmedSnapshot,
                classification: classification
            )
        )
    }

    // MARK: - Merchant memory keys

    func testMerchantMemoryNormalizedKeys() {
        let keys = WalletMerchantCategoryMemory.normalizedKeys(
            merchantName: "Sainsbury's",
            walletRawLabel: "SAINSBURY'S LONDON"
        )
        XCTAssertTrue(keys.contains(MerchantLogoEngine.normalizeMerchantName("Sainsbury's")))
        XCTAssertTrue(keys.contains(MerchantLogoEngine.normalizeMerchantName("SAINSBURY'S LONDON")))
    }
}
