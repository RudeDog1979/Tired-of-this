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
    
    // MARK: - Profile Settings
    @Published public var userDisplayName: String? = nil
    @Published public var profileAvatarData: Data? = nil
    @Published public var preferredNameStyle: PreferredNameStyle = .fullName
    
    // MARK: - Appearance Settings
    @Published public var themeMode: ThemeMode = .system
    @Published public var accentColorId: String = "Purple"
    @Published public var useGlassmorphism: Bool = true
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
    @Published public var freelanceEnabled: Bool = true
    @Published public var freelanceProfileId: UUID? = nil
    
    // MARK: - Notifications Settings
    @Published public var notificationsEnabled: Bool = true
    @Published public var budgetAlertsEnabled: Bool = true
    @Published public var billRemindersEnabled: Bool = true
    @Published public var freelanceInvoiceRemindersEnabled: Bool = true
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
    
    // MARK: - Data Settings
    @Published public var allowLocalBackups: Bool = true
    @Published public var autoBackupFrequency: AutoBackupFrequency = .weekly
    @Published public var includeFreelanceDataInExports: Bool = true
    @Published public var includeAnalyticsInExports: Bool = false
    @Published public var lastExportDate: Date? = nil
    
    // MARK: - Developer Options
    @Published public var enableDebugOverlay: Bool = false
    @Published public var showPerformanceMetrics: Bool = false
    
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
        let userDisplayName: String?
        let profileAvatarData: Data?
        let preferredNameStyle: PreferredNameStyle
        
        let themeMode: ThemeMode
        let accentColorId: String
        let useGlassmorphism: Bool
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
        
        let freelanceEnabled: Bool
        let freelanceProfileId: UUID?
        
        let notificationsEnabled: Bool
        let budgetAlertsEnabled: Bool
        let billRemindersEnabled: Bool
        let freelanceInvoiceRemindersEnabled: Bool
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
        
        let allowLocalBackups: Bool
        let autoBackupFrequency: AutoBackupFrequency
        let includeFreelanceDataInExports: Bool
        let includeAnalyticsInExports: Bool
        let lastExportDate: Date?
        
        let enableDebugOverlay: Bool
        let showPerformanceMetrics: Bool
    }
    
    public func loadStore() {
        guard !isLoaded else { return }
        let fm = FileManager.default
        let path = storeURL.path
        
        if fm.fileExists(atPath: path) {
            do {
                let data = try Data(contentsOf: storeURL)
                let payload = try JSONDecoder().decode(StorePayload.self, from: data)
                
                self.userDisplayName = payload.userDisplayName
                self.profileAvatarData = payload.profileAvatarData
                self.preferredNameStyle = payload.preferredNameStyle
                
                self.themeMode = payload.themeMode
                self.accentColorId = payload.accentColorId
                self.useGlassmorphism = payload.useGlassmorphism
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
                
                self.freelanceEnabled = payload.freelanceEnabled
                self.freelanceProfileId = payload.freelanceProfileId
                
                self.notificationsEnabled = payload.notificationsEnabled
                self.budgetAlertsEnabled = payload.budgetAlertsEnabled
                self.billRemindersEnabled = payload.billRemindersEnabled
                self.freelanceInvoiceRemindersEnabled = payload.freelanceInvoiceRemindersEnabled
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
                
                self.allowLocalBackups = payload.allowLocalBackups
                self.autoBackupFrequency = payload.autoBackupFrequency
                self.includeFreelanceDataInExports = payload.includeFreelanceDataInExports
                self.includeAnalyticsInExports = payload.includeAnalyticsInExports
                self.lastExportDate = payload.lastExportDate
                
                self.enableDebugOverlay = payload.enableDebugOverlay
                self.showPerformanceMetrics = payload.showPerformanceMetrics
                
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
        self.userDisplayName = nil
        self.themeMode = .system
        self.accentColorId = "Purple"
        self.weekStartDay = .monday
        self.budgetingMode = .simple
        self.defaultBudgetPeriod = .monthly
        self.freelanceEnabled = true
        self.notificationsEnabled = true
        self.biometricLockEnabled = false
        self.customBudgetProfiles = []
        self.simpleBudgetLimit = 1000
        self.customBudgetLimit = 50
        self.customBudgetPeriod = .weekly
        save()
    }
    
    public func save() {
        let payload = StorePayload(
            userDisplayName: userDisplayName,
            profileAvatarData: profileAvatarData,
            preferredNameStyle: preferredNameStyle,
            themeMode: themeMode,
            accentColorId: accentColorId,
            useGlassmorphism: useGlassmorphism,
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
            freelanceEnabled: freelanceEnabled,
            freelanceProfileId: freelanceProfileId,
            notificationsEnabled: notificationsEnabled,
            budgetAlertsEnabled: budgetAlertsEnabled,
            billRemindersEnabled: billRemindersEnabled,
            freelanceInvoiceRemindersEnabled: freelanceInvoiceRemindersEnabled,
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
            allowLocalBackups: allowLocalBackups,
            autoBackupFrequency: autoBackupFrequency,
            includeFreelanceDataInExports: includeFreelanceDataInExports,
            includeAnalyticsInExports: includeAnalyticsInExports,
            lastExportDate: lastExportDate,
            enableDebugOverlay: enableDebugOverlay,
            showPerformanceMetrics: showPerformanceMetrics
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            let url = storeURL
            saveQueue.async {
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    print("SettingsStore: failed to write JSON payload: \(error)")
                }
            }
        } catch {
            print("SettingsStore: failed to encode JSON payload: \(error)")
        }
    }
    
    // MARK: - Actions
    
    public func resetAllData() {
        // Clear passcode
        clearPasscode()
        // Re-seed defaults
        seedDefaults()
    }
}
