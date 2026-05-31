//
//  SettingsStore.swift
//  BuxMuse
//
//  Unified, thread-safe on-device Settings state store & persistent JSON repository.
//

import Foundation
import SwiftUI
import Combine

@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    
    /// Display name shown in UI when profile name is unset, respecting preferred name style.
    public var resolvedDisplayName: String {
        let f = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let l = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if preferredNameStyle == .firstName {
            return f.isEmpty ? (l.isEmpty ? "User" : l) : f
        } else {
            let combined = "\(f) \(l)".trimmingCharacters(in: .whitespacesAndNewlines)
            return combined.isEmpty ? "User" : combined
        }
    }

    // MARK: - Profile Settings
    @Published public var firstName: String? = nil
    @Published public var lastName: String? = nil
    
    public var userDisplayName: String? {
        let f = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let l = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combined = "\(f) \(l)".trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? nil : combined
    }
    
    @Published public var profileAvatarData: Data? = nil
    @Published public var preferredNameStyle: PreferredNameStyle = .fullName
    
    // MARK: - Appearance Settings
    @Published public var themeMode: ThemeMode = .system
    @Published public var accentColorId: String = AppTheme.buxDefault.name
    @Published public var neutralAccentId: String = BuxSystemAccent.systemBlue.rawValue
    @Published public var useGlassmorphism: Bool = true
    @Published public var brandThemesEnabled: Bool = true
    @Published public var reducedMotion: Bool = false
    
    // MARK: - Region Settings
    @Published public var weekStartDay: WeekStartDay = .monday
    
    // MARK: - Budget Settings
    @Published public var budgetingMode: BudgetingMode = .simple
    @Published public var defaultBudgetPeriod: DefaultBudgetPeriod = .monthly
    @Published public var showBudgetWarnings: Bool = true
    @Published public var autoAdjustBudgetsFromHistory: Bool = false
    @Published public var customBudgetProfiles: [CustomBudgetProfile] = []
    @Published public var simpleBudgetLimit: Decimal = 1000
    @Published public var customBudgetLimit: Decimal = 50
    @Published public var customBudgetPeriod: DefaultBudgetPeriod = .weekly
    
    // MARK: - Freelance Settings
    @Published public var studioEnabled: Bool = false
    /// Home banner dismissed; separate from main settings payload.
    @Published public var studioDiscoveryOfferDismissed: Bool = false
    @Published public var studioProfileId: UUID? = nil
    /// Simple (default) vs Pro Studio presentation.
    @Published public var studioMode: StudioMode = .simple
    @Published public var studioPersona: StudioPersona = .other
    @Published public var studioPersonaConfigured: Bool = false
    
    // MARK: - Notifications Settings
    @Published public var notificationsEnabled: Bool = true
    @Published public var budgetAlertsEnabled: Bool = true
    @Published public var billRemindersEnabled: Bool = true
    @Published public var studioInvoiceRemindersEnabled: Bool = true
    @Published public var taxDeadlineRemindersEnabled: Bool = true
    @Published public var dailySummaryEnabled: Bool = false
    @Published public var quietHoursStartHour: Int = 22
    @Published public var quietHoursStartMinute: Int = 0
    @Published public var quietHoursEndHour: Int = 7
    @Published public var quietHoursEndMinute: Int = 0
    
    // MARK: - Security Settings
    @Published public var biometricLockEnabled: Bool = false
    @Published public var requireBiometricOnLaunch: Bool = false
    @Published public var lockAfterInactivityMinutes: Int = 1 // 1 minute
    @Published public var privacyBlurInAppSwitching: Bool = true
    @Published public var cancelledSubscriptionMerchants: [String] = []

    // MARK: - Data Settings
    @Published public var allowLocalBackups: Bool = true
    @Published public var autoBackupFrequency: AutoBackupFrequency = .weekly
    @Published public var includeStudioDataInExports: Bool = true
    @Published public var includeAnalyticsInExports: Bool = false
    @Published public var lastExportDate: Date? = nil
    
    // MARK: - Developer Options
    @Published public var enableDebugOverlay: Bool = false
    @Published public var showPerformanceMetrics: Bool = false

    // MARK: - Invoice payment (Settings → Studio invoices)
    @Published public var autoDetectInvoiceBankAccountType: Bool = true
    @Published public var invoiceBankAccountTypeOverride: BankAccountType? = nil

    // MARK: - Studio mileage
    @Published public var autoLocationForMileage: Bool = false
    @Published public var mileageRatePerUnitValue: Double = 0.45

    public var mileageRatePerUnit: Decimal {
        Decimal(mileageRatePerUnitValue)
    }
    
    private let saveQueue = DispatchQueue(label: "com.buxmuse.settings.save", qos: .utility)
    private var isLoaded = false
    
    private init() {
        loadStore()
    }
    
    // MARK: - Derived Security Accessors
    
    public var hasAppPasscode: Bool {
        KeychainHelper.shared.retrievePasscode() != nil
    }
    
    public func setPasscode(_ passcode: String) {
        KeychainHelper.shared.savePasscode(passcode)
        objectWillChange.send()
    }
    
    public func clearPasscode() {
        KeychainHelper.shared.deletePasscode()
        objectWillChange.send()
    }

    public func registerCancelledSubscription(normalizedMerchant: String) {
        guard !normalizedMerchant.isEmpty else { return }
        if !cancelledSubscriptionMerchants.contains(normalizedMerchant) {
            cancelledSubscriptionMerchants.append(normalizedMerchant)
            UserDefaults.standard.set(cancelledSubscriptionMerchants, forKey: Self.cancelledSubscriptionsDefaultsKey)
            save()
        }
    }

    public func isSubscriptionCancelled(normalizedMerchant: String) -> Bool {
        cancelledSubscriptionMerchants.contains(normalizedMerchant)
    }

    public func clearCancelledSubscription(normalizedMerchant: String) {
        guard !normalizedMerchant.isEmpty else { return }
        let updated = cancelledSubscriptionMerchants.filter { $0 != normalizedMerchant }
        guard updated.count != cancelledSubscriptionMerchants.count else { return }
        cancelledSubscriptionMerchants = updated
        UserDefaults.standard.set(cancelledSubscriptionMerchants, forKey: Self.cancelledSubscriptionsDefaultsKey)
        save()
    }

    private static let cancelledSubscriptionsDefaultsKey = "buxmuse.cancelledSubscriptionMerchants"
    private static let autoDetectInvoiceBankKey = "buxmuse.settings.autoDetectInvoiceBankType"
    private static let invoiceBankOverrideKey = "buxmuse.settings.invoiceBankTypeOverride"
    private static let autoLocationMileageKey = "buxmuse.settings.autoLocationForMileage"
    private static let mileageRateKey = "buxmuse.settings.mileageRatePerUnit"
    
    // MARK: - Local Persistence URLs
    
    private var storeURL: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let settingsDir = appSupport.appendingPathComponent("Settings", isDirectory: true)
        
        if !fm.fileExists(atPath: settingsDir.path) {
            try? fm.createDirectory(at: settingsDir, withIntermediateDirectories: true, attributes: nil)
        }
        return settingsDir.appendingPathComponent("settings_store_v1.json")
    }
    
    // MARK: - Saving & Loading Schema
    
    private struct StorePayload: Codable {
        let firstName: String?
        let lastName: String?
        let userDisplayName: String?
        let profileAvatarData: Data?
        let preferredNameStyle: PreferredNameStyle
        
        let themeMode: ThemeMode
        let accentColorId: String
        let neutralAccentId: String?
        let useGlassmorphism: Bool
        let brandThemesEnabled: Bool?
        let reducedMotion: Bool
        
        let weekStartDay: WeekStartDay
        
        let budgetingMode: BudgetingMode
        let defaultBudgetPeriod: DefaultBudgetPeriod
        let showBudgetWarnings: Bool
        let autoAdjustBudgetsFromHistory: Bool
        let customBudgetProfiles: [CustomBudgetProfile]
        let simpleBudgetLimit: Decimal?
        let customBudgetLimit: Decimal?
        let customBudgetPeriod: DefaultBudgetPeriod?
        
        let studioEnabled: Bool
        let studioProfileId: UUID?
        let studioMode: StudioMode?
        let studioPersona: StudioPersona?
        let studioPersonaConfigured: Bool?
        
        let notificationsEnabled: Bool
        let budgetAlertsEnabled: Bool
        let billRemindersEnabled: Bool
        let studioInvoiceRemindersEnabled: Bool
        let taxDeadlineRemindersEnabled: Bool
        let dailySummaryEnabled: Bool
        let quietHoursStartHour: Int
        let quietHoursStartMinute: Int
        let quietHoursEndHour: Int
        let quietHoursEndMinute: Int
        
        let biometricLockEnabled: Bool
        let requireBiometricOnLaunch: Bool
        let lockAfterInactivityMinutes: Int
        let privacyBlurInAppSwitching: Bool
        let cancelledSubscriptionMerchants: [String]?
        
        let allowLocalBackups: Bool
        let autoBackupFrequency: AutoBackupFrequency
        let includeStudioDataInExports: Bool
        let includeAnalyticsInExports: Bool
        let lastExportDate: Date?
        
        let enableDebugOverlay: Bool
        let showPerformanceMetrics: Bool

        enum CodingKeys: String, CodingKey {
            case firstName, lastName, userDisplayName, profileAvatarData, preferredNameStyle
            case themeMode, accentColorId, neutralAccentId, useGlassmorphism, brandThemesEnabled, reducedMotion
            case weekStartDay, budgetingMode, defaultBudgetPeriod
            case showBudgetWarnings, autoAdjustBudgetsFromHistory, customBudgetProfiles
            case simpleBudgetLimit, customBudgetLimit, customBudgetPeriod
            case studioEnabled, freelanceEnabled
            case studioProfileId, freelanceProfileId
            case studioMode, studioPersona, studioPersonaConfigured
            case notificationsEnabled, budgetAlertsEnabled, billRemindersEnabled
            case studioInvoiceRemindersEnabled, freelanceInvoiceRemindersEnabled
            case taxDeadlineRemindersEnabled, dailySummaryEnabled
            case quietHoursStartHour, quietHoursStartMinute, quietHoursEndHour, quietHoursEndMinute
            case biometricLockEnabled, requireBiometricOnLaunch, lockAfterInactivityMinutes
            case privacyBlurInAppSwitching, cancelledSubscriptionMerchants
            case allowLocalBackups, autoBackupFrequency
            case includeStudioDataInExports, includeFreelanceDataInExports
            case includeAnalyticsInExports, lastExportDate
            case enableDebugOverlay, showPerformanceMetrics
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            
            let decodedFirstName = try c.decodeIfPresent(String.self, forKey: .firstName)
            let decodedLastName = try c.decodeIfPresent(String.self, forKey: .lastName)
            let rawUserDisplayName = try c.decodeIfPresent(String.self, forKey: .userDisplayName)
            
            if decodedFirstName != nil || decodedLastName != nil {
                self.firstName = decodedFirstName
                self.lastName = decodedLastName
                self.userDisplayName = rawUserDisplayName ?? "\(decodedFirstName ?? "") \(decodedLastName ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let rawUserDisplayName = rawUserDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !rawUserDisplayName.isEmpty {
                let components = rawUserDisplayName.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                if components.count > 1 {
                    self.firstName = components.first
                    self.lastName = components.dropFirst().joined(separator: " ")
                } else {
                    self.firstName = components.first
                    self.lastName = nil
                }
                self.userDisplayName = rawUserDisplayName
            } else {
                self.firstName = nil
                self.lastName = nil
                self.userDisplayName = nil
            }
            
            profileAvatarData = try c.decodeIfPresent(Data.self, forKey: .profileAvatarData)
            preferredNameStyle = try c.decode(PreferredNameStyle.self, forKey: .preferredNameStyle)
            themeMode = try c.decode(ThemeMode.self, forKey: .themeMode)
            accentColorId = try c.decode(String.self, forKey: .accentColorId)
            neutralAccentId = try c.decodeIfPresent(String.self, forKey: .neutralAccentId) ?? BuxSystemAccent.systemBlue.rawValue
            useGlassmorphism = try c.decode(Bool.self, forKey: .useGlassmorphism)
            brandThemesEnabled = try c.decodeIfPresent(Bool.self, forKey: .brandThemesEnabled) ?? true
            reducedMotion = try c.decode(Bool.self, forKey: .reducedMotion)
            weekStartDay = try c.decode(WeekStartDay.self, forKey: .weekStartDay)
            budgetingMode = try c.decode(BudgetingMode.self, forKey: .budgetingMode)
            defaultBudgetPeriod = try c.decode(DefaultBudgetPeriod.self, forKey: .defaultBudgetPeriod)
            showBudgetWarnings = try c.decode(Bool.self, forKey: .showBudgetWarnings)
            autoAdjustBudgetsFromHistory = try c.decode(Bool.self, forKey: .autoAdjustBudgetsFromHistory)
            customBudgetProfiles = try c.decode([CustomBudgetProfile].self, forKey: .customBudgetProfiles)
            simpleBudgetLimit = try c.decodeIfPresent(Decimal.self, forKey: .simpleBudgetLimit)
            customBudgetLimit = try c.decodeIfPresent(Decimal.self, forKey: .customBudgetLimit)
            customBudgetPeriod = try c.decodeIfPresent(DefaultBudgetPeriod.self, forKey: .customBudgetPeriod)
            studioEnabled = try c.decodeIfPresent(Bool.self, forKey: .studioEnabled)
                ?? c.decodeIfPresent(Bool.self, forKey: .freelanceEnabled) ?? false
            studioProfileId = try c.decodeIfPresent(UUID.self, forKey: .studioProfileId)
                ?? c.decodeIfPresent(UUID.self, forKey: .freelanceProfileId)
            self.studioMode = try c.decodeIfPresent(StudioMode.self, forKey: .studioMode) ?? .simple
            self.studioPersona = try c.decodeIfPresent(StudioPersona.self, forKey: .studioPersona) ?? .other
            self.studioPersonaConfigured = try c.decodeIfPresent(Bool.self, forKey: .studioPersonaConfigured) ?? false
            notificationsEnabled = try c.decode(Bool.self, forKey: .notificationsEnabled)
            budgetAlertsEnabled = try c.decode(Bool.self, forKey: .budgetAlertsEnabled)
            billRemindersEnabled = try c.decode(Bool.self, forKey: .billRemindersEnabled)
            studioInvoiceRemindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .studioInvoiceRemindersEnabled)
                ?? c.decodeIfPresent(Bool.self, forKey: .freelanceInvoiceRemindersEnabled) ?? true
            taxDeadlineRemindersEnabled = try c.decode(Bool.self, forKey: .taxDeadlineRemindersEnabled)
            dailySummaryEnabled = try c.decode(Bool.self, forKey: .dailySummaryEnabled)
            quietHoursStartHour = try c.decode(Int.self, forKey: .quietHoursStartHour)
            quietHoursStartMinute = try c.decode(Int.self, forKey: .quietHoursStartMinute)
            quietHoursEndHour = try c.decode(Int.self, forKey: .quietHoursEndHour)
            quietHoursEndMinute = try c.decode(Int.self, forKey: .quietHoursEndMinute)
            biometricLockEnabled = try c.decode(Bool.self, forKey: .biometricLockEnabled)
            requireBiometricOnLaunch = try c.decode(Bool.self, forKey: .requireBiometricOnLaunch)
            lockAfterInactivityMinutes = try c.decode(Int.self, forKey: .lockAfterInactivityMinutes)
            privacyBlurInAppSwitching = try c.decode(Bool.self, forKey: .privacyBlurInAppSwitching)
            cancelledSubscriptionMerchants = try c.decodeIfPresent([String].self, forKey: .cancelledSubscriptionMerchants)
            allowLocalBackups = try c.decode(Bool.self, forKey: .allowLocalBackups)
            autoBackupFrequency = try c.decode(AutoBackupFrequency.self, forKey: .autoBackupFrequency)
            includeStudioDataInExports = try c.decodeIfPresent(Bool.self, forKey: .includeStudioDataInExports)
                ?? c.decodeIfPresent(Bool.self, forKey: .includeFreelanceDataInExports) ?? true
            includeAnalyticsInExports = try c.decode(Bool.self, forKey: .includeAnalyticsInExports)
            lastExportDate = try c.decodeIfPresent(Date.self, forKey: .lastExportDate)
            enableDebugOverlay = try c.decode(Bool.self, forKey: .enableDebugOverlay)
            showPerformanceMetrics = try c.decode(Bool.self, forKey: .showPerformanceMetrics)
        }

        init(
            firstName: String?,
            lastName: String?,
            userDisplayName: String?,
            profileAvatarData: Data?,
            preferredNameStyle: PreferredNameStyle,
            themeMode: ThemeMode,
            accentColorId: String,
            neutralAccentId: String,
            useGlassmorphism: Bool,
            brandThemesEnabled: Bool,
            reducedMotion: Bool,
            weekStartDay: WeekStartDay,
            budgetingMode: BudgetingMode,
            defaultBudgetPeriod: DefaultBudgetPeriod,
            showBudgetWarnings: Bool,
            autoAdjustBudgetsFromHistory: Bool,
            customBudgetProfiles: [CustomBudgetProfile],
            simpleBudgetLimit: Decimal?,
            customBudgetLimit: Decimal?,
            customBudgetPeriod: DefaultBudgetPeriod?,
            studioEnabled: Bool,
            studioProfileId: UUID?,
            studioMode: StudioMode?,
            studioPersona: StudioPersona?,
            studioPersonaConfigured: Bool?,
            notificationsEnabled: Bool,
            budgetAlertsEnabled: Bool,
            billRemindersEnabled: Bool,
            studioInvoiceRemindersEnabled: Bool,
            taxDeadlineRemindersEnabled: Bool,
            dailySummaryEnabled: Bool,
            quietHoursStartHour: Int,
            quietHoursStartMinute: Int,
            quietHoursEndHour: Int,
            quietHoursEndMinute: Int,
            biometricLockEnabled: Bool,
            requireBiometricOnLaunch: Bool,
            lockAfterInactivityMinutes: Int,
            privacyBlurInAppSwitching: Bool,
            cancelledSubscriptionMerchants: [String]?,
            allowLocalBackups: Bool,
            autoBackupFrequency: AutoBackupFrequency,
            includeStudioDataInExports: Bool,
            includeAnalyticsInExports: Bool,
            lastExportDate: Date?,
            enableDebugOverlay: Bool,
            showPerformanceMetrics: Bool
        ) {
            self.firstName = firstName
            self.lastName = lastName
            self.userDisplayName = userDisplayName
            self.profileAvatarData = profileAvatarData
            self.preferredNameStyle = preferredNameStyle
            self.themeMode = themeMode
            self.accentColorId = accentColorId
            self.neutralAccentId = neutralAccentId
            self.useGlassmorphism = useGlassmorphism
            self.brandThemesEnabled = brandThemesEnabled
            self.reducedMotion = reducedMotion
            self.weekStartDay = weekStartDay
            self.budgetingMode = budgetingMode
            self.defaultBudgetPeriod = defaultBudgetPeriod
            self.showBudgetWarnings = showBudgetWarnings
            self.autoAdjustBudgetsFromHistory = autoAdjustBudgetsFromHistory
            self.customBudgetProfiles = customBudgetProfiles
            self.simpleBudgetLimit = simpleBudgetLimit
            self.customBudgetLimit = customBudgetLimit
            self.customBudgetPeriod = customBudgetPeriod
            self.studioEnabled = studioEnabled
            self.studioProfileId = studioProfileId
            self.studioMode = studioMode
            self.studioPersona = studioPersona
            self.studioPersonaConfigured = studioPersonaConfigured
            self.notificationsEnabled = notificationsEnabled
            self.budgetAlertsEnabled = budgetAlertsEnabled
            self.billRemindersEnabled = billRemindersEnabled
            self.studioInvoiceRemindersEnabled = studioInvoiceRemindersEnabled
            self.taxDeadlineRemindersEnabled = taxDeadlineRemindersEnabled
            self.dailySummaryEnabled = dailySummaryEnabled
            self.quietHoursStartHour = quietHoursStartHour
            self.quietHoursStartMinute = quietHoursStartMinute
            self.quietHoursEndHour = quietHoursEndHour
            self.quietHoursEndMinute = quietHoursEndMinute
            self.biometricLockEnabled = biometricLockEnabled
            self.requireBiometricOnLaunch = requireBiometricOnLaunch
            self.lockAfterInactivityMinutes = lockAfterInactivityMinutes
            self.privacyBlurInAppSwitching = privacyBlurInAppSwitching
            self.cancelledSubscriptionMerchants = cancelledSubscriptionMerchants
            self.allowLocalBackups = allowLocalBackups
            self.autoBackupFrequency = autoBackupFrequency
            self.includeStudioDataInExports = includeStudioDataInExports
            self.includeAnalyticsInExports = includeAnalyticsInExports
            self.lastExportDate = lastExportDate
            self.enableDebugOverlay = enableDebugOverlay
            self.showPerformanceMetrics = showPerformanceMetrics
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(firstName, forKey: .firstName)
            try c.encodeIfPresent(lastName, forKey: .lastName)
            try c.encodeIfPresent(userDisplayName, forKey: .userDisplayName)
            try c.encodeIfPresent(profileAvatarData, forKey: .profileAvatarData)
            try c.encode(preferredNameStyle, forKey: .preferredNameStyle)
            try c.encode(themeMode, forKey: .themeMode)
            try c.encode(accentColorId, forKey: .accentColorId)
            try c.encode(neutralAccentId, forKey: .neutralAccentId)
            try c.encode(useGlassmorphism, forKey: .useGlassmorphism)
            try c.encode(brandThemesEnabled, forKey: .brandThemesEnabled)
            try c.encode(reducedMotion, forKey: .reducedMotion)
            try c.encode(weekStartDay, forKey: .weekStartDay)
            try c.encode(budgetingMode, forKey: .budgetingMode)
            try c.encode(defaultBudgetPeriod, forKey: .defaultBudgetPeriod)
            try c.encode(showBudgetWarnings, forKey: .showBudgetWarnings)
            try c.encode(autoAdjustBudgetsFromHistory, forKey: .autoAdjustBudgetsFromHistory)
            try c.encode(customBudgetProfiles, forKey: .customBudgetProfiles)
            try c.encodeIfPresent(simpleBudgetLimit, forKey: .simpleBudgetLimit)
            try c.encodeIfPresent(customBudgetLimit, forKey: .customBudgetLimit)
            try c.encodeIfPresent(customBudgetPeriod, forKey: .customBudgetPeriod)
            try c.encode(studioEnabled, forKey: .studioEnabled)
            try c.encodeIfPresent(studioProfileId, forKey: .studioProfileId)
            try c.encodeIfPresent(studioMode, forKey: .studioMode)
            try c.encodeIfPresent(studioPersona, forKey: .studioPersona)
            try c.encodeIfPresent(studioPersonaConfigured, forKey: .studioPersonaConfigured)
            try c.encode(notificationsEnabled, forKey: .notificationsEnabled)
            try c.encode(budgetAlertsEnabled, forKey: .budgetAlertsEnabled)
            try c.encode(billRemindersEnabled, forKey: .billRemindersEnabled)
            try c.encode(studioInvoiceRemindersEnabled, forKey: .studioInvoiceRemindersEnabled)
            try c.encode(taxDeadlineRemindersEnabled, forKey: .taxDeadlineRemindersEnabled)
            try c.encode(dailySummaryEnabled, forKey: .dailySummaryEnabled)
            try c.encode(quietHoursStartHour, forKey: .quietHoursStartHour)
            try c.encode(quietHoursStartMinute, forKey: .quietHoursStartMinute)
            try c.encode(quietHoursEndHour, forKey: .quietHoursEndHour)
            try c.encode(quietHoursEndMinute, forKey: .quietHoursEndMinute)
            try c.encode(biometricLockEnabled, forKey: .biometricLockEnabled)
            try c.encode(requireBiometricOnLaunch, forKey: .requireBiometricOnLaunch)
            try c.encode(lockAfterInactivityMinutes, forKey: .lockAfterInactivityMinutes)
            try c.encode(privacyBlurInAppSwitching, forKey: .privacyBlurInAppSwitching)
            try c.encodeIfPresent(cancelledSubscriptionMerchants, forKey: .cancelledSubscriptionMerchants)
            try c.encode(allowLocalBackups, forKey: .allowLocalBackups)
            try c.encode(autoBackupFrequency, forKey: .autoBackupFrequency)
            try c.encode(includeStudioDataInExports, forKey: .includeStudioDataInExports)
            try c.encode(includeAnalyticsInExports, forKey: .includeAnalyticsInExports)
            try c.encodeIfPresent(lastExportDate, forKey: .lastExportDate)
            try c.encode(enableDebugOverlay, forKey: .enableDebugOverlay)
            try c.encode(showPerformanceMetrics, forKey: .showPerformanceMetrics)
        }
    }
    
    /// Legacy accent keys → current theme names.
    private static func normalizeAccentColorId(_ raw: String) -> String {
        switch raw {
        case "Bux Default", "buxDefault":
            return AppTheme.buxDefault.name
        default:
            if AppTheme.all.contains(where: { $0.name == raw || $0.id == raw }) {
                return AppTheme.all.first(where: { $0.name == raw || $0.id == raw })?.name ?? raw
            }
            return raw
        }
    }

    public func loadStore() {
        guard !isLoaded else { return }
        let fm = FileManager.default
        let path = storeURL.path
        
        if fm.fileExists(atPath: path) {
            do {
                let data = try Data(contentsOf: storeURL)
                let payload = try JSONDecoder().decode(StorePayload.self, from: data)
                
                self.firstName = payload.firstName
                self.lastName = payload.lastName
                self.profileAvatarData = payload.profileAvatarData
                self.preferredNameStyle = payload.preferredNameStyle
                
                self.themeMode = payload.themeMode
                self.accentColorId = Self.normalizeAccentColorId(payload.accentColorId)
                self.neutralAccentId = payload.neutralAccentId ?? BuxSystemAccent.systemBlue.rawValue
                self.useGlassmorphism = payload.useGlassmorphism
                self.brandThemesEnabled = payload.brandThemesEnabled ?? true
                self.reducedMotion = payload.reducedMotion
                
                self.weekStartDay = payload.weekStartDay
                
                self.budgetingMode = payload.budgetingMode
                self.defaultBudgetPeriod = payload.defaultBudgetPeriod
                self.showBudgetWarnings = payload.showBudgetWarnings
                self.autoAdjustBudgetsFromHistory = payload.autoAdjustBudgetsFromHistory
                self.customBudgetProfiles = payload.customBudgetProfiles.filter { $0.name != "Standard Essentials" }
                self.simpleBudgetLimit = payload.simpleBudgetLimit ?? 1000
                self.customBudgetLimit = payload.customBudgetLimit ?? 50
                self.customBudgetPeriod = payload.customBudgetPeriod ?? .weekly
                
                self.studioEnabled = payload.studioEnabled
                self.studioProfileId = payload.studioProfileId
                self.studioMode = payload.studioMode ?? .simple
                self.studioPersona = payload.studioPersona ?? .other
                self.studioPersonaConfigured = payload.studioPersonaConfigured ?? false
                
                self.notificationsEnabled = payload.notificationsEnabled
                self.budgetAlertsEnabled = payload.budgetAlertsEnabled
                self.billRemindersEnabled = payload.billRemindersEnabled
                self.studioInvoiceRemindersEnabled = payload.studioInvoiceRemindersEnabled
                self.taxDeadlineRemindersEnabled = payload.taxDeadlineRemindersEnabled
                self.dailySummaryEnabled = payload.dailySummaryEnabled
                self.quietHoursStartHour = payload.quietHoursStartHour
                self.quietHoursStartMinute = payload.quietHoursStartMinute
                self.quietHoursEndHour = payload.quietHoursEndHour
                self.quietHoursEndMinute = payload.quietHoursEndMinute
                
                self.biometricLockEnabled = payload.biometricLockEnabled
                self.requireBiometricOnLaunch = payload.requireBiometricOnLaunch
                self.lockAfterInactivityMinutes = payload.lockAfterInactivityMinutes
                self.privacyBlurInAppSwitching = payload.privacyBlurInAppSwitching
                self.cancelledSubscriptionMerchants = payload.cancelledSubscriptionMerchants ?? []
                UserDefaults.standard.set(self.cancelledSubscriptionMerchants, forKey: Self.cancelledSubscriptionsDefaultsKey)
                
                self.allowLocalBackups = payload.allowLocalBackups
                self.autoBackupFrequency = payload.autoBackupFrequency
                self.includeStudioDataInExports = payload.includeStudioDataInExports
                self.includeAnalyticsInExports = payload.includeAnalyticsInExports
                self.lastExportDate = payload.lastExportDate
                
                self.enableDebugOverlay = payload.enableDebugOverlay
                self.showPerformanceMetrics = payload.showPerformanceMetrics

                loadInvoicePaymentPreferences()
                loadMileagePreferences()
                loadStudioDiscoveryPreference()
                
                self.isLoaded = true
                print("SettingsStore: successfully loaded settings.")
                return
            } catch {
                print("SettingsStore: decoding error (\(error)). Setting up defaults.")
            }
        }
        
        // Defaults seed
        seedDefaults()
        self.isLoaded = true
    }
    
    private func seedDefaults() {
        self.firstName = nil
        self.lastName = nil
        self.themeMode = .system
        self.accentColorId = AppTheme.buxDefault.name
        self.neutralAccentId = BuxSystemAccent.systemBlue.rawValue
        self.weekStartDay = .monday
        self.budgetingMode = .simple
        self.defaultBudgetPeriod = .monthly
        self.studioEnabled = false
        self.notificationsEnabled = true
        self.biometricLockEnabled = false
        self.customBudgetProfiles = []
        self.simpleBudgetLimit = 1000
        self.customBudgetLimit = 50
        self.customBudgetPeriod = .weekly
        loadInvoicePaymentPreferences()
        loadMileagePreferences()
        loadStudioDiscoveryPreference()
        save()
    }

    private static let studioDiscoveryDismissedKey = "studio_discovery_offer_dismissed"

    public func dismissStudioDiscoveryOffer() {
        studioDiscoveryOfferDismissed = true
        UserDefaults.standard.set(true, forKey: Self.studioDiscoveryDismissedKey)
    }

    private func loadStudioDiscoveryPreference() {
        studioDiscoveryOfferDismissed = UserDefaults.standard.bool(forKey: Self.studioDiscoveryDismissedKey)
    }

    private func loadMileagePreferences() {
        if UserDefaults.standard.object(forKey: Self.autoLocationMileageKey) != nil {
            autoLocationForMileage = UserDefaults.standard.bool(forKey: Self.autoLocationMileageKey)
        }
        if UserDefaults.standard.object(forKey: Self.mileageRateKey) != nil {
            mileageRatePerUnitValue = UserDefaults.standard.double(forKey: Self.mileageRateKey)
        }
    }

    private func persistMileagePreferences() {
        UserDefaults.standard.set(autoLocationForMileage, forKey: Self.autoLocationMileageKey)
        UserDefaults.standard.set(mileageRatePerUnitValue, forKey: Self.mileageRateKey)
    }

    private func loadInvoicePaymentPreferences() {
        if UserDefaults.standard.object(forKey: Self.autoDetectInvoiceBankKey) != nil {
            autoDetectInvoiceBankAccountType = UserDefaults.standard.bool(forKey: Self.autoDetectInvoiceBankKey)
        }
        if let raw = UserDefaults.standard.string(forKey: Self.invoiceBankOverrideKey),
           let type = BankAccountType(rawValue: raw) {
            invoiceBankAccountTypeOverride = type
        }
    }

    private func persistInvoicePaymentPreferences() {
        UserDefaults.standard.set(autoDetectInvoiceBankAccountType, forKey: Self.autoDetectInvoiceBankKey)
        if let override = invoiceBankAccountTypeOverride {
            UserDefaults.standard.set(override.rawValue, forKey: Self.invoiceBankOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.invoiceBankOverrideKey)
        }
    }
    
    public func save() {
        persistInvoicePaymentPreferences()
        persistMileagePreferences()
        let payload = StorePayload(
            firstName: firstName,
            lastName: lastName,
            userDisplayName: userDisplayName,
            profileAvatarData: profileAvatarData,
            preferredNameStyle: preferredNameStyle,
            themeMode: themeMode,
            accentColorId: accentColorId,
            neutralAccentId: neutralAccentId,
            useGlassmorphism: useGlassmorphism,
            brandThemesEnabled: brandThemesEnabled,
            reducedMotion: reducedMotion,
            weekStartDay: weekStartDay,
            budgetingMode: budgetingMode,
            defaultBudgetPeriod: defaultBudgetPeriod,
            showBudgetWarnings: showBudgetWarnings,
            autoAdjustBudgetsFromHistory: autoAdjustBudgetsFromHistory,
            customBudgetProfiles: customBudgetProfiles,
            simpleBudgetLimit: simpleBudgetLimit,
            customBudgetLimit: customBudgetLimit,
            customBudgetPeriod: customBudgetPeriod,
            studioEnabled: studioEnabled,
            studioProfileId: studioProfileId,
            studioMode: studioMode,
            studioPersona: studioPersona,
            studioPersonaConfigured: studioPersonaConfigured,
            notificationsEnabled: notificationsEnabled,
            budgetAlertsEnabled: budgetAlertsEnabled,
            billRemindersEnabled: billRemindersEnabled,
            studioInvoiceRemindersEnabled: studioInvoiceRemindersEnabled,
            taxDeadlineRemindersEnabled: taxDeadlineRemindersEnabled,
            dailySummaryEnabled: dailySummaryEnabled,
            quietHoursStartHour: quietHoursStartHour,
            quietHoursStartMinute: quietHoursStartMinute,
            quietHoursEndHour: quietHoursEndHour,
            quietHoursEndMinute: quietHoursEndMinute,
            biometricLockEnabled: biometricLockEnabled,
            requireBiometricOnLaunch: requireBiometricOnLaunch,
            lockAfterInactivityMinutes: lockAfterInactivityMinutes,
            privacyBlurInAppSwitching: privacyBlurInAppSwitching,
            cancelledSubscriptionMerchants: cancelledSubscriptionMerchants,
            allowLocalBackups: allowLocalBackups,
            autoBackupFrequency: autoBackupFrequency,
            includeStudioDataInExports: includeStudioDataInExports,
            includeAnalyticsInExports: includeAnalyticsInExports,
            lastExportDate: lastExportDate,
            enableDebugOverlay: enableDebugOverlay,
            showPerformanceMetrics: showPerformanceMetrics
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storeURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("SettingsStore: failed to save JSON payload: \(error)")
        }
    }
    
    // MARK: - Actions
    
    public func resetAllData() {
        // Clear passcode
        clearPasscode()
        // Re-seed defaults
        seedDefaults()
    }

    // MARK: - Brand themes

    func resolvedBrandTheme() -> AppTheme {
        AppTheme.all.first(where: { $0.name == accentColorId })
            ?? AppTheme.all.first(where: { $0.id == accentColorId })
            ?? .buxDefault
    }

    func resolvedSystemAccent() -> BuxSystemAccent {
        BuxSystemAccent.resolve(id: neutralAccentId)
    }

    func resolvedSystemAccentColor(for colorScheme: ColorScheme) -> Color {
        resolvedSystemAccent().color(for: colorScheme)
    }

    func resolvedAppearanceSummary(themeManager: ThemeManager) -> String {
        if brandThemesEnabled {
            return themeManager.current.name
        }
        return resolvedSystemAccent().displayName
    }

    func applyBrandThemesAppearance(to themeManager: ThemeManager) {
        if brandThemesEnabled {
            themeManager.applyTheme(resolvedBrandTheme())
        } else {
            themeManager.applyTheme(AppTheme.standardNeutral(accent: resolvedSystemAccent()))
        }
    }

    /// Persist appearance + sync ThemeManager (call from theme picker).
    func persistThemeSelection(_ theme: AppTheme, themeManager: ThemeManager) {
        accentColorId = theme.name
        themeManager.applyTheme(theme)
        save()
    }
}
