//
//  PersonalSettingsDomainSync.swift
//  BuxMuse
//
//  Export, merge, and apply settings as independent iCloud domains.
//

import Foundation

// MARK: - Domain payloads

struct SettingsProfileDomain: Codable, Equatable {
    var firstName: String?
    var lastName: String?
    var profileAvatarData: Data?
    var preferredNameStyle: PreferredNameStyle
    var hasCompletedOnboarding: Bool
}

struct SettingsRegionalDomain: Codable, Equatable {
    var syncedCurrencyId: String?
    var syncedCountryId: String?
    var syncedInterfaceLanguageRaw: String?
    var weekStartDay: WeekStartDay
    var primaryLocalCurrency: String
    var secondaryTradingCurrency: String
}

struct SettingsAppearanceDomain: Codable, Equatable {
    var themeMode: ThemeMode
    var accentColorId: String
    var neutralAccentId: String
    var useGlassmorphism: Bool
    var brandThemesEnabled: Bool
    var landingBackdropEnabled: Bool
    var showVisualHorizonBackground: Bool
    var reducedMotion: Bool
    var solarContrastModeEnabled: Bool
}

struct SettingsBudgetDomain: Codable, Equatable {
    var budgetingMode: BudgetingMode
    var defaultBudgetPeriod: DefaultBudgetPeriod
    var showBudgetWarnings: Bool
    var autoAdjustBudgetsFromHistory: Bool
    var customBudgetProfiles: [CustomBudgetProfile]
    var simpleBudgetLimit: Decimal
    var simpleBudgetCycle: SimpleBudgetCycle
    var simpleBudgetPeriodAnchor: Date
    var incomeFundingSource: IncomeFundingSource
    var salaryPayProfile: SalaryPayProfile?
    var includeSimpleStudioIncomeInBudget: Bool
    var includeProStudioIncomeInBudget: Bool
    var customBudgetLimit: Decimal
    var customBudgetPeriod: DefaultBudgetPeriod
    var budgetApproachingThresholdPercent: Int
    var budgetQuickSetupCompleted: Bool
}

struct SettingsStudioFlagsDomain: Codable, Equatable {
    var studioEnabled: Bool
    var studioProfileId: UUID?
    var studioMode: StudioMode
    var studioPersona: StudioPersona
    var studioPersonaConfigured: Bool
    var studioDiscoveryOfferDismissed: Bool
    var standardBudgetStudioBridgePromptDismissed: Bool
}

struct SettingsDebtDomain: Codable, Equatable {
    var consumerDebtEnabled: Bool
    var debtDiscoveryDeferred: Bool
}

struct SettingsNotificationsDomain: Codable, Equatable {
    var notificationsEnabled: Bool
    var budgetAlertsEnabled: Bool
    var billRemindersEnabled: Bool
    var studioInvoiceRemindersEnabled: Bool
    var taxDeadlineRemindersEnabled: Bool
    var dailySummaryEnabled: Bool
    var quietHoursStartHour: Int
    var quietHoursStartMinute: Int
    var quietHoursEndHour: Int
    var quietHoursEndMinute: Int
    var burnoutGuardEnabled: Bool
    var healthKitSyncEnabled: Bool
    var hasAcknowledgedHealthKitDisclaimer: Bool
    var manualSleepHours: Double
    var manualStressLevel: Double
}

struct SettingsSecurityDomain: Codable, Equatable {
    var biometricLockEnabled: Bool
    var requireBiometricOnLaunch: Bool
    var lockAfterInactivityMinutes: Int
    var privacyBlurInAppSwitching: Bool
}

struct SettingsHouseholdDomain: Codable, Equatable {
    var householdCloudRecordName: String?
    var householdShareURL: String?
    var sharedEnvelopeProfileId: UUID?
    var householdDisplayName: String?
    var householdSharedZoneName: String?
    var householdSharedZoneOwner: String?
}

struct SettingsDataBackupDomain: Codable, Equatable {
    var allowLocalBackups: Bool
    var autoBackupFrequency: AutoBackupFrequency
    var customBackupIntervalDays: Int
    var includeStudioDataInExports: Bool
    var includeAnalyticsInExports: Bool
    var lastExportDate: Date?
    var personalCloudSyncEnabled: Bool
}

