//
//  PersonalCloudSyncEngine.swift
//  BuxMuse
//
//  Private CloudKit sync — expenses, debts, goals, settings across your Apple devices.
//

import CloudKit
import Combine
import Foundation

private enum PersonalCloudSyncMetadata {
    private static let defaults = UserDefaults.standard
    private static let lastSyncedKey = "buxmuse.personalCloud.lastSyncedAt"
    private static let initialUploadKey = "buxmuse.personalCloud.initialUploadCompleted"
    private static let settingsRevisionKey = "buxmuse.personalCloud.settingsRevision"
    private static let studioRevisionKey = "buxmuse.personalCloud.studioRevision"
    private static let simpleStudioRevisionKey = "buxmuse.personalCloud.simpleStudioRevision"
    private static let hustlesRevisionKey = "buxmuse.personalCloud.hustlesRevision"
    private static let zoneChangeTokenKey = "buxmuse.personalCloud.zoneChangeToken"
    private static let enableDisclaimerAcceptedKey = "buxmuse.personalCloud.enableDisclaimerAccepted"

    static var enableDisclaimerAccepted: Bool {
        get { defaults.bool(forKey: enableDisclaimerAcceptedKey) }
        set { defaults.set(newValue, forKey: enableDisclaimerAcceptedKey) }
    }

    static var zoneChangeToken: CKServerChangeToken? {
        get {
            guard let data = defaults.data(forKey: zoneChangeTokenKey) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        set {
            if let newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: zoneChangeTokenKey)
            } else {
                defaults.removeObject(forKey: zoneChangeTokenKey)
            }
        }
    }

    static var lastSyncedAt: Date? {
        get { defaults.object(forKey: lastSyncedKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: lastSyncedKey)
            } else {
                defaults.removeObject(forKey: lastSyncedKey)
            }
        }
    }

    static var initialUploadCompleted: Bool {
        get { defaults.bool(forKey: initialUploadKey) }
        set { defaults.set(newValue, forKey: initialUploadKey) }
    }

    static var settingsRevision: Date? {
        get { defaults.object(forKey: settingsRevisionKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: settingsRevisionKey)
            } else {
                defaults.removeObject(forKey: settingsRevisionKey)
            }
        }
    }

    static var studioRevision: Date? {
        get { defaults.object(forKey: studioRevisionKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: studioRevisionKey)
            } else {
                defaults.removeObject(forKey: studioRevisionKey)
            }
        }
    }

    static var simpleStudioRevision: Date? {
        get { defaults.object(forKey: simpleStudioRevisionKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: simpleStudioRevisionKey)
            } else {
                defaults.removeObject(forKey: simpleStudioRevisionKey)
            }
        }
    }

    static var hustlesRevision: Date? {
        get { defaults.object(forKey: hustlesRevisionKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: hustlesRevisionKey)
            } else {
                defaults.removeObject(forKey: hustlesRevisionKey)
            }
        }
    }
}

@MainActor
final class PersonalCloudSyncEngine: ObservableObject {
    static let shared = PersonalCloudSyncEngine()

    static let containerIdentifier = HouseholdSyncEngine.containerIdentifier
    private static let zoneName = "BuxPersonalSyncZone"
    private static let zoneSubscriptionID = "buxmuse-personal-sync-zone"
    private static let foregroundPullInterval: TimeInterval = 45

