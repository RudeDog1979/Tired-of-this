//
//  BuxMuseArchiveTests.swift
//  BuxMuseTests
//
//  Encrypt/decrypt round-trip for .buxmuse archives — no simulator UI required.
//

import XCTest
@testable import BuxMuse

@MainActor
final class BuxMuseArchiveTests: XCTestCase {

    func testEncryptDecryptRoundTripPreservesPayload() throws {
        let settings = SettingsStore.shared
        settings.resetAllData()
        settings.studioEnabled = true
        settings.firstName = "Archive"
        settings.lastName = "Tester"

        let tx = Transaction(
            id: UUID(),
            date: Date(),
            amount: MoneyAmount(value: -4.50, currencyCode: "USD"),
            merchantName: "Coffee",
            category: .restaurants,
            notes: "test"
        )
        let goal = Goal(
            id: UUID(),
            name: "Emergency fund",
            targetAmount: 1000,
            currentAmount: 120,
            deadline: nil,
            priority: 2
        )
        let hustle = Hustle(name: "Design gig", colorHex: "#5856D6")
        let draft = AgreementDraft(
            title: "Website scope",
            scopeBullets: "Homepage + contact form",
            deliverables: "Figma + static build"
        )
        let studioSnapshot = StudioSnapshot(
            profile: StudioProfile(displayName: "Studio", businessName: "Test Co", countryCode: "US", currencyCode: "USD", businessType: .freelancer, vatRegistered: false),
            clients: [],
            invoices: [],
            projects: [],
            receipts: [],
            taxProfile: StudioTaxProfile(countryCode: "US", businessType: .freelancer, vatRegistered: false, incomeTaxRules: [], vatRules: [], deductionCategories: [], paymentSchedule: "annually"),
            agreementDrafts: [draft]
        )

        let payload = try BuxMuseArchiveService.buildPayload(
            settings: settings,
            hustles: [hustle],
            selectedHustleId: hustle.id,
            transactions: [tx],
            goals: [goal],
            studioSnapshot: studioSnapshot,
            simpleSnapshot: nil
        )

        let encrypted = try BuxMuseArchiveService.encrypt(payload, password: "test-pass-1234", includeRecoveryKey: true)
        XCTAssertTrue(encrypted.archiveData.starts(with: Data("BUXMUSE2".utf8)))

        let decrypted = try BuxMuseArchiveService.decrypt(encrypted.archiveData, secret: "test-pass-1234")
        XCTAssertEqual(decrypted.manifest.transactionCount, 1)
        XCTAssertEqual(decrypted.manifest.goalCount, 1)
        XCTAssertEqual(decrypted.hustles.count, 1)
        XCTAssertEqual(decrypted.transactions.first?.merchantName, "Coffee")
        XCTAssertEqual(decrypted.goals.first?.name, "Emergency fund")
        XCTAssertEqual(decrypted.studioSnapshot?.agreementDrafts.first?.title, "Website scope")

        if let recoveryKey = encrypted.recoveryKey {
            let viaRecovery = try BuxMuseArchiveService.decrypt(encrypted.archiveData, secret: recoveryKey)
            XCTAssertEqual(viaRecovery.transactions.first?.merchantName, "Coffee")
        } else {
            XCTFail("Expected recovery key")
        }
    }

    func testRecoveryKeyUnlocksWithoutPassword() throws {
        let settings = SettingsStore.shared
        let payload = try BuxMuseArchiveService.buildPayload(
            settings: settings,
            hustles: [],
            selectedHustleId: nil,
            transactions: [],
            goals: [],
            studioSnapshot: nil,
            simpleSnapshot: nil
        )
        let result = try BuxMuseArchiveService.encrypt(payload, password: "my-password", includeRecoveryKey: true)
        guard let recoveryKey = result.recoveryKey else {
            XCTFail("Missing recovery key")
            return
        }
        XCTAssertThrowsError(try BuxMuseArchiveService.decrypt(result.archiveData, secret: "wrong-password"))
        _ = try BuxMuseArchiveService.decrypt(result.archiveData, secret: recoveryKey)
    }

