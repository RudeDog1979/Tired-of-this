//
//  PersonalSyncReconciler.swift
//  BuxMuse
//

import Foundation

enum PersonalSyncReconciler {
    private static let manifestDefaultsKey = "buxmuse.personalSync.dualReconcileVersion"

    @MainActor
    static func reconcileAfterPull(
        brain: BuxMuseBrain,
        settingsStore: SettingsStore,
        remoteSettingsDomains: [PersonalSettingsDomainRecord],
        remoteStudioEntities: [PersonalSyncEntityRecord],
        remoteSimpleStudioEntities: [PersonalSyncEntityRecord],
        remoteHustleEntities: [PersonalSyncEntityRecord],
        manifest: PersonalSyncManifestPayload?
    ) -> [PersonalSyncConflict] {
        var conflicts: [PersonalSyncConflict] = []

        let localSettings = PersonalSettingsDomainSync.exportAllDomains(from: settingsStore)
        let settingsMerge = PersonalSettingsDomainSync.mergeDomains(local: localSettings, remote: remoteSettingsDomains)
        PersonalSettingsDomainSync.applyDomains(settingsMerge.merged, to: settingsStore)
        conflicts.append(contentsOf: settingsMerge.conflicts)

        let localStudio = PersonalStudioEntitySync.exportAll(from: StudioStore.shared)
        let studioMerge = PersonalStudioEntitySync.merge(local: localStudio, remote: remoteStudioEntities)
        PersonalStudioEntitySync.apply(studioMerge.merged, to: StudioStore.shared)
        conflicts.append(contentsOf: studioMerge.conflicts)

        let localSimple = PersonalSimpleStudioEntitySync.exportAll(from: SimpleStudioStore.shared)
        let simpleMerge = PersonalSimpleStudioEntitySync.merge(local: localSimple, remote: remoteSimpleStudioEntities)
        PersonalSimpleStudioEntitySync.apply(simpleMerge.merged, to: SimpleStudioStore.shared)
        conflicts.append(contentsOf: simpleMerge.conflicts)

        let localHustles = PersonalHustleEntitySync.exportAll(from: HustleManager.shared)
        let hustleMerge = PersonalHustleEntitySync.merge(local: localHustles, remote: remoteHustleEntities)
        PersonalHustleEntitySync.apply(hustleMerge.merged, to: HustleManager.shared)
        conflicts.append(contentsOf: hustleMerge.conflicts)

        if shouldRunDualDevicePass(brain: brain, manifest: manifest) {
            markDualDeviceReconcileComplete()
        }

        PersonalSyncConflictStore.shared.append(contentsOf: conflicts)
        _ = brain
        return conflicts
    }

    @MainActor
    static func localHasUserData(brain: BuxMuseBrain) -> Bool {
        let expenses = (try? brain.fetchAllExpenseRecords()) ?? []
        if !expenses.isEmpty { return true }
        if SettingsStore.shared.hasCompletedOnboarding { return true }
        if !PersonalStudioEntitySync.exportAll(from: StudioStore.shared).filter({ PersonalStudioEntitySync.entityHasUserData($0) }).isEmpty { return true }
        if !PersonalSimpleStudioEntitySync.exportAll(from: SimpleStudioStore.shared).isEmpty { return true }
        if !HustleManager.shared.hustles.isEmpty { return true }
        return false
    }

    static func cloudHasUserData(
        settingsDomains: [PersonalSettingsDomainRecord],
        studioEntities: [PersonalSyncEntityRecord],
        simpleEntities: [PersonalSyncEntityRecord],
        hustleEntities: [PersonalSyncEntityRecord],
        expenseCount: Int
    ) -> Bool {
        if expenseCount > 0 { return true }
        if settingsDomains.contains(where: { PersonalSettingsDomainSync.domainHasUserData($0) }) { return true }
        if studioEntities.contains(where: { PersonalStudioEntitySync.entityHasUserData($0) }) { return true }
        if !simpleEntities.isEmpty { return true }
        if !hustleEntities.filter({ $0.entityKind == PersonalHustleEntityKind.hustle.cloudKind }).isEmpty { return true }
        return false
    }

    static func dualDeviceReconcileCompletedVersion() -> Int? {
        let value = UserDefaults.standard.integer(forKey: manifestDefaultsKey)
        return value == 0 ? nil : value
    }

    private static func shouldRunDualDevicePass(brain: BuxMuseBrain, manifest: PersonalSyncManifestPayload?) -> Bool {
        guard dualDeviceReconcileCompletedVersion() != PersonalSyncSchema.currentVersion else { return false }
        return localHasUserData(brain: brain) || manifest != nil
    }

    private static func markDualDeviceReconcileComplete() {
        UserDefaults.standard.set(PersonalSyncSchema.currentVersion, forKey: manifestDefaultsKey)
    }
}