    @Published private(set) var syncStatus: PersonalSyncStatus = .disabled
    @Published private(set) var pendingConflictCount: Int = 0

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var personalZoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: Self.zoneName) }
    private var brain: BuxMuseBrain?
    private var debtEngine: DebtEngine?
    private var goalsEngine: GoalsEngine?
    private var settingsPushWork: DispatchWorkItem?
    private var studioPushWork: DispatchWorkItem?
    private var simpleStudioPushWork: DispatchWorkItem?
    private var hustlesPushWork: DispatchWorkItem?
    private var foregroundPullTimer: Timer?
    private var isPullInFlight = false
    private(set) var isApplyingRemote = false

    private var settingsStore: SettingsStore { SettingsStore.shared }

    private init() {
        container = CKContainer(identifier: Self.containerIdentifier)
        privateDatabase = container.privateCloudDatabase
        refreshEnabledState()
    }

    var isEnabled: Bool { settingsStore.personalCloudSyncEnabled }

    func attach(brain: BuxMuseBrain, debtEngine: DebtEngine, goalsEngine: GoalsEngine) {
        self.brain = brain
        self.debtEngine = debtEngine
        self.goalsEngine = goalsEngine
        Task { await bootstrapIfNeeded() }
    }

    deinit {
        foregroundPullTimer?.invalidate()
    }

    func refreshEnabledState() {
        syncStatus = isEnabled ? .idle : .disabled
    }

    func setEnabled(_ enabled: Bool) async {
        settingsStore.personalCloudSyncEnabled = enabled
        settingsStore.save(notifyCloudSync: false)
        refreshEnabledState()
        guard enabled else {
            stopForegroundPullTimer()
            return
        }
        guard await ensureAccountAvailable() else { return }
        do {
            try await ensurePersonalZoneExists()
            await ensurePersonalRecordTypesExist()
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "iCloud"))
            return
        }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        await pullRemoteChangesIfIdle()
        if !PersonalCloudSyncMetadata.initialUploadCompleted {
            await performInitialUpload()
            PersonalCloudSyncMetadata.initialUploadCompleted = true
        } else {
            await reconcileInitialUploadIfNeeded()
        }
        await reconcileMasterDataIfNeeded()
        await ensureZoneSubscription()
        startForegroundPullTimer()
    }

    func syncNow() async {
        guard isEnabled else { return }
        guard await ensureAccountAvailable() else { return }
        do {
            try await ensurePersonalZoneExists()
            await ensurePersonalRecordTypesExist()
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "iCloud"))
            return
        }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        await pullRemoteChangesIfIdle()
        await reconcileMasterDataIfNeeded()
    }

    @discardableResult
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async -> Bool {
        guard isEnabled else { return false }
        let payload = userInfo as? [String: NSObject] ?? [:]
        guard CKNotification(fromRemoteNotificationDictionary: payload) != nil else { return false }
        await pullRemoteChangesIfIdle()
        return true
    }

    // MARK: - Push hooks

    func pushExpenseIfNeeded(_ record: ExpenseRecord) {
        guard isEnabled, !isApplyingRemote else { return }
        Task { await pushExpense(record) }
    }

    func pushDeletedExpense(id: UUID, currencyCode: String = "USD") {
        guard isEnabled, !isApplyingRemote else { return }
        Task { await pushExpenseDeletion(id: id, currencyCode: currencyCode) }
    }

    func pushDebtsIfNeeded(_ debts: [Debt]) {
        guard isEnabled, !isApplyingRemote else { return }
        Task { await pushDebts(debts) }
    }

    func pushGoalsIfNeeded(_ goals: [Goal]) {
        guard isEnabled, !isApplyingRemote else { return }
        Task { await pushGoals(goals) }
    }

    func scheduleSettingsPush() {
        guard isEnabled, !isApplyingRemote else { return }
        settingsPushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.pushSettings()
            }
        }
        settingsPushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func scheduleStudioPush() {
        guard isEnabled, !isApplyingRemote else { return }
        studioPushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.pushStudio()
            }
        }
        studioPushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func scheduleSimpleStudioPush() {
        guard isEnabled, !isApplyingRemote else { return }
        simpleStudioPushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.pushSimpleStudio()
            }
        }
        simpleStudioPushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func scheduleHustlesPush() {
        guard isEnabled, !isApplyingRemote else { return }
        hustlesPushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.pushHustles()
            }
        }
        hustlesPushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    // MARK: - Account

    @discardableResult
    private func ensureAccountAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                if isEnabled { syncStatus = .idle }
                return true
            case .noAccount:
                syncStatus = .noAccount
            case .restricted, .temporarilyUnavailable:
                syncStatus = .error("iCloud is temporarily unavailable.")
            case .couldNotDetermine:
                syncStatus = .error("Could not verify iCloud account.")
            @unknown default:
                syncStatus = .error("Unknown iCloud status.")
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
        return false
    }

    private func bootstrapIfNeeded() async {
        refreshEnabledState()
        guard isEnabled else { return }
        guard await ensureAccountAvailable() else { return }
        do {
            try await ensurePersonalZoneExists()
            await ensurePersonalRecordTypesExist()
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "iCloud"))
            return
        }
        await pullRemoteChangesIfIdle()
        await reconcileMasterDataIfNeeded()
        await ensureZoneSubscription()
        startForegroundPullTimer()
    }

    private func pullRemoteChangesIfIdle() async {
        guard isEnabled, !isPullInFlight else { return }
        isPullInFlight = true
        defer { isPullInFlight = false }
        await pullRemoteChanges()
    }

    private func startForegroundPullTimer() {
        guard isEnabled else { return }
        foregroundPullTimer?.invalidate()
        foregroundPullTimer = Timer.scheduledTimer(withTimeInterval: Self.foregroundPullInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pullRemoteChangesIfIdle()
            }
        }
    }

    private func stopForegroundPullTimer() {
        foregroundPullTimer?.invalidate()
        foregroundPullTimer = nil
    }

    private func ensureZoneSubscription() async {
        guard isEnabled, await ensureAccountAvailable() else { return }
        do {
            try await ensurePersonalZoneExists()
            let subscription = CKRecordZoneSubscription(
                zoneID: personalZoneID,
                subscriptionID: Self.zoneSubscriptionID
            )
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            _ = try await privateDatabase.modifySubscriptions(saving: [subscription], deleting: [])
        } catch {
            // Subscription may already exist; foreground polling still keeps devices in sync.
        }
    }

    private func makeRecordID(recordName: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordName, zoneID: personalZoneID)
    }

    private func reconcileInitialUploadIfNeeded() async {
        guard let brain else { return }
        let localExpenses = (try? brain.fetchAllExpenseRecords()) ?? []
        guard !localExpenses.isEmpty else { return }
        do {
            let remote = try await fetchRecordsFromPersonalZone()
            let syncedRecords = remote.filter { !$0.recordID.recordName.contains("bootstrap") }
            guard syncedRecords.isEmpty else { return }
            PersonalCloudSyncMetadata.initialUploadCompleted = false
            PersonalCloudSyncMetadata.zoneChangeToken = nil
            await performInitialUpload()
        } catch {
            // Pull will surface errors if needed.
        }
    }

    // MARK: - Initial upload

    private func performInitialUpload() async {
        guard let brain else { return }
        syncStatus = .syncing

        let expenses = (try? brain.fetchAllExpenseRecords()) ?? []
        for record in expenses {
            await pushExpense(record)
        }
        if let debts = debtEngine?.debts, !debts.isEmpty {
            await pushDebts(debts)
        }
        if let goals = goalsEngine?.goals, !goals.isEmpty {
            await pushGoals(goals)
        }
        await pushEntityFirstMasterDataIfNeeded()
        PersonalCloudSyncMetadata.lastSyncedAt = Date()
        if case .error = syncStatus {} else {
            syncStatus = .lastSynced(Date())
        }
    }

    /// Upload local entity-first data when cloud is missing it or local is richer.
    private func reconcileMasterDataIfNeeded() async {
        await pushEntityFirstMasterDataIfNeeded()
    }

    @discardableResult
    private func upsertCloudRecord(
        recordID: CKRecord.ID,
        recordType: String,
        apply: (CKRecord) -> Void
    ) async throws -> CKRecord {
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }
        apply(record)
        do {
            return try await privateDatabase.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            guard let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
                throw error
            }
            apply(serverRecord)
            return try await privateDatabase.save(serverRecord)
        }
    }

    // MARK: - Push

    private func pushExpense(_ record: ExpenseRecord) async {
        guard isEnabled, await ensureAccountAvailable() else { return }
        let payload = PersonalExpensePayload(from: record)
        guard let json = try? JSONEncoder().encode(payload),
              let jsonString = String(data: json, encoding: .utf8) else { return }

        let recordID = makeRecordID(recordName: "personal-expense-\(record.id.uuidString)")

        do {
            _ = try await upsertCloudRecord(
                recordID: recordID,
                recordType: PersonalCloudRecordType.expense
            ) { cloudRecord in
                cloudRecord[PersonalCloudField.entityId] = record.id.uuidString as CKRecordValue
                cloudRecord[PersonalCloudField.payloadJSON] = jsonString as CKRecordValue
                cloudRecord[PersonalCloudField.updatedAt] = record.updatedAt as CKRecordValue
            }
            PersonalCloudSyncMetadata.lastSyncedAt = Date()
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "expenses"))
        }
    }

    private func pushExpenseDeletion(id: UUID, currencyCode: String) async {
        guard isEnabled, await ensureAccountAvailable() else { return }
        let payload = PersonalExpensePayload(
            from: ExpenseRecord(
                id: id,
                name: "",
                amountValue: 0,
                currencyCode: currencyCode,
                date: Date(),
                categoryRaw: TransactionCategory.other.rawValue,
                merchantName: ""
            ),
            isDeleted: true
        )
        var tombstone = payload
        tombstone.updatedAt = Date()
        guard let json = try? JSONEncoder().encode(tombstone),
              let jsonString = String(data: json, encoding: .utf8) else { return }

        let recordID = makeRecordID(recordName: "personal-expense-\(id.uuidString)")

        do {
            _ = try await upsertCloudRecord(
                recordID: recordID,
                recordType: PersonalCloudRecordType.expense
            ) { cloudRecord in
                cloudRecord[PersonalCloudField.entityId] = id.uuidString as CKRecordValue
                cloudRecord[PersonalCloudField.payloadJSON] = jsonString as CKRecordValue
                cloudRecord[PersonalCloudField.updatedAt] = Date() as CKRecordValue
            }
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "expenses"))
        }
    }

    private func pushDebts(_ debts: [Debt]) async {
        guard isEnabled, await ensureAccountAvailable() else { return }
        for debt in debts {
            let revision = Self.debtRevision(debt)
            guard let json = try? JSONEncoder().encode(debt),
                  let jsonString = String(data: json, encoding: .utf8) else { continue }
            let recordID = makeRecordID(recordName: "personal-debt-\(debt.id.uuidString)")
            do {
                _ = try await upsertCloudRecord(
                    recordID: recordID,
                    recordType: PersonalCloudRecordType.debt
                ) { cloudRecord in
                    cloudRecord[PersonalCloudField.entityId] = debt.id.uuidString as CKRecordValue
                    cloudRecord[PersonalCloudField.payloadJSON] = jsonString as CKRecordValue
                    cloudRecord[PersonalCloudField.updatedAt] = revision as CKRecordValue
                }
            } catch {
                if isMissingRecordTypeError(error, recordType: PersonalCloudRecordType.debt) { return }
                syncStatus = .error(userFacingSyncError(error, feature: "debts"))
            }
        }
    }

    private func pushGoals(_ goals: [Goal]) async {
        guard isEnabled, await ensureAccountAvailable() else { return }
        for goal in goals {
            let revision = Self.goalRevision(goal)
            guard let json = try? JSONEncoder().encode(goal),
                  let jsonString = String(data: json, encoding: .utf8) else { continue }
            let recordID = makeRecordID(recordName: "personal-goal-\(goal.id.uuidString)")
            do {
                _ = try await upsertCloudRecord(
                    recordID: recordID,
                    recordType: PersonalCloudRecordType.goal
                ) { cloudRecord in
                    cloudRecord[PersonalCloudField.entityId] = goal.id.uuidString as CKRecordValue
                    cloudRecord[PersonalCloudField.payloadJSON] = jsonString as CKRecordValue
                    cloudRecord[PersonalCloudField.updatedAt] = revision as CKRecordValue
                }
            } catch {
                if isMissingRecordTypeError(error, recordType: PersonalCloudRecordType.goal) { return }
                syncStatus = .error(userFacingSyncError(error, feature: "goals"))
            }
        }
    }

    private func pushSettings() async {
        await pushSettingsDomainsIfNeeded()
    }

    private func pushStudio() async {
        await pushStudioEntitiesIfNeeded()
    }

    private func pushSimpleStudio() async {
        await pushSimpleStudioEntitiesIfNeeded()
    }

    private func pushHustles() async {
        await pushHustleEntitiesIfNeeded()
    }

    private func pushEntityFirstMasterDataIfNeeded() async {
        await pushSettingsDomainsIfNeeded()
        await pushStudioEntitiesIfNeeded()
        await pushSimpleStudioEntitiesIfNeeded()
        await pushHustleEntitiesIfNeeded()
        await pushSyncManifestIfNeeded()
    }

    private func pushSettingsDomainsIfNeeded() async {
        guard isEnabled, await ensureAccountAvailable(), !isApplyingRemote else { return }
        PersonalSettingsDomainSync.refreshDomainRevisions(from: settingsStore)
        for domain in PersonalSettingsDomainSync.exportAllDomains(from: settingsStore) {
            guard PersonalSettingsDomainSync.domainHasUserData(domain) else { continue }
            let recordID = makeRecordID(recordName: "personal-settings-domain-\(domain.domainId)")
            if let remote = await fetchRecordIfExists(recordID),
               !shouldPushSettingsDomain(local: domain, remote: remote) { continue }
            await upsertSettingsDomainRecord(domain, recordID: recordID)
        }
    }

    private func pushStudioEntitiesIfNeeded() async {
        guard isEnabled, await ensureAccountAvailable(), !isApplyingRemote else { return }
        for entity in PersonalStudioEntitySync.exportAll(from: StudioStore.shared) {
            guard PersonalStudioEntitySync.entityHasUserData(entity) else { continue }
            let recordID = makeRecordID(recordName: PersonalStudioEntitySync.recordName(for: entity))
            if let remote = await fetchEntityRecordIfExists(recordID),
               !PersonalEntityMergeEngine.shouldPushLocal(local: entity, remote: remote) { continue }
            await upsertGenericEntityRecord(entity, recordID: recordID, recordType: PersonalCloudRecordType.studioEntity)
        }
    }

    private func pushSimpleStudioEntitiesIfNeeded() async {
        guard isEnabled, await ensureAccountAvailable(), !isApplyingRemote else { return }
        for entity in PersonalSimpleStudioEntitySync.exportAll(from: SimpleStudioStore.shared) {
            let recordID = makeRecordID(recordName: PersonalSimpleStudioEntitySync.recordName(for: entity))
            if let remote = await fetchEntityRecordIfExists(recordID),
               !PersonalEntityMergeEngine.shouldPushLocal(local: entity, remote: remote) { continue }
            await upsertGenericEntityRecord(entity, recordID: recordID, recordType: PersonalCloudRecordType.simpleStudioEntity)
        }
    }

    private func pushHustleEntitiesIfNeeded() async {
        guard isEnabled, await ensureAccountAvailable(), !isApplyingRemote else { return }
        for entity in PersonalHustleEntitySync.exportAll(from: HustleManager.shared) {
            let recordID = makeRecordID(recordName: PersonalHustleEntitySync.recordName(for: entity))
            if let remote = await fetchEntityRecordIfExists(recordID),
               !PersonalEntityMergeEngine.shouldPushLocal(local: entity, remote: remote) { continue }
            await upsertGenericEntityRecord(entity, recordID: recordID, recordType: PersonalCloudRecordType.hustleEntity)
        }
    }

    private func pushSyncManifestIfNeeded() async {
        guard isEnabled, await ensureAccountAvailable() else { return }
        var manifest = PersonalSyncManifestPayload.fresh(deviceId: PersonalSyncDeviceIdentity.currentDeviceId)
        manifest.dualDeviceReconcileCompletedVersion = PersonalSyncReconciler.dualDeviceReconcileCompletedVersion()
        manifest.lastFullReconcileAt = PersonalCloudSyncMetadata.lastSyncedAt
        manifest.updatedAt = Date()
        guard let json = try? JSONEncoder().encode(manifest),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        let recordID = makeRecordID(recordName: "personal-sync-manifest")
        do {
            _ = try await upsertCloudRecord(recordID: recordID, recordType: PersonalCloudRecordType.manifest) { record in
                record[PersonalCloudField.payloadJSON] = jsonString as CKRecordValue
                record[PersonalCloudField.updatedAt] = manifest.updatedAt as CKRecordValue
            }
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "iCloud"))
        }
    }

    private func upsertSettingsDomainRecord(_ domain: PersonalSettingsDomainRecord, recordID: CKRecord.ID) async {
        guard let payloadJSON = String(data: domain.data, encoding: .utf8) else { return }
        do {
            _ = try await upsertCloudRecord(recordID: recordID, recordType: PersonalCloudRecordType.settingsDomain) { record in
                record[PersonalCloudField.domainId] = domain.domainId as CKRecordValue
                record[PersonalCloudField.payloadJSON] = payloadJSON as CKRecordValue
                record[PersonalCloudField.updatedAt] = domain.updatedAt as CKRecordValue
                record[PersonalCloudField.deviceId] = domain.deviceId as CKRecordValue
                record[PersonalCloudField.contentHash] = domain.contentHash as CKRecordValue
            }
            PersonalCloudSyncMetadata.lastSyncedAt = Date()
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "settings"))
        }
    }

    private func upsertGenericEntityRecord(_ entity: PersonalSyncEntityRecord, recordID: CKRecord.ID, recordType: String) async {
        do {
            _ = try await upsertCloudRecord(recordID: recordID, recordType: recordType) { record in
                record[PersonalCloudField.entityKind] = entity.entityKind as CKRecordValue
                record[PersonalCloudField.entityId] = entity.entityId as CKRecordValue
                record[PersonalCloudField.payloadJSON] = entity.payloadJSON as CKRecordValue
                record[PersonalCloudField.updatedAt] = entity.updatedAt as CKRecordValue
                record[PersonalCloudField.deviceId] = entity.deviceId as CKRecordValue
                record[PersonalCloudField.contentHash] = entity.contentHash as CKRecordValue
                record[PersonalCloudField.isDeleted] = (entity.isDeleted ? 1 : 0) as CKRecordValue
                if entity.usesExternalAsset,
                   let attachmentData = entity.attachmentData,
                   let asset = makeSyncAsset(from: attachmentData) {
                    record[PersonalCloudField.payloadAsset] = asset
                } else if entity.usesExternalAsset, let asset = makeSyncAsset(from: entity.payloadJSON) {
                    record[PersonalCloudField.payloadAsset] = asset
                }
            }
            PersonalCloudSyncMetadata.lastSyncedAt = Date()
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "iCloud"))
        }
    }

    private func makeSyncAsset(from data: Data) -> CKAsset? {
        guard !data.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bux-sync-\(UUID().uuidString).bin")
        do {
            try data.write(to: url, options: .atomic)
            return CKAsset(fileURL: url)
        } catch {
            return nil
        }
    }

    private func makeSyncAsset(from json: String) -> CKAsset? {
        guard json.utf8.count >= 100_000 else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bux-sync-\(UUID().uuidString).json")
        do {
            try json.write(to: url, atomically: true, encoding: .utf8)
            return CKAsset(fileURL: url)
        } catch {
            return nil
        }
    }

    private func shouldPushSettingsDomain(local: PersonalSettingsDomainRecord, remote: CKRecord) -> Bool {
        let remoteUpdated = (remote[PersonalCloudField.updatedAt] as? Date) ?? .distantPast
        guard let remoteJSON = remote[PersonalCloudField.payloadJSON] as? String,
              let remoteData = remoteJSON.data(using: .utf8),
              let remoteDomainID = PersonalSettingsDomainID(rawValue: local.domainId) else {
            return local.updatedAt > remoteUpdated
        }
        let remoteDomain = PersonalSettingsDomainRecord(
            domain: remoteDomainID,
            data: remoteData,
            updatedAt: remoteUpdated,
            deviceId: "",
            contentHash: PersonalSyncContentHash.hash(data: remoteData)
        )
        if local.domainId == PersonalSettingsDomainID.budget.rawValue {
            return PersonalSettingsDomainSync.shouldPushBudgetDomain(local: local, remote: remoteDomain)
        }
        if local.updatedAt > remoteUpdated { return true }
        return PersonalSettingsDomainSync.domainHasUserData(local) && !PersonalSettingsDomainSync.domainHasUserData(remoteDomain)
    }

    private func fetchEntityRecordIfExists(_ recordID: CKRecord.ID) async -> PersonalSyncEntityRecord? {
        guard let record = await fetchRecordIfExists(recordID) else { return nil }
        return decodeEntityRecord(record)
    }

    private func decodeSettingsDomainRecord(_ record: CKRecord) -> PersonalSettingsDomainRecord? {
        let domainId = (record[PersonalCloudField.domainId] as? String)
            ?? record.recordID.recordName.replacingOccurrences(of: "personal-settings-domain-", with: "")
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8),
              let domain = PersonalSettingsDomainID(rawValue: domainId) else { return nil }
        return PersonalSettingsDomainRecord(
            domain: domain,
            data: data,
            updatedAt: (record[PersonalCloudField.updatedAt] as? Date) ?? Date(),
            deviceId: (record[PersonalCloudField.deviceId] as? String) ?? "",
            contentHash: (record[PersonalCloudField.contentHash] as? String) ?? PersonalSyncContentHash.hash(data: data)
        )
    }

    private func decodeEntityRecord(_ record: CKRecord) -> PersonalSyncEntityRecord? {
        var jsonString = record[PersonalCloudField.payloadJSON] as? String ?? ""
        var attachmentData: Data?
        if let asset = record[PersonalCloudField.payloadAsset] as? CKAsset, let url = asset.fileURL {
            if jsonString.isEmpty, let assetText = try? String(contentsOf: url, encoding: .utf8) {
                jsonString = assetText
            } else if let assetData = try? Data(contentsOf: url) {
                attachmentData = assetData
            }
        }
        guard let entityKind = record[PersonalCloudField.entityKind] as? String,
              let entityId = record[PersonalCloudField.entityId] as? String,
              !jsonString.isEmpty else { return nil }
        return PersonalSyncEntityRecord(
            entityKind: entityKind,
            entityId: entityId,
            payloadJSON: jsonString,
            updatedAt: (record[PersonalCloudField.updatedAt] as? Date) ?? Date(),
            deviceId: (record[PersonalCloudField.deviceId] as? String) ?? "",
            contentHash: (record[PersonalCloudField.contentHash] as? String) ?? PersonalSyncContentHash.hash(json: jsonString),
            isDeleted: (record[PersonalCloudField.isDeleted] as? Int) == 1,
            usesExternalAsset: record[PersonalCloudField.payloadAsset] != nil,
            attachmentData: attachmentData
        )
    }

    private func decodeManifestRecord(_ record: CKRecord) -> PersonalSyncManifestPayload? {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PersonalSyncManifestPayload.self, from: data)
    }

    private func ingestEntityRecordsForReconcile(_ records: [CKRecord], brain: BuxMuseBrain, errors: inout [String]) {
        var settingsDomains: [PersonalSettingsDomainRecord] = []
        var studioEntities: [PersonalSyncEntityRecord] = []
        var simpleStudioEntities: [PersonalSyncEntityRecord] = []
        var hustleEntities: [PersonalSyncEntityRecord] = []
        var manifest: PersonalSyncManifestPayload?
        var importedLegacySettings = false

        for record in records where !record.recordID.recordName.contains("bootstrap") {
            switch record.recordType {
            case PersonalCloudRecordType.settingsDomain:
                if let domain = decodeSettingsDomainRecord(record) { settingsDomains.append(domain) }
            case PersonalCloudRecordType.settings:
                if settingsDomains.isEmpty, applyLegacySettingsMasterRecord(record, errors: &errors) {
                    importedLegacySettings = true
                }
            case PersonalCloudRecordType.studioEntity:
                if let entity = decodeEntityRecord(record) { studioEntities.append(entity) }
            case PersonalCloudRecordType.studio:
                if studioEntities.isEmpty { importLegacyStudioMasterRecord(record) }
            case PersonalCloudRecordType.simpleStudioEntity:
                if let entity = decodeEntityRecord(record) { simpleStudioEntities.append(entity) }
            case PersonalCloudRecordType.simpleStudio:
                if simpleStudioEntities.isEmpty { importLegacySimpleStudioMasterRecord(record) }
            case PersonalCloudRecordType.hustleEntity:
                if let entity = decodeEntityRecord(record) { hustleEntities.append(entity) }
            case PersonalCloudRecordType.hustles:
                if hustleEntities.isEmpty { importLegacyHustlesMasterRecord(record) }
            case PersonalCloudRecordType.manifest:
                manifest = decodeManifestRecord(record)
            default:
                continue
            }
        }

        if importedLegacySettings {
            settingsDomains = PersonalSettingsDomainSync.exportAllDomains(from: settingsStore)
        }
        if studioEntities.isEmpty, StudioStore.shared.didLoadPersistedSnapshot {
            studioEntities = PersonalStudioEntitySync.exportAll(from: StudioStore.shared)
        }

        _ = PersonalSyncReconciler.reconcileAfterPull(
            brain: brain,
            settingsStore: settingsStore,
            remoteSettingsDomains: settingsDomains,
            remoteStudioEntities: studioEntities,
            remoteSimpleStudioEntities: simpleStudioEntities,
            remoteHustleEntities: hustleEntities,
            manifest: manifest
        )
        pendingConflictCount = PersonalSyncConflictStore.shared.unresolvedCount
    }

    @discardableResult
    private func applyLegacySettingsMasterRecord(_ record: CKRecord, errors: inout [String]) -> Bool {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PersonalSettingsPayload.self, from: data) else { return false }
        let remoteUpdated = (record[PersonalCloudField.updatedAt] as? Date) ?? payload.updatedAt
        let localRevision = PersonalCloudSyncMetadata.settingsRevision ?? .distantPast
        guard shouldApplyMasterRecord(
            remoteUpdatedAt: remoteUpdated,
            remoteHasContent: SettingsStore.archiveContainsUserData(payload.settingsData),
            localRevision: localRevision,
            localHasContent: localSettingsHasUserData()
        ) else { return false }
        do {
            try settingsStore.importArchiveSettingsData(payload.settingsData)
            PersonalCloudSyncMetadata.settingsRevision = remoteUpdated
            PersonalSettingsDomainSync.refreshDomainRevisions(from: settingsStore)
            return true
        } catch {
            errors.append(userFacingSyncError(error, feature: "settings"))
            return false
        }
    }

    private func importLegacyStudioMasterRecord(_ record: CKRecord) {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PersonalStudioPayload.self, from: data) else { return }
        let remoteUpdated = (record[PersonalCloudField.updatedAt] as? Date) ?? payload.updatedAt
        let localRevision = PersonalCloudSyncMetadata.studioRevision ?? .distantPast
        let localHas = studioSnapshotHasUserData(StudioStore.shared.currentSnapshot())
        let remoteHas = studioSnapshotHasUserData(payload.snapshot)
        guard shouldApplyMasterRecord(
            remoteUpdatedAt: remoteUpdated,
            remoteHasContent: remoteHas,
            localRevision: localRevision,
            localHasContent: localHas
        ) else { return }
        StudioStore.shared.apply(payload.snapshot)
        StudioStore.shared.save(notifyCloudSync: false)
        PersonalCloudSyncMetadata.studioRevision = remoteUpdated
    }

    private func importLegacySimpleStudioMasterRecord(_ record: CKRecord) {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PersonalSimpleStudioPayload.self, from: data) else { return }
        let remoteUpdated = (record[PersonalCloudField.updatedAt] as? Date) ?? payload.updatedAt
        let localRevision = PersonalCloudSyncMetadata.simpleStudioRevision ?? .distantPast
        let localHas = simpleStudioSnapshotHasUserData(SimpleStudioStore.shared.snapshot)
        let remoteHas = simpleStudioSnapshotHasUserData(payload.snapshot)
        guard shouldApplyMasterRecord(
            remoteUpdatedAt: remoteUpdated,
            remoteHasContent: remoteHas,
            localRevision: localRevision,
            localHasContent: localHas
        ) else { return }
        SimpleStudioStore.shared.apply(payload.snapshot)
        SimpleStudioStore.shared.save(notifyCloudSync: false)
        PersonalCloudSyncMetadata.simpleStudioRevision = remoteUpdated
    }

    private func importLegacyHustlesMasterRecord(_ record: CKRecord) {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PersonalHustlesPayload.self, from: data) else { return }
        let remoteUpdated = (record[PersonalCloudField.updatedAt] as? Date) ?? payload.updatedAt
        let localRevision = PersonalCloudSyncMetadata.hustlesRevision ?? .distantPast
        let localHas = !HustleManager.shared.hustles.isEmpty
        let remoteHas = !payload.hustles.isEmpty
        guard shouldApplyMasterRecord(
            remoteUpdatedAt: remoteUpdated,
            remoteHasContent: remoteHas,
            localRevision: localRevision,
            localHasContent: localHas
        ) else { return }
        HustleManager.shared.replaceAll(payload.hustles, selectedId: payload.selectedHustleId, notifyCloudSync: false)
        PersonalCloudSyncMetadata.hustlesRevision = remoteUpdated
    }

    // MARK: - Pull

    func pullRemoteChanges() async {
        guard isEnabled, let brain else { return }
        guard await ensureAccountAvailable() else { return }
        syncStatus = .syncing
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        var syncErrors: [String] = []

        do {
            let zoneRecords = try await fetchRecordsFromPersonalZone()
            let masterRecords = await fetchMasterRecordsDirectly()
            let records = mergeRecordsPreferringNewer(zoneRecords, masterRecords)
            applyRemoteRecords(records, into: brain, errors: &syncErrors)
        } catch let error as CKError where error.code == .changeTokenExpired {
            PersonalCloudSyncMetadata.zoneChangeToken = nil
            do {
                let zoneRecords = try await fetchRecordsFromPersonalZone()
                let masterRecords = await fetchMasterRecordsDirectly()
                let records = mergeRecordsPreferringNewer(zoneRecords, masterRecords)
                applyRemoteRecords(records, into: brain, errors: &syncErrors)
            } catch {
                syncErrors.append(userFacingSyncError(error, feature: "iCloud"))
            }
        } catch {
            syncErrors.append(userFacingSyncError(error, feature: "iCloud"))
        }

        brain.refreshExpenses()
        debtEngine?.load()
        pendingConflictCount = PersonalSyncConflictStore.shared.unresolvedCount

        NotificationCenter.default.post(name: .buxMusePersonalCloudSyncDidPull, object: nil)

        let uniqueErrors = Array(Set(syncErrors))
        if uniqueErrors.isEmpty {
            PersonalCloudSyncMetadata.lastSyncedAt = Date()
            syncStatus = .lastSynced(Date())
        } else if uniqueErrors.count == 1 {
            syncStatus = .error(uniqueErrors[0])
        } else {
            syncStatus = .error(uniqueErrors.joined(separator: " "))
        }
    }

    private func applyRemoteRecords(_ records: [CKRecord], into brain: BuxMuseBrain, errors: inout [String]) {
        var mergedDebts = debtEngine?.debts ?? []
        var mergedGoals = goalsEngine?.goals ?? []

        for record in records {
            if record.recordID.recordName.contains("bootstrap") { continue }
            switch record.recordType {
            case PersonalCloudRecordType.expense:
                applyExpenseRecord(record, into: brain)
            case PersonalCloudRecordType.debt:
                applyDebtRecord(record, merged: &mergedDebts)
            case PersonalCloudRecordType.goal:
                applyGoalRecord(record, merged: &mergedGoals)
            default:
                continue
            }
        }

        debtEngine?.replaceAllDebtsFromSync(mergedDebts)
        goalsEngine?.replaceAllGoals(mergedGoals)
        ingestEntityRecordsForReconcile(records, brain: brain, errors: &errors)
    }

    private func applyExpenseRecord(_ record: CKRecord, into brain: BuxMuseBrain) {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PersonalExpensePayload.self, from: data) else {
            return
        }
        if payload.isDeleted {
            try? brain.persistence.deleteExpenseRecord(id: payload.id)
            return
        }
        if let existing = try? brain.fetchExpenseRecord(id: payload.id),
           existing.updatedAt >= payload.updatedAt {
            return
        }
        _ = try? brain.saveExpenseRecord(payload.toExpenseRecord(), merchantSelection: nil)
    }

    private func applyDebtRecord(_ record: CKRecord, merged: inout [Debt]) {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8),
              let remote = try? JSONDecoder().decode(Debt.self, from: data) else {
            return
        }
        let remoteRevision = (record[PersonalCloudField.updatedAt] as? Date) ?? Self.debtRevision(remote)
        if let index = merged.firstIndex(where: { $0.id == remote.id }) {
            let localRevision = Self.debtRevision(merged[index])
            guard remoteRevision >= localRevision else { return }
            merged[index] = remote
        } else {
            merged.append(remote)
        }
    }

    private func applyGoalRecord(_ record: CKRecord, merged: inout [Goal]) {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8),
              let remote = try? JSONDecoder().decode(Goal.self, from: data) else {
            return
        }
        let remoteRevision = (record[PersonalCloudField.updatedAt] as? Date) ?? Self.goalRevision(remote)
        if let index = merged.firstIndex(where: { $0.id == remote.id }) {
            let localRevision = Self.goalRevision(merged[index])
            guard remoteRevision >= localRevision else { return }
            merged[index] = remote
        } else {
            merged.append(remote)
        }
    }

    private func fetchRecordsFromPersonalZone() async throws -> [CKRecord] {
        let zoneID = personalZoneID
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = PersonalCloudSyncMetadata.zoneChangeToken

        return try await withCheckedThrowingContinuation { continuation in
            var fetchedRecords: [CKRecord] = []
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: configuration]
            )

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    fetchedRecords.append(record)
                }
            }

            operation.recordZoneFetchResultBlock = { _, result in
                if case .success(let zoneResult) = result {
                    PersonalCloudSyncMetadata.zoneChangeToken = zoneResult.serverChangeToken
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: fetchedRecords)
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .changeTokenExpired {
                        PersonalCloudSyncMetadata.zoneChangeToken = nil
                    }
                    continuation.resume(throwing: error)
                }
            }

            privateDatabase.add(operation)
        }
    }

    private func ensurePersonalZoneExists() async throws {
        let zone = CKRecordZone(zoneID: personalZoneID)
        do {
            _ = try await privateDatabase.modifyRecordZones(saving: [zone], deleting: [])
        } catch let error as CKError where error.code == .serverRecordChanged || error.code == .zoneNotFound {
            return
        }
    }

    // MARK: - Schema / errors

    /// CloudKit creates record types on first save in Development; Production needs Dashboard schema deploy.
    private func ensurePersonalRecordTypesExist() async {
        guard await ensureAccountAvailable() else { return }
        _ = await bootstrapRecordType(PersonalCloudRecordType.expense, recordName: "personal-expense-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.debt, recordName: "personal-debt-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.goal, recordName: "personal-goal-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.settings, recordName: "personal-settings-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.studio, recordName: "personal-studio-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.simpleStudio, recordName: "personal-simple-studio-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.hustles, recordName: "personal-hustles-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.settingsDomain, recordName: "personal-settings-domain-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.studioEntity, recordName: "personal-studio-entity-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.simpleStudioEntity, recordName: "personal-simple-studio-entity-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.hustleEntity, recordName: "personal-hustle-entity-bootstrap")
        _ = await bootstrapRecordType(PersonalCloudRecordType.manifest, recordName: "personal-sync-manifest-bootstrap")
    }

    @discardableResult
    private func bootstrapRecordType(_ recordType: String, recordName: String) async -> Bool {
        let recordID = makeRecordID(recordName: recordName)
        do {
            _ = try await upsertCloudRecord(
                recordID: recordID,
                recordType: recordType
            ) { cloudRecord in
                cloudRecord[PersonalCloudField.entityId] = "bootstrap" as CKRecordValue
                cloudRecord[PersonalCloudField.payloadJSON] = "[]" as CKRecordValue
                cloudRecord[PersonalCloudField.updatedAt] = Date.distantPast as CKRecordValue
            }
            return true
        } catch {
            return !isMissingRecordTypeError(error, recordType: recordType)
        }
    }

    private func isMissingRecordTypeError(_ error: Error, recordType: String) -> Bool {
        let message = error.localizedDescription.lowercased()
        if message.contains("did not find record type") {
            return message.contains(recordType.lowercased()) || recordType.isEmpty
        }
        return false
    }

    private func userFacingSyncError(_ error: Error, feature: String) -> String {
        let message = error.localizedDescription.lowercased()
        if isMissingRecordTypeError(error, recordType: "") {
            return "iCloud sync setup is still finishing. Try again in a moment."
        }
        if message.contains("not marked queryable") {
            return "iCloud sync hit a temporary Apple server issue. Tap refresh to try again."
        }
        if message.contains("did not find record type") {
            return "iCloud sync setup is still finishing. Try again in a moment."
        }
        if message.contains("already exists") {
            return "iCloud sync is catching up on this device. Tap refresh to try again."
        }
        return error.localizedDescription
    }

    private static func debtRevision(_ debt: Debt) -> Date {
        debt.payments.map(\.date).max() ?? debt.createdAt
    }

    private static func goalRevision(_ goal: Goal) -> Date {
        goal.contributions.map(\.date).max() ?? goal.createdAt
    }

    // MARK: - Master record merge helpers

    private static let masterRecordNames = [
        "personal-settings-master",
        "personal-studio-master",
        "personal-simple-studio-master",
        "personal-hustles-master"
    ]

    private func fetchMasterRecordsDirectly() async -> [CKRecord] {
        var records: [CKRecord] = []
        for name in Self.masterRecordNames {
            let recordID = makeRecordID(recordName: name)
            if let record = try? await privateDatabase.record(for: recordID) {
                records.append(record)
            }
        }
        return records
    }

    private func fetchRecordIfExists(_ recordID: CKRecord.ID) async -> CKRecord? {
        try? await privateDatabase.record(for: recordID)
    }

    private func mergeRecordsPreferringNewer(_ lhs: [CKRecord], _ rhs: [CKRecord]) -> [CKRecord] {
        var byID: [String: CKRecord] = [:]
        for record in lhs + rhs {
            let key = record.recordID.recordName
            guard let existing = byID[key] else {
                byID[key] = record
                continue
            }
            let existingDate = (existing[PersonalCloudField.updatedAt] as? Date) ?? .distantPast
            let candidateDate = (record[PersonalCloudField.updatedAt] as? Date) ?? .distantPast
            if candidateDate >= existingDate {
                byID[key] = record
            }
        }
        return Array(byID.values)
    }

    private func shouldApplyMasterRecord(
        remoteUpdatedAt: Date,
        remoteHasContent: Bool,
        localRevision: Date?,
        localHasContent: Bool
    ) -> Bool {
        if localHasContent && !remoteHasContent { return false }
        let localRev = localRevision ?? .distantPast
        if remoteUpdatedAt > localRev { return true }
        if remoteHasContent && !localHasContent { return true }
        return false
    }

    private func shouldPushMasterRecord(
        localUpdatedAt: Date,
        localHasContent: Bool,
        remoteRecord: CKRecord?
    ) -> Bool {
        guard localHasContent else { return false }
        guard let remoteRecord else { return true }
        let remoteUpdatedAt = (remoteRecord[PersonalCloudField.updatedAt] as? Date) ?? .distantPast
        let remoteHasContent = masterRecordHasContent(remoteRecord)
        if !remoteHasContent { return true }
        return localUpdatedAt > remoteUpdatedAt
    }

    private func masterRecordHasContent(_ record: CKRecord) -> Bool {
        guard let jsonString = record[PersonalCloudField.payloadJSON] as? String,
              let data = jsonString.data(using: .utf8) else {
            return false
        }
        switch record.recordType {
        case PersonalCloudRecordType.settings:
            guard let payload = try? JSONDecoder().decode(PersonalSettingsPayload.self, from: data) else { return false }
            return settingsPayloadHasUserData(payload)
        case PersonalCloudRecordType.studio:
            guard let payload = try? JSONDecoder().decode(PersonalStudioPayload.self, from: data) else { return false }
            return studioSnapshotHasUserData(payload.snapshot)
        case PersonalCloudRecordType.simpleStudio:
            guard let payload = try? JSONDecoder().decode(PersonalSimpleStudioPayload.self, from: data) else { return false }
            return simpleStudioSnapshotHasUserData(payload.snapshot)
        case PersonalCloudRecordType.hustles:
            guard let payload = try? JSONDecoder().decode(PersonalHustlesPayload.self, from: data) else { return false }
            return !payload.hustles.isEmpty
        default:
            return false
        }
    }

    private func localSettingsHasUserData() -> Bool {
        if settingsStore.hasCompletedOnboarding { return true }
        if let brain, ((try? brain.fetchAllExpenseRecords()) ?? []).isEmpty == false { return true }
        if let data = settingsStore.exportArchiveSettingsData() {
            return SettingsStore.archiveContainsUserData(data)
        }
        return false
    }

    private func settingsPayloadHasUserData(_ payload: PersonalSettingsPayload) -> Bool {
        SettingsStore.archiveContainsUserData(payload.settingsData)
    }

    private func studioSnapshotHasUserData(_ snapshot: StudioSnapshot) -> Bool {
        !snapshot.clients.isEmpty
            || !snapshot.invoices.isEmpty
            || !snapshot.projects.isEmpty
            || !snapshot.receipts.isEmpty
            || !snapshot.agreementDrafts.isEmpty
            || !snapshot.mileageEntries.isEmpty
            || !snapshot.profile.businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !snapshot.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func simpleStudioSnapshotHasUserData(_ snapshot: SimpleStudioSnapshot) -> Bool {
        !snapshot.entries.isEmpty || !snapshot.invoices.isEmpty || !snapshot.customers.isEmpty || snapshot.businessCard != nil
    }
}