struct SettingsFeatureFlagsDomain: Codable, Equatable {
    var enableDebugOverlay: Bool
    var showPerformanceMetrics: Bool
    var dataGuardModeEnabled: Bool
    var barterLoggerEnabled: Bool
    var antiScopeCreepEnabled: Bool
    var agreementScratchpadEnabled: Bool
    var agreementDefaultEnabledClauseIds: [String]
    var agreementDefaultCustomTerms: String
    var sideHustleMatrixEnabled: Bool
    var showUnassignedExpensesInWorkspace: Bool
    var paymentSourceTrackingEnabled: Bool
    var dualCashDrawerEnabled: Bool
    var cashLocalBalanceValue: Double
    var cashSecondaryBalanceValue: Double
    var appTourFinished: Bool
    var appTourSkipped: Bool
}

struct SettingsGreetingDomain: Codable, Equatable {
    var greetingHeaderEnabled: Bool
    var greetingShowIcon: Bool
    var greetingFontStyle: GreetingFontStyle
}

struct SettingsSubscriptionsDomain: Codable, Equatable {
    var cancelledSubscriptionMerchants: [String]
}

// MARK: - Domain sync engine

enum PersonalSettingsDomainSync {
    private static let revisionDefaultsKey = "buxmuse.personalSync.settingsDomainRevisions"

    static func domainRevisions() -> [String: Date] {
        guard let raw = UserDefaults.standard.dictionary(forKey: revisionDefaultsKey) as? [String: Date] else {
            return [:]
        }
        return raw
    }

    private static func setDomainRevisions(_ revisions: [String: Date]) {
        UserDefaults.standard.set(revisions, forKey: revisionDefaultsKey)
    }

    /// Clears local domain revision/hash caches after factory reset (CloudKit unchanged).
    static func resetLocalSyncMetadata() {
        UserDefaults.standard.removeObject(forKey: revisionDefaultsKey)
        UserDefaults.standard.removeObject(forKey: "buxmuse.personalSync.settingsDomainHashes")
    }

    static func exportAllDomains(from store: SettingsStore) -> [PersonalSettingsDomainRecord] {
        let deviceId = PersonalSyncDeviceIdentity.currentDeviceId
        let revisions = domainRevisions()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        return PersonalSettingsDomainID.allCases.compactMap { domain in
            guard let data = try? encodeDomain(domain, from: store, encoder: encoder) else { return nil }
            let hash = PersonalSyncContentHash.hash(data: data)
            // Use per-domain revision only — never stamp every domain with lastPersistedAt (breaks iCloud restore).
            let updatedAt = revisions[domain.rawValue] ?? .distantPast
            return PersonalSettingsDomainRecord(
                domain: domain,
                data: data,
                updatedAt: updatedAt,
                deviceId: deviceId,
                contentHash: hash
            )
        }
    }

    static func refreshDomainRevisions(from store: SettingsStore) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var revisions = domainRevisions()
        var changed = false
        let hashDefaultsKey = "buxmuse.personalSync.settingsDomainHashes"
        var hashes = UserDefaults.standard.dictionary(forKey: hashDefaultsKey) as? [String: String] ?? [:]

