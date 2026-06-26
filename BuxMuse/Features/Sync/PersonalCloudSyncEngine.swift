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
    static let pendingCloudRestoreKey = "buxmuse.personalCloud.pendingCloudRestore"

    static var pendingCloudRestore: Bool {
        get { defaults.bool(forKey: pendingCloudRestoreKey) }
        set {
            if newValue {
                defaults.set(true, forKey: pendingCloudRestoreKey)
            } else {
                defaults.removeObject(forKey: pendingCloudRestoreKey)
            }
        }
    }

    static func clearPendingCloudRestore() {
        pendingCloudRestore = false
    }

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

    /// Clears on-device sync bookkeeping only — never deletes CloudKit records.
    static func resetLocalState(preserveCloudSnapshot: Bool = true) {
        lastSyncedAt = nil
        // Always require a cloud adopt/join pass after reset — never treat device as upload source.
        initialUploadCompleted = false
        _ = preserveCloudSnapshot
        settingsRevision = nil
        studioRevision = nil
        simpleStudioRevision = nil
        hustlesRevision = nil
        zoneChangeToken = nil
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
    private(set) var lastPullAdoptedCloudBackup = false
    private var preferLocalMergeOnNextPull = false
    private var forceCloudAdoptOnNextPull = false
    private var lastPullReceivedRemoteUserData = false
    private var forceFullZoneFetchOnNextPull = false
    private var preferredRestoreSourceDeviceIdOnNextPull: String?

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

    /// Factory reset: wipe local sync state and disable pull/push. iCloud data is untouched.
    func prepareForFactoryReset() {
        cancelPendingPushWork()
        stopForegroundPullTimer()
        isPullInFlight = false
        isApplyingRemote = false

        PersonalCloudSyncMetadata.resetLocalState(preserveCloudSnapshot: true)
        PersonalSettingsDomainSync.resetLocalSyncMetadata()
        PersonalSyncConflictStore.shared.clearAll()
        pendingConflictCount = 0

        settingsStore.personalCloudSyncEnabled = false
        refreshEnabledState()
    }

    /// Set after local nuclear wipe when iCloud backup was kept — forces silent cloud restore on next sync enable.
    static var isPendingCloudRestoreAfterWipe: Bool {
        PersonalCloudSyncMetadata.pendingCloudRestore
    }

    static func markPendingCloudRestoreAfterLocalWipe() {
        PersonalCloudSyncMetadata.pendingCloudRestore = true
    }

    static func clearPendingCloudRestore() {
        PersonalCloudSyncMetadata.pendingCloudRestore = false
    }

    static var hasCompletedInitialCloudUpload: Bool {
        PersonalCloudSyncMetadata.initialUploadCompleted
    }

    static var lastCloudSyncDate: Date? {
        PersonalCloudSyncMetadata.lastSyncedAt
    }

    /// Permanently deletes the personal sync zone and all CloudKit records in it.
    func deleteAllCloudData() async throws {
        cancelPendingPushWork()
        stopForegroundPullTimer()
        isPullInFlight = false
        isApplyingRemote = false

        guard await ensureAccountAvailable() else {
            throw PersonalCloudSyncDeletionError.iCloudUnavailable
        }

        _ = try? await privateDatabase.deleteSubscription(withID: Self.zoneSubscriptionID)
        try await purgeAllRecordsInPersonalZone()

        do {
            _ = try await privateDatabase.modifyRecordZones(saving: [], deleting: [personalZoneID])
        } catch let error as CKError where error.code == .zoneNotFound {
            // Zone already removed — treat as success.
        }

        PersonalCloudSyncMetadata.resetLocalState(preserveCloudSnapshot: false)
        PersonalSettingsDomainSync.resetLocalSyncMetadata()
        UserDefaults.standard.removeObject(forKey: "buxmuse.personalSync.dualReconcileVersion")
        PersonalSyncConflictStore.shared.clearAll()
        pendingConflictCount = 0
        settingsStore.personalCloudSyncEnabled = false
        refreshEnabledState()
    }

    /// Deletes every record in the personal sync zone before the zone itself is removed.
    private func purgeAllRecordsInPersonalZone() async throws {
        let zoneID = personalZoneID
        var recordIDs: [CKRecord.ID] = []
        var changeToken: CKServerChangeToken?
        var done = false

        while !done {
            let fetched = try await fetchAllRecordIDs(in: zoneID, previousToken: changeToken)
            recordIDs.append(contentsOf: fetched.recordIDs)
            changeToken = fetched.nextToken
            done = fetched.moreComing == false
        }

        guard !recordIDs.isEmpty else { return }

        let batchSize = 400
        var index = 0
        while index < recordIDs.count {
            let end = min(index + batchSize, recordIDs.count)
            let batch = Array(recordIDs[index..<end])
            _ = try await privateDatabase.modifyRecords(saving: [], deleting: batch)
            index = end
        }
    }

    private func fetchAllRecordIDs(
        in zoneID: CKRecordZone.ID,
        previousToken: CKServerChangeToken?
    ) async throws -> (recordIDs: [CKRecord.ID], nextToken: CKServerChangeToken?, moreComing: Bool) {
        try await withCheckedThrowingContinuation { continuation in
            var collected: [CKRecord.ID] = []
            var nextToken: CKServerChangeToken?
            var moreComing = false

            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = previousToken

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: configuration]
            )

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    collected.append(record.recordID)
                }
            }
            operation.recordZoneFetchResultBlock = { _, result in
                if case .success(let payload) = result {
                    nextToken = payload.serverChangeToken
                    moreComing = payload.moreComing
                }
            }
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (collected, nextToken, moreComing))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            privateDatabase.add(operation)
        }
    }

    private func cancelPendingPushWork() {
        settingsPushWork?.cancel()
        studioPushWork?.cancel()
        simpleStudioPushWork?.cancel()
        hustlesPushWork?.cancel()
    }

    func setEnabled(
        _ enabled: Bool,
        preferLocalMerge: Bool = false,
        preferredRestoreSourceDeviceId: String? = nil
    ) async {
        settingsStore.personalCloudSyncEnabled = enabled
        settingsStore.save(notifyCloudSync: false)
        refreshEnabledState()
        guard enabled else {
            stopForegroundPullTimer()
            return
        }
        syncStatus = .syncing
        guard await ensureAccountAvailable() else { return }
        do {
            try await ensurePersonalZoneExists()
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "iCloud"))
            return
        }
        preferLocalMergeOnNextPull = preferLocalMerge
        forceCloudAdoptOnNextPull = !preferLocalMerge
        forceFullZoneFetchOnNextPull = !preferLocalMerge
        preferredRestoreSourceDeviceIdOnNextPull = preferredRestoreSourceDeviceId
        if !preferLocalMerge {
            PersonalCloudSyncMetadata.zoneChangeToken = nil
        }
        isApplyingRemote = true
        defer {
            isApplyingRemote = false
            preferLocalMergeOnNextPull = false
            forceCloudAdoptOnNextPull = false
            forceFullZoneFetchOnNextPull = false
            preferredRestoreSourceDeviceIdOnNextPull = nil
        }
        await pullRemoteChangesIfIdle(forceFullZoneFetch: !preferLocalMerge)

        if !preferLocalMerge, !lastPullAdoptedCloudBackup, !lastPullReceivedRemoteUserData {
            PersonalCloudSyncMetadata.zoneChangeToken = nil
            await pullRemoteChangesIfIdle(forceFullZoneFetch: true)
        }

        if !preferLocalMerge, !lastPullAdoptedCloudBackup, !lastPullReceivedRemoteUserData {
            syncStatus = .error("Could not download your iCloud backup. Check that you are signed into iCloud and try again.")
            settingsStore.personalCloudSyncEnabled = false
            settingsStore.save(notifyCloudSync: false)
            refreshEnabledState()
            return
        }

        if !PersonalCloudSyncMetadata.initialUploadCompleted {
            if lastPullAdoptedCloudBackup || lastPullReceivedRemoteUserData {
                PersonalCloudSyncMetadata.initialUploadCompleted = true
            } else if preferLocalMerge {
                await performInitialUpload()
                PersonalCloudSyncMetadata.initialUploadCompleted = true
            }
        } else {
            await reconcileInitialUploadIfNeeded()
        }
        if shouldPushLocalMasterData(brain: brain), !lastPullAdoptedCloudBackup, preferLocalMerge {
            await reconcileMasterDataIfNeeded()
        }
        startForegroundPullTimer()
        Task {
            await ensurePersonalRecordTypesExist()
            await ensureZoneSubscription()
        }
    }

    /// Pre-enable iCloud account check for settings UI (does not turn sync on).
    func ensureAccountAvailableForEnable() async -> Bool {
        await ensureAccountAvailable()
    }

    private func shouldPushLocalMasterData(brain: BuxMuseBrain?) -> Bool {
        guard let brain else { return false }
        return PersonalSyncReconciler.localHasMeaningfulUserData(brain: brain, settingsStore: settingsStore)
    }

    func syncNow() async {
        guard isEnabled else { return }
        syncStatus = .syncing
        guard await ensureAccountAvailable() else { return }
        do {
            try await ensurePersonalZoneExists()
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "iCloud"))
            return
        }
        isApplyingRemote = true
        await pullRemoteChangesIfIdle()
        isApplyingRemote = false
        if shouldPushLocalMasterData(brain: brain), !lastPullAdoptedCloudBackup {
            await reconcileMasterDataIfNeeded()
        }
        await pushAllLocalExpenses()
        Task { await ensurePersonalRecordTypesExist() }
    }

    /// Fast pre-enable probe — manifest + legacy masters only (no schema bootstrap, no full zone scan).
    func fetchCloudBackupSummary() async -> PersonalCloudBackupSummary? {
        guard await ensureAccountAvailable() else { return nil }
        do {
            try await ensurePersonalZoneExists()
        } catch {
            return nil
        }

        let manifestID = makeRecordID(recordName: "personal-sync-manifest")
        async let manifestTask = fetchManifestRecord(recordID: manifestID)
        async let mastersTask = fetchMasterRecordsDirectly()
        let manifest = await manifestTask
        let masterRecords = await mastersTask

        if let manifest {
            let devices = manifest.registeredDevices.sorted { $0.lastSeenAt > $1.lastSeenAt }
            let sourceDevice = manifest.preferredBackupSourceDevice(
                excludingDeviceId: PersonalSyncDeviceIdentity.currentDeviceId
            ) ?? manifest.preferredBackupSourceDevice()
            return PersonalCloudBackupSummary(
                lastBackupAt: manifest.lastFullReconcileAt ?? manifest.updatedAt,
                expenseRecordCount: 0,
                hasConfiguredSettings: true,
                registeredDeviceCount: devices.count,
                sourceDeviceName: sourceDevice?.name,
                recommendedSourceDeviceId: sourceDevice?.deviceId,
                registeredDevices: devices
            )
        }

        if masterRecords.contains(where: masterRecordHasContent) {
            return PersonalCloudBackupSummary(
                lastBackupAt: masterRecords.compactMap { $0[PersonalCloudField.updatedAt] as? Date }.max(),
                expenseRecordCount: 0,
                hasConfiguredSettings: true,
                registeredDeviceCount: 0,
                sourceDeviceName: nil,
                registeredDevices: []
            )
        }

        return nil
    }

    /// Always prompt before first enable when iCloud already has a backup.
    func shouldOfferRestoreChoice(summary: PersonalCloudBackupSummary) -> Bool {
        guard !settingsStore.personalCloudSyncEnabled else { return false }
        return summary.hasBackupContent
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

    /// Bulk push after wallet import or manual sync — uploads local rows CloudKit never received.
    func pushExpenses(_ records: [ExpenseRecord]) async {
        guard isEnabled, !isApplyingRemote else { return }
        guard !records.isEmpty else { return }
        for record in records {
            await pushExpense(record)
        }
    }

    func pushAllLocalExpenses() async {
        guard isEnabled, !isApplyingRemote, let brain else { return }
        let expenses = (try? brain.fetchAllExpenseRecords()) ?? []
        await pushExpenses(expenses)
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
        if shouldPushLocalMasterData(brain: brain), !lastPullAdoptedCloudBackup {
            await reconcileMasterDataIfNeeded()
        }
        await ensureZoneSubscription()
        startForegroundPullTimer()
    }

    private func pullRemoteChangesIfIdle(forceFullZoneFetch: Bool = false) async {
        guard isEnabled, !isPullInFlight else { return }
        isPullInFlight = true
        defer { isPullInFlight = false }
        await pullRemoteChanges(forceFullZoneFetch: forceFullZoneFetch)
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
        guard shouldPushLocalMasterData(brain: brain) else { return }
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
        await saveSyncManifest(lastFullReconcileAt: PersonalCloudSyncMetadata.lastSyncedAt)
    }

    /// Registers this device in the manifest after pull-only sessions (e.g. cloud restore on a new device).
    private func touchSyncManifestPresence() async {
        await saveSyncManifest(lastFullReconcileAt: nil)
    }

    private func saveSyncManifest(lastFullReconcileAt: Date?) async {
        guard isEnabled, await ensureAccountAvailable() else { return }
        let recordID = makeRecordID(recordName: "personal-sync-manifest")
        let existing = await fetchManifestRecord(recordID: recordID)
        let now = Date()
        var manifest = (existing ?? PersonalSyncManifestPayload.fresh(
            deviceId: PersonalSyncDeviceIdentity.currentDeviceId,
            deviceName: PersonalSyncDeviceIdentity.currentDeviceName
        )).registeringDevice(
            id: PersonalSyncDeviceIdentity.currentDeviceId,
            name: PersonalSyncDeviceIdentity.currentDeviceName,
            at: now
        )
        manifest.dualDeviceReconcileCompletedVersion = PersonalSyncReconciler.dualDeviceReconcileCompletedVersion()
        if let lastFullReconcileAt {
            manifest.lastFullReconcileAt = lastFullReconcileAt
        }
        manifest.updatedAt = now
        guard let json = try? JSONEncoder().encode(manifest),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        do {
            _ = try await upsertCloudRecord(recordID: recordID, recordType: PersonalCloudRecordType.manifest) { record in
                record[PersonalCloudField.payloadJSON] = jsonString as CKRecordValue
                record[PersonalCloudField.updatedAt] = manifest.updatedAt as CKRecordValue
            }
        } catch {
            syncStatus = .error(userFacingSyncError(error, feature: "iCloud"))
        }
    }

    private func fetchManifestRecord(recordID: CKRecord.ID) async -> PersonalSyncManifestPayload? {
        guard let record = await fetchRecordIfExists(recordID) else { return nil }
        return decodeManifestRecord(record)
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
        var remoteExpenseCount = 0

        for record in records where !record.recordID.recordName.contains("bootstrap") {
            switch record.recordType {
            case PersonalCloudRecordType.expense:
                remoteExpenseCount += 1
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
        if studioEntities.isEmpty, StudioStore.shared.didLoadPersistedSnapshot, !forceCloudAdoptOnNextPull {
            studioEntities = PersonalStudioEntitySync.exportAll(from: StudioStore.shared)
        }

        let reconcileResult = PersonalSyncReconciler.reconcileAfterPull(
            brain: brain,
            settingsStore: settingsStore,
            remoteSettingsDomains: settingsDomains,
            remoteStudioEntities: studioEntities,
            remoteSimpleStudioEntities: simpleStudioEntities,
            remoteHustleEntities: hustleEntities,
            manifest: manifest,
            preferLocalMerge: preferLocalMergeOnNextPull,
            forceCloudAdopt: forceCloudAdoptOnNextPull,
            remoteExpenseCount: remoteExpenseCount,
            preferredRestoreSourceDeviceId: preferredRestoreSourceDeviceIdOnNextPull
        )
        lastPullAdoptedCloudBackup = reconcileResult.adoptedCloudBackup
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

    func pullRemoteChanges(forceFullZoneFetch: Bool = false) async {
        guard isEnabled, let brain else { return }
        guard await ensureAccountAvailable() else { return }
        syncStatus = .syncing
        lastPullAdoptedCloudBackup = false
        let useFullZoneFetch = forceFullZoneFetch || forceFullZoneFetchOnNextPull
        if useFullZoneFetch {
            PersonalCloudSyncMetadata.zoneChangeToken = nil
        }
        let zoneFetchToken = useFullZoneFetch ? nil : PersonalCloudSyncMetadata.zoneChangeToken

        var syncErrors: [String] = []
        var pulledRecords: [CKRecord] = []

        do {
            async let zoneRecordsTask = fetchZoneRecords(
                persistChangeToken: true,
                previousToken: zoneFetchToken
            )
            async let masterRecordsTask = fetchMasterRecordsDirectly()
            let zoneRecords = try await zoneRecordsTask
            let masterRecords = await masterRecordsTask
            pulledRecords = mergeRecordsPreferringNewer(zoneRecords, masterRecords)
            applyRemoteRecords(pulledRecords, into: brain, errors: &syncErrors)
        } catch let error as CKError where error.code == .changeTokenExpired {
            PersonalCloudSyncMetadata.zoneChangeToken = nil
            do {
                async let zoneRecordsTask = fetchZoneRecords(persistChangeToken: true, previousToken: nil)
                async let masterRecordsTask = fetchMasterRecordsDirectly()
                let zoneRecords = try await zoneRecordsTask
                let masterRecords = await masterRecordsTask
                pulledRecords = mergeRecordsPreferringNewer(zoneRecords, masterRecords)
                applyRemoteRecords(pulledRecords, into: brain, errors: &syncErrors)
            } catch {
                syncErrors.append(userFacingSyncError(error, feature: "iCloud"))
            }
        } catch {
            syncErrors.append(userFacingSyncError(error, feature: "iCloud"))
        }

        lastPullReceivedRemoteUserData = pulledRecords.contains {
            !$0.recordID.recordName.contains("bootstrap")
        }

        brain.refreshExpenses()
        debtEngine?.load()
        pendingConflictCount = PersonalSyncConflictStore.shared.unresolvedCount

        NotificationCenter.default.post(name: .buxMusePersonalCloudSyncDidPull, object: nil)

        let uniqueErrors = Array(Set(syncErrors))
        if uniqueErrors.isEmpty {
            PersonalCloudSyncMetadata.lastSyncedAt = Date()
            syncStatus = .lastSynced(Date())
            if lastPullAdoptedCloudBackup || lastPullReceivedRemoteUserData {
                await touchSyncManifestPresence()
            }
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
            if let financeKitId = normalizedFinanceKitId(payload.financeKitTransactionId),
               let linked = try? brain.fetchExpenseRecord(financeKitTransactionId: financeKitId),
               linked.id != payload.id {
                try? brain.persistence.deleteExpenseRecord(id: linked.id)
            }
            return
        }

        var incoming = payload.toExpenseRecord()

        if let financeKitId = normalizedFinanceKitId(payload.financeKitTransactionId),
           let existingByFinanceKit = try? brain.fetchExpenseRecord(financeKitTransactionId: financeKitId),
           existingByFinanceKit.id != payload.id {
            if existingByFinanceKit.updatedAt >= payload.updatedAt {
                return
            }
            incoming = expenseRecord(incoming, replacingID: existingByFinanceKit.id)
            _ = try? brain.saveExpenseRecord(incoming, merchantSelection: nil)
            return
        }

        if let existing = try? brain.fetchExpenseRecord(id: payload.id),
           existing.updatedAt >= payload.updatedAt {
            return
        }
        _ = try? brain.saveExpenseRecord(incoming, merchantSelection: nil)
    }

    private func normalizedFinanceKitId(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func expenseRecord(_ record: ExpenseRecord, replacingID id: UUID) -> ExpenseRecord {
        var replaced = ExpenseRecord(
            id: id,
            name: record.name,
            amountValue: record.amountValue,
            currencyCode: record.currencyCode,
            categoryId: record.categoryId,
            merchantId: record.merchantId,
            date: record.date,
            notes: record.notes,
            isRecurring: record.isRecurring,
            recurrenceType: record.recurrenceType,
            recurrenceConfidence: record.recurrenceConfidence,
            nextExpectedDate: record.nextExpectedDate,
            isSubscriptionLike: record.isSubscriptionLike,
            isTrial: record.isTrial,
            subscriptionStartDate: record.subscriptionStartDate,
            trialEndDate: record.trialEndDate,
            renewalReminderDays: record.renewalReminderDays,
            heatZoneBucket: record.heatZoneBucket,
            emotion: record.emotion,
            contextTag: record.contextTag,
            habitSignatureId: record.habitSignatureId,
            subscriptionConfidence: record.subscriptionConfidence,
            microCommitmentType: record.microCommitmentType,
            microCommitmentValue: record.microCommitmentValue,
            futureImpact1Y: record.futureImpact1Y,
            futureImpact5Y: record.futureImpact5Y,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            categoryRaw: record.categoryRaw,
            merchantName: record.merchantName,
            hustleId: record.hustleId,
            paymentMethod: record.paymentMethod,
            isBarterExchange: record.isBarterExchange,
            barterGoodsGiven: record.barterGoodsGiven,
            barterGoodsReceived: record.barterGoodsReceived,
            barterEstimatedValue: record.barterEstimatedValue,
            bridgeGroupId: record.bridgeGroupId,
            bridgeKind: record.bridgeKind,
            bridgeRole: record.bridgeRole,
            bridgeSharePercent: record.bridgeSharePercent,
            bridgePeerExpenseId: record.bridgePeerExpenseId,
            bridgeCounterpartyHustleId: record.bridgeCounterpartyHustleId,
            isCategorySplit: record.isCategorySplit,
            splitLines: record.splitLines,
            householdScope: record.householdScope,
            walletIsPending: record.walletIsPending,
            walletCategoryUserConfirmed: record.walletCategoryUserConfirmed,
            walletCategoryConfidence: record.walletCategoryConfidence,
            incomeRole: record.incomeRole,
            isExcludedFromSpending: record.isExcludedFromSpending
        )
        replaced.financeKitTransactionId = record.financeKitTransactionId
        replaced.walletAccountId = record.walletAccountId
        return replaced
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
        try await fetchZoneRecords(persistChangeToken: true, previousToken: PersonalCloudSyncMetadata.zoneChangeToken)
    }

    private func fetchZoneRecords(
        persistChangeToken: Bool,
        previousToken: CKServerChangeToken?
    ) async throws -> [CKRecord] {
        let zoneID = personalZoneID
        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = previousToken

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
                if persistChangeToken, case .success(let zoneResult) = result {
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
        let locale = BuxInterfaceLocale.currentInterfaceLocale
        let message = error.localizedDescription.lowercased()
        if isMissingRecordTypeError(error, recordType: "") {
            return BuxLocalizedString.string(
                "iCloud sync setup is still finishing. Try again in a moment.",
                locale: locale
            )
        }
        if message.contains("not marked queryable") {
            return BuxLocalizedString.string(
                "iCloud sync hit a temporary Apple server issue. Tap refresh to try again.",
                locale: locale
            )
        }
        if message.contains("did not find record type") {
            return BuxLocalizedString.string(
                "iCloud sync setup is still finishing. Try again in a moment.",
                locale: locale
            )
        }
        if message.contains("already exists") {
            return BuxLocalizedString.string(
                "iCloud sync is catching up on this device. Tap refresh to try again.",
                locale: locale
            )
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
        let recordIDs = Self.masterRecordNames.map { makeRecordID(recordName: $0) }
        return await withTaskGroup(of: CKRecord?.self) { group in
            for recordID in recordIDs {
                group.addTask {
                    try? await self.privateDatabase.record(for: recordID)
                }
            }
            var records: [CKRecord] = []
            for await record in group {
                if let record {
                    records.append(record)
                }
            }
            return records
        }
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
        if let brain {
            return PersonalSyncReconciler.localHasMeaningfulUserData(brain: brain, settingsStore: settingsStore)
        }
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

enum PersonalCloudSyncDeletionError: LocalizedError {
    case iCloudUnavailable

    var errorDescription: String? {
        let locale = BuxInterfaceLocale.currentInterfaceLocale
        switch self {
        case .iCloudUnavailable:
            return BuxLocalizedString.string(
                "Sign in to iCloud on this device and try again.",
                locale: locale
            )
        }
    }
}