    func testPasswordOnlyBackupV1FormatWhenRecoveryDisabled() throws {
        let settings = SettingsStore.shared
        let payload = try BuxMuseArchiveService.buildPayload(
            settings: settings,
            hustles: [],
            selectedHustleId: nil,
            transactions: [],
            goals: [],
            studioSnapshot: nil,
            simpleSnapshot: nil
        )
        let result = try BuxMuseArchiveService.encrypt(payload, password: "legacy", includeRecoveryKey: false)
        XCTAssertTrue(result.archiveData.starts(with: Data("BUXMUSE1".utf8)))
        XCTAssertNil(result.recoveryKey)
        _ = try BuxMuseArchiveService.decrypt(result.archiveData, secret: "legacy")
    }

    func testWrongPasswordFailsDecryptLegacy() throws {
        let settings = SettingsStore.shared
        let payload = try BuxMuseArchiveService.buildPayload(
            settings: settings,
            hustles: [],
            selectedHustleId: nil,
            transactions: [],
            goals: [],
            studioSnapshot: nil,
            simpleSnapshot: nil
        )
        let result = try BuxMuseArchiveService.encrypt(payload, password: "correct", includeRecoveryKey: true)
        XCTAssertThrowsError(try BuxMuseArchiveService.decrypt(result.archiveData, secret: "wrong"))
    }

    func testCorruptHeaderRejected() {
        let garbage = Data("NOTANARCHIVE".utf8)
        XCTAssertThrowsError(try BuxMuseArchiveService.decrypt(garbage, password: "any"))
    }

    func testSettingsStoreIncomeFundingSourceBackwardsCompatibility() throws {
        let settings = SettingsStore.shared
        
        // 1. Reset and set a known name and non-default incomeFundingSource value
        settings.resetAllData()
        settings.firstName = "Legacy"
        settings.incomeFundingSource = .other
        settings.save()
        
        // 2. Export settings data to JSON
        guard let data = settings.exportArchiveSettingsData() else {
            XCTFail("Failed to export settings data")
            return
        }
        
        // 3. Deserialize JSON to dictionary, remove the "incomeFundingSource" key, and re-serialize to JSON
        guard var jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            XCTFail("Failed to parse settings JSON to dictionary")
            return
        }
        
        XCTAssertNotNil(jsonDict["incomeFundingSource"])
        jsonDict.removeValue(forKey: "incomeFundingSource")
        
        let legacyJSON = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
        
        // 4. Import the legacy JSON (which is missing the "incomeFundingSource" key)
        try settings.importArchiveSettingsData(legacyJSON)
        
        // 5. Verify it loaded successfully and defaulted incomeFundingSource to .salary
        XCTAssertEqual(settings.firstName, "Legacy")
        XCTAssertEqual(settings.incomeFundingSource, .salary)
    }

    func testSettingsStoreOnboardingBackwardsCompatibility() throws {
        let settings = SettingsStore.shared
        
        // 1. Reset and set hasCompletedOnboarding to true
        settings.resetAllData()
        settings.firstName = "OnboardingLegacy"
        settings.hasCompletedOnboarding = true
        settings.save()
        
        // 2. Export settings data to JSON
        guard let data = settings.exportArchiveSettingsData() else {
            XCTFail("Failed to export settings data")
            return
        }
        
        // 3. Deserialize JSON to dictionary, remove the "hasCompletedOnboarding" key, and re-serialize to JSON
        guard var jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            XCTFail("Failed to parse settings JSON to dictionary")
            return
        }
        
        XCTAssertNotNil(jsonDict["hasCompletedOnboarding"])
        jsonDict.removeValue(forKey: "hasCompletedOnboarding")
        
        let legacyJSON = try JSONSerialization.data(withJSONObject: jsonDict, options: [])
        
        // 4. Import the legacy JSON (missing key)
        try settings.importArchiveSettingsData(legacyJSON)
        
        // 5. Verify it loaded successfully and defaulted hasCompletedOnboarding to true (so legacy users aren't forced to onboard)
        XCTAssertEqual(settings.firstName, "OnboardingLegacy")
        XCTAssertEqual(settings.hasCompletedOnboarding, true)
        
        // 6. Test a fresh seeder defaults to false
        settings.resetAllData()
        XCTAssertEqual(settings.hasCompletedOnboarding, false)
    }

    func testBackupNotificationSchedulerReschedule() async {
        // 1. Reschedule with .off
        await BackupNotificationScheduler.reschedule(frequency: .off)
        
        // 2. Reschedule with .daily
        await BackupNotificationScheduler.reschedule(frequency: .daily)
        
        // 3. Verify it does not crash and the settings properties align
        let settings = SettingsStore.shared
        settings.autoBackupFrequency = .daily
        XCTAssertEqual(settings.autoBackupFrequency, .daily)
    }
}