        for domain in PersonalSettingsDomainID.allCases {
            guard let data = try? encodeDomain(domain, from: store, encoder: encoder) else { continue }
            let hash = PersonalSyncContentHash.hash(data: data)
            if hashes[domain.rawValue] != hash {
                hashes[domain.rawValue] = hash
                revisions[domain.rawValue] = Date()
                changed = true
            }
        }
        if changed {
            UserDefaults.standard.set(hashes, forKey: hashDefaultsKey)
            setDomainRevisions(revisions)
        }
    }

    static func mergeDomains(
        local: [PersonalSettingsDomainRecord],
        remote: [PersonalSettingsDomainRecord]
    ) -> (merged: [PersonalSettingsDomainRecord], conflicts: [PersonalSyncConflict]) {
        var byID: [String: PersonalSettingsDomainRecord] = Dictionary(uniqueKeysWithValues: local.map { ($0.domainId, $0) })
        var conflicts: [PersonalSyncConflict] = []

        for remoteDomain in remote {
            guard let localDomain = byID[remoteDomain.domainId] else {
                byID[remoteDomain.domainId] = remoteDomain
                continue
            }
            if remoteDomain.domainId == PersonalSettingsDomainID.budget.rawValue,
               let preferred = preferredBudgetDomain(local: localDomain, remote: remoteDomain) {
                byID[remoteDomain.domainId] = preferred
                continue
            }
            let localHas = domainHasUserData(localDomain)
            let remoteHas = domainHasUserData(remoteDomain)
            if localHas && !remoteHas { continue }
            if !localHas && remoteHas {
                byID[remoteDomain.domainId] = remoteDomain
                continue
            }
            if remoteDomain.updatedAt > localDomain.updatedAt {
                byID[remoteDomain.domainId] = remoteDomain
            } else if remoteDomain.updatedAt < localDomain.updatedAt {
                continue
            } else if remoteDomain.contentHash != localDomain.contentHash {
                if localHas && remoteHas && recordsConflictAcrossDevices(local: localDomain, remote: remoteDomain) {
                    conflicts.append(
                        PersonalSyncConflict(
                            kind: .settingsDomain,
                            entityKey: remoteDomain.domainId,
                            titleKey: conflictTitleKey(for: remoteDomain.domainId),
                            localUpdatedAt: localDomain.updatedAt,
                            remoteUpdatedAt: remoteDomain.updatedAt,
                            localSummary: localDomain.domainId,
                            remoteSummary: remoteDomain.domainId
                        )
                    )
                } else {
                    byID[remoteDomain.domainId] = preferredDomainWhenHashesDiffer(
                        local: localDomain,
                        remote: remoteDomain,
                        localHas: localHas,
                        remoteHas: remoteHas
                    )
                }
            }
        }
        return (Array(byID.values), conflicts)
    }

    /// Applies cloud domains/entities wholesale — used when this device has no meaningful local data yet.
    @MainActor
    static func applyCloudRestore(
        settingsStore: SettingsStore,
        remoteSettingsDomains: [PersonalSettingsDomainRecord],
        remoteStudioEntities: [PersonalSyncEntityRecord],
        remoteSimpleStudioEntities: [PersonalSyncEntityRecord],
        remoteHustleEntities: [PersonalSyncEntityRecord]
    ) {
        if !remoteSettingsDomains.isEmpty {
            applyDomains(remoteSettingsDomains, to: settingsStore)
        }
        if !remoteStudioEntities.isEmpty {
            PersonalStudioEntitySync.apply(remoteStudioEntities, to: StudioStore.shared)
        }
        if !remoteSimpleStudioEntities.isEmpty {
            PersonalSimpleStudioEntitySync.apply(remoteSimpleStudioEntities, to: SimpleStudioStore.shared)
        }
        if !remoteHustleEntities.isEmpty {
            PersonalHustleEntitySync.apply(remoteHustleEntities, to: HustleManager.shared)
        }
        PersonalSyncConflictStore.shared.clearAll()
    }

    static func localBudgetIsConfigured(in store: SettingsStore) -> Bool {
        if store.budgetQuickSetupCompleted { return true }
        if store.budgetingMode == .custom, !store.customBudgetProfiles.isEmpty { return true }
        return false
    }

    @MainActor
    static func applyDomains(_ domains: [PersonalSettingsDomainRecord], to store: SettingsStore) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for record in domains {
            applyDomain(record, to: store, decoder: decoder)
        }
        var revisions = domainRevisions()
        for record in domains {
            revisions[record.domainId] = record.updatedAt
        }
        setDomainRevisions(revisions)
        store.save(notifyCloudSync: false)
    }

    static func domainHasUserData(_ record: PersonalSettingsDomainRecord) -> Bool {
        switch PersonalSettingsDomainID(rawValue: record.domainId) {
        case .profile:
            if let payload = try? JSONDecoder().decode(SettingsProfileDomain.self, from: record.data) {
                return payload.firstName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    || payload.profileAvatarData != nil
            }
            return false
        case .budget:
            return budgetDomainIsConfigured(record)
        case .studioFlags:
            if let payload = try? JSONDecoder().decode(SettingsStudioFlagsDomain.self, from: record.data) {
                return payload.studioEnabled
            }
            return false
        case .debt:
            if let payload = try? JSONDecoder().decode(SettingsDebtDomain.self, from: record.data) {
                return payload.consumerDebtEnabled
            }
            return false
        case .dataBackup:
            if let payload = try? JSONDecoder().decode(SettingsDataBackupDomain.self, from: record.data) {
                return payload.personalCloudSyncEnabled
            }
            return false
        default:
            return false
        }
    }

    static func domainsFromLegacyMasterBlob(_ settingsData: Data, updatedAt: Date, deviceId: String) -> [PersonalSettingsDomainRecord] {
        guard let payload = try? JSONDecoder().decode(SettingsStoreLegacyProbe.self, from: settingsData) else {
            return []
        }
        // Legacy blob applied field-by-field through temporary decode — full import happens in engine before push.
        _ = payload
        _ = updatedAt
        _ = deviceId
        return []
    }

    static func budgetDomainIsConfigured(_ record: PersonalSettingsDomainRecord) -> Bool {
        budgetPayloadIsConfigured(decodeBudgetDomain(from: record))
    }

    static func shouldPushBudgetDomain(local: PersonalSettingsDomainRecord, remote: PersonalSettingsDomainRecord) -> Bool {
        let localConfigured = budgetDomainIsConfigured(local)
        let remoteConfigured = budgetDomainIsConfigured(remote)
        if remoteConfigured && !localConfigured { return false }
        if !localConfigured && !remoteConfigured { return false }
        if localConfigured && !remoteConfigured { return true }
        return local.updatedAt >= remote.updatedAt
    }

    private static func preferredBudgetDomain(
        local: PersonalSettingsDomainRecord,
        remote: PersonalSettingsDomainRecord
    ) -> PersonalSettingsDomainRecord? {
        let localConfigured = budgetDomainIsConfigured(local)
        let remoteConfigured = budgetDomainIsConfigured(remote)
        if remoteConfigured && !localConfigured { return remote }
        if localConfigured && !remoteConfigured { return local }
        return nil
    }

    private static func decodeBudgetDomain(from record: PersonalSettingsDomainRecord) -> SettingsBudgetDomain? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SettingsBudgetDomain.self, from: record.data)
    }

    private static func budgetPayloadIsConfigured(_ payload: SettingsBudgetDomain?) -> Bool {
        guard let payload else { return false }
        if payload.budgetQuickSetupCompleted { return true }
        if payload.budgetingMode == .custom, !payload.customBudgetProfiles.isEmpty { return true }
        return false
    }

    nonisolated private static func conflictTitleKey(for domainId: String) -> String {
        switch domainId {
        case PersonalSettingsDomainID.budget.rawValue: return "Budget settings conflict"
        case PersonalSettingsDomainID.appearance.rawValue: return "Appearance settings conflict"
        case PersonalSettingsDomainID.studioFlags.rawValue: return "Studio settings conflict"
        default: return "Settings conflict"
        }
    }

    private static func encodeDomain(
        _ domain: PersonalSettingsDomainID,
        from store: SettingsStore,
        encoder: JSONEncoder
    ) throws -> Data {
        switch domain {
        case .profile:
            return try encoder.encode(SettingsProfileDomain(
                firstName: store.firstName,
                lastName: store.lastName,
                profileAvatarData: store.profileAvatarData,
                preferredNameStyle: store.preferredNameStyle,
                hasCompletedOnboarding: store.hasCompletedOnboarding
            ))
        case .regional:
            return try encoder.encode(SettingsRegionalDomain(
                syncedCurrencyId: store.syncedCurrencyId,
                syncedCountryId: store.syncedCountryId,
                syncedInterfaceLanguageRaw: store.syncedInterfaceLanguageRaw,
                weekStartDay: store.weekStartDay,
                primaryLocalCurrency: store.primaryLocalCurrency,
                secondaryTradingCurrency: store.secondaryTradingCurrency
            ))
        case .appearance:
            return try encoder.encode(SettingsAppearanceDomain(
                themeMode: store.themeMode,
                accentColorId: store.accentColorId,
                neutralAccentId: store.neutralAccentId,
                useGlassmorphism: store.useGlassmorphism,
                brandThemesEnabled: store.brandThemesEnabled,
                landingBackdropEnabled: store.landingBackdropEnabled,
                showVisualHorizonBackground: store.showVisualHorizonBackground,
                reducedMotion: store.reducedMotion,
                solarContrastModeEnabled: store.solarContrastModeEnabled
            ))
        case .budget:
            return try encoder.encode(SettingsBudgetDomain(
                budgetingMode: store.budgetingMode,
                defaultBudgetPeriod: store.defaultBudgetPeriod,
                showBudgetWarnings: store.showBudgetWarnings,
                autoAdjustBudgetsFromHistory: store.autoAdjustBudgetsFromHistory,
                customBudgetProfiles: store.customBudgetProfiles,
                simpleBudgetLimit: store.simpleBudgetLimit,
                simpleBudgetCycle: store.simpleBudgetCycle,
                simpleBudgetPeriodAnchor: store.simpleBudgetPeriodAnchor,
                incomeFundingSource: store.incomeFundingSource,
                salaryPayProfile: store.salaryPayProfile,
                includeSimpleStudioIncomeInBudget: store.includeSimpleStudioIncomeInBudget,
                includeProStudioIncomeInBudget: store.includeProStudioIncomeInBudget,
                customBudgetLimit: store.customBudgetLimit,
                customBudgetPeriod: store.customBudgetPeriod,
                budgetApproachingThresholdPercent: store.budgetApproachingThresholdPercent,
                budgetQuickSetupCompleted: store.budgetQuickSetupCompleted
            ))
        case .studioFlags:
            return try encoder.encode(SettingsStudioFlagsDomain(
                studioEnabled: store.studioEnabled,
                studioProfileId: store.studioProfileId,
                studioMode: store.studioMode,
                studioPersona: store.studioPersona,
                studioPersonaConfigured: store.studioPersonaConfigured,
                studioDiscoveryOfferDismissed: store.studioDiscoveryOfferDismissed,
                standardBudgetStudioBridgePromptDismissed: store.standardBudgetStudioBridgePromptDismissed
            ))
        case .debt:
            return try encoder.encode(SettingsDebtDomain(
                consumerDebtEnabled: store.consumerDebtEnabled,
                debtDiscoveryDeferred: store.debtDiscoveryDeferred
            ))
        case .notifications:
            return try encoder.encode(SettingsNotificationsDomain(
                notificationsEnabled: store.notificationsEnabled,
                budgetAlertsEnabled: store.budgetAlertsEnabled,
                billRemindersEnabled: store.billRemindersEnabled,
                studioInvoiceRemindersEnabled: store.studioInvoiceRemindersEnabled,
                taxDeadlineRemindersEnabled: store.taxDeadlineRemindersEnabled,
                dailySummaryEnabled: store.dailySummaryEnabled,
                quietHoursStartHour: store.quietHoursStartHour,
                quietHoursStartMinute: store.quietHoursStartMinute,
                quietHoursEndHour: store.quietHoursEndHour,
                quietHoursEndMinute: store.quietHoursEndMinute,
                burnoutGuardEnabled: store.burnoutGuardEnabled,
                healthKitSyncEnabled: store.healthKitSyncEnabled,
                hasAcknowledgedHealthKitDisclaimer: store.hasAcknowledgedHealthKitDisclaimer,
                manualSleepHours: store.manualSleepHours,
                manualStressLevel: store.manualStressLevel
            ))
        case .security:
            return try encoder.encode(SettingsSecurityDomain(
                biometricLockEnabled: store.biometricLockEnabled,
                requireBiometricOnLaunch: store.requireBiometricOnLaunch,
                lockAfterInactivityMinutes: store.lockAfterInactivityMinutes,
                privacyBlurInAppSwitching: store.privacyBlurInAppSwitching
            ))
        case .household:
            return try encoder.encode(SettingsHouseholdDomain(
                householdCloudRecordName: store.householdCloudRecordName,
                householdShareURL: store.householdShareURL,
                sharedEnvelopeProfileId: store.sharedEnvelopeProfileId,
                householdDisplayName: store.householdDisplayName,
                householdSharedZoneName: store.householdSharedZoneName,
                householdSharedZoneOwner: store.householdSharedZoneOwner
            ))
        case .dataBackup:
            return try encoder.encode(SettingsDataBackupDomain(
                allowLocalBackups: store.allowLocalBackups,
                autoBackupFrequency: store.autoBackupFrequency,
                customBackupIntervalDays: store.customBackupIntervalDays,
                includeStudioDataInExports: store.includeStudioDataInExports,
                includeAnalyticsInExports: store.includeAnalyticsInExports,
                lastExportDate: store.lastExportDate,
                personalCloudSyncEnabled: store.personalCloudSyncEnabled
            ))
        case .featureFlags:
            return try encoder.encode(SettingsFeatureFlagsDomain(
                enableDebugOverlay: store.enableDebugOverlay,
                showPerformanceMetrics: store.showPerformanceMetrics,
                dataGuardModeEnabled: store.dataGuardModeEnabled,
                barterLoggerEnabled: store.barterLoggerEnabled,
                antiScopeCreepEnabled: store.antiScopeCreepEnabled,
                agreementScratchpadEnabled: store.agreementScratchpadEnabled,
                agreementDefaultEnabledClauseIds: store.agreementDefaultEnabledClauseIds,
                agreementDefaultCustomTerms: store.agreementDefaultCustomTerms,
                sideHustleMatrixEnabled: store.sideHustleMatrixEnabled,
                showUnassignedExpensesInWorkspace: store.showUnassignedExpensesInWorkspace,
                paymentSourceTrackingEnabled: store.paymentSourceTrackingEnabled,
                dualCashDrawerEnabled: store.dualCashDrawerEnabled,
                cashLocalBalanceValue: store.cashLocalBalanceValue,
                cashSecondaryBalanceValue: store.cashSecondaryBalanceValue,
                appTourFinished: false,
                appTourSkipped: false
            ))
        case .greeting:
            return try encoder.encode(SettingsGreetingDomain(
                greetingHeaderEnabled: store.greetingHeaderEnabled,
                greetingShowIcon: store.greetingShowIcon,
                greetingFontStyle: store.greetingFontStyle
            ))
        case .subscriptions:
            return try encoder.encode(SettingsSubscriptionsDomain(
                cancelledSubscriptionMerchants: store.cancelledSubscriptionMerchants
            ))
        }
    }

    @MainActor
    private static func applyDomain(
        _ record: PersonalSettingsDomainRecord,
        to store: SettingsStore,
        decoder: JSONDecoder
    ) {
        guard let domain = PersonalSettingsDomainID(rawValue: record.domainId) else { return }
        switch domain {
        case .profile:
            guard let payload = try? decoder.decode(SettingsProfileDomain.self, from: record.data) else { return }
            store.firstName = payload.firstName
            store.lastName = payload.lastName
            store.profileAvatarData = payload.profileAvatarData
            store.preferredNameStyle = payload.preferredNameStyle
            store.hasCompletedOnboarding = payload.hasCompletedOnboarding
        case .regional:
            guard let payload = try? decoder.decode(SettingsRegionalDomain.self, from: record.data) else { return }
            store.syncedCurrencyId = payload.syncedCurrencyId
            store.syncedCountryId = payload.syncedCountryId
            store.syncedInterfaceLanguageRaw = payload.syncedInterfaceLanguageRaw
            store.weekStartDay = payload.weekStartDay
            store.primaryLocalCurrency = payload.primaryLocalCurrency
            store.secondaryTradingCurrency = payload.secondaryTradingCurrency
        case .appearance:
            guard let payload = try? decoder.decode(SettingsAppearanceDomain.self, from: record.data) else { return }
            store.themeMode = payload.themeMode
            store.accentColorId = payload.accentColorId
            store.neutralAccentId = payload.neutralAccentId
            store.useGlassmorphism = payload.useGlassmorphism
            store.brandThemesEnabled = payload.brandThemesEnabled
            store.landingBackdropEnabled = payload.landingBackdropEnabled
            store.showVisualHorizonBackground = payload.showVisualHorizonBackground
            store.reducedMotion = payload.reducedMotion
            store.solarContrastModeEnabled = payload.solarContrastModeEnabled
        case .budget:
            guard let payload = try? decoder.decode(SettingsBudgetDomain.self, from: record.data) else { return }
            store.budgetingMode = payload.budgetingMode
            store.defaultBudgetPeriod = payload.defaultBudgetPeriod
            store.showBudgetWarnings = payload.showBudgetWarnings
            store.autoAdjustBudgetsFromHistory = payload.autoAdjustBudgetsFromHistory
            store.customBudgetProfiles = payload.customBudgetProfiles
            store.simpleBudgetLimit = payload.simpleBudgetLimit
            store.simpleBudgetCycle = payload.simpleBudgetCycle
            store.simpleBudgetPeriodAnchor = payload.simpleBudgetPeriodAnchor
            store.incomeFundingSource = payload.incomeFundingSource
            store.salaryPayProfile = payload.salaryPayProfile ?? .empty
            store.includeSimpleStudioIncomeInBudget = payload.includeSimpleStudioIncomeInBudget
            store.includeProStudioIncomeInBudget = payload.includeProStudioIncomeInBudget
            store.customBudgetLimit = payload.customBudgetLimit
            store.customBudgetPeriod = payload.customBudgetPeriod
            store.budgetApproachingThresholdPercent = payload.budgetApproachingThresholdPercent
            store.budgetQuickSetupCompleted = payload.budgetQuickSetupCompleted
        case .studioFlags:
            guard let payload = try? decoder.decode(SettingsStudioFlagsDomain.self, from: record.data) else { return }
            store.studioEnabled = payload.studioEnabled
            store.studioProfileId = payload.studioProfileId
            store.studioMode = payload.studioMode
            store.studioPersona = payload.studioPersona
            store.studioPersonaConfigured = payload.studioPersonaConfigured
            store.studioDiscoveryOfferDismissed = payload.studioDiscoveryOfferDismissed
            store.standardBudgetStudioBridgePromptDismissed = payload.standardBudgetStudioBridgePromptDismissed
        case .debt:
            guard let payload = try? decoder.decode(SettingsDebtDomain.self, from: record.data) else { return }
            store.consumerDebtEnabled = payload.consumerDebtEnabled
            store.debtDiscoveryDeferred = payload.debtDiscoveryDeferred
        case .notifications:
            guard let payload = try? decoder.decode(SettingsNotificationsDomain.self, from: record.data) else { return }
            store.notificationsEnabled = payload.notificationsEnabled
            store.budgetAlertsEnabled = payload.budgetAlertsEnabled
            store.billRemindersEnabled = payload.billRemindersEnabled
            store.studioInvoiceRemindersEnabled = payload.studioInvoiceRemindersEnabled
            store.taxDeadlineRemindersEnabled = payload.taxDeadlineRemindersEnabled
            store.dailySummaryEnabled = payload.dailySummaryEnabled
            store.quietHoursStartHour = payload.quietHoursStartHour
            store.quietHoursStartMinute = payload.quietHoursStartMinute
            store.quietHoursEndHour = payload.quietHoursEndHour
            store.quietHoursEndMinute = payload.quietHoursEndMinute
            store.burnoutGuardEnabled = payload.burnoutGuardEnabled
            store.healthKitSyncEnabled = payload.healthKitSyncEnabled
            store.hasAcknowledgedHealthKitDisclaimer = payload.hasAcknowledgedHealthKitDisclaimer
            store.manualSleepHours = payload.manualSleepHours
            store.manualStressLevel = payload.manualStressLevel
        case .security:
            guard let payload = try? decoder.decode(SettingsSecurityDomain.self, from: record.data) else { return }
            store.biometricLockEnabled = payload.biometricLockEnabled
            store.requireBiometricOnLaunch = payload.requireBiometricOnLaunch
            store.lockAfterInactivityMinutes = payload.lockAfterInactivityMinutes
            store.privacyBlurInAppSwitching = payload.privacyBlurInAppSwitching
        case .household:
            guard let payload = try? decoder.decode(SettingsHouseholdDomain.self, from: record.data) else { return }
            store.householdCloudRecordName = payload.householdCloudRecordName
            store.householdShareURL = payload.householdShareURL
            store.sharedEnvelopeProfileId = payload.sharedEnvelopeProfileId
            store.householdDisplayName = payload.householdDisplayName
            store.householdSharedZoneName = payload.householdSharedZoneName
            store.householdSharedZoneOwner = payload.householdSharedZoneOwner
        case .dataBackup:
            guard let payload = try? decoder.decode(SettingsDataBackupDomain.self, from: record.data) else { return }
            store.allowLocalBackups = payload.allowLocalBackups
            store.autoBackupFrequency = payload.autoBackupFrequency
            store.customBackupIntervalDays = payload.customBackupIntervalDays
            store.includeStudioDataInExports = payload.includeStudioDataInExports
            store.includeAnalyticsInExports = payload.includeAnalyticsInExports
            store.lastExportDate = payload.lastExportDate
            store.personalCloudSyncEnabled = payload.personalCloudSyncEnabled
        case .featureFlags:
            guard let payload = try? decoder.decode(SettingsFeatureFlagsDomain.self, from: record.data) else { return }
            store.enableDebugOverlay = payload.enableDebugOverlay
            store.showPerformanceMetrics = payload.showPerformanceMetrics
            store.dataGuardModeEnabled = payload.dataGuardModeEnabled
            store.barterLoggerEnabled = payload.barterLoggerEnabled
            store.antiScopeCreepEnabled = payload.antiScopeCreepEnabled
            store.agreementScratchpadEnabled = payload.agreementScratchpadEnabled
            store.agreementDefaultEnabledClauseIds = payload.agreementDefaultEnabledClauseIds
            store.agreementDefaultCustomTerms = payload.agreementDefaultCustomTerms
            store.sideHustleMatrixEnabled = payload.sideHustleMatrixEnabled
            store.showUnassignedExpensesInWorkspace = payload.showUnassignedExpensesInWorkspace
            store.paymentSourceTrackingEnabled = payload.paymentSourceTrackingEnabled
            store.dualCashDrawerEnabled = payload.dualCashDrawerEnabled
            store.cashLocalBalanceValue = payload.cashLocalBalanceValue
            store.cashSecondaryBalanceValue = payload.cashSecondaryBalanceValue
            // Tour progress is per-device UX state — never overwrite from iCloud.
        case .greeting:
            guard let payload = try? decoder.decode(SettingsGreetingDomain.self, from: record.data) else { return }
            store.greetingHeaderEnabled = payload.greetingHeaderEnabled
            store.greetingShowIcon = payload.greetingShowIcon
            store.greetingFontStyle = payload.greetingFontStyle
        case .subscriptions:
            guard let payload = try? decoder.decode(SettingsSubscriptionsDomain.self, from: record.data) else { return }
            store.cancelledSubscriptionMerchants = payload.cancelledSubscriptionMerchants
        }
    }

    private static func recordsConflictAcrossDevices(
        local: PersonalSettingsDomainRecord,
        remote: PersonalSettingsDomainRecord
    ) -> Bool {
        guard !local.deviceId.isEmpty, !remote.deviceId.isEmpty else { return false }
        return local.deviceId != remote.deviceId
    }

    private static func preferredDomainWhenHashesDiffer(
        local: PersonalSettingsDomainRecord,
        remote: PersonalSettingsDomainRecord,
        localHas: Bool,
        remoteHas: Bool
    ) -> PersonalSettingsDomainRecord {
        if remoteHas && !localHas { return remote }
        if localHas && !remoteHas { return local }
        if remote.updatedAt >= local.updatedAt { return remote }
        return local
    }
}

private struct SettingsStoreLegacyProbe: Decodable {
    var hasCompletedOnboarding: Bool?
    var personalCloudSyncEnabled: Bool?
}