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
    @Published public var brandThemesEnabled: Bool = false
    @Published public var landingBackdropEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "buxmuse.landingBackdrop.enabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "buxmuse.landingBackdrop.enabled")
    }() {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(landingBackdropEnabled, forKey: "buxmuse.landingBackdrop.enabled")
        }
    }
    @Published public var showVisualHorizonBackground: Bool = {
        if UserDefaults.standard.object(forKey: "buxmuse.showVisualHorizonBackground") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "buxmuse.showVisualHorizonBackground")
    }() {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(showVisualHorizonBackground, forKey: "buxmuse.showVisualHorizonBackground")
        }
    }
    @Published public var reducedMotion: Bool = false
    @Published public var solarContrastModeEnabled: Bool = false
    
    // MARK: - Region Settings
    @Published public var weekStartDay: WeekStartDay = .monday
    
    // MARK: - Budget Settings
    @Published public var budgetingMode: BudgetingMode = .simple
    @Published public var defaultBudgetPeriod: DefaultBudgetPeriod = .monthly
    @Published public var showBudgetWarnings: Bool = true
    @Published public var autoAdjustBudgetsFromHistory: Bool = false
    @Published public var customBudgetProfiles: [CustomBudgetProfile] = []
    @Published public var simpleBudgetLimit: Decimal = 1000
    @Published public var simpleBudgetCycle: SimpleBudgetCycle = .monthFirst
    @Published public var simpleBudgetPeriodAnchor: Date = Date()
    @Published public var incomeFundingSource: IncomeFundingSource = .other
    /// When enabled, Simple Studio money-in entries count toward Standard budget earned income for the pay period.
    @Published public var includeSimpleStudioIncomeInBudget: Bool = false
    /// When enabled, paid Pro Studio invoices count toward Standard budget earned income for the pay period.
    @Published public var includeProStudioIncomeInBudget: Bool = false
    @Published public var customBudgetLimit: Decimal = 50
    @Published public var customBudgetPeriod: DefaultBudgetPeriod = .weekly
    @Published public var budgetApproachingThresholdPercent: Int = 80
    
    // MARK: - Freelance Settings
    @Published public var studioEnabled: Bool = false
    /// Home banner dismissed; separate from main settings payload.
    @Published public var studioDiscoveryOfferDismissed: Bool = false
    /// Dismisses the Standard budget ↔ Simple Studio bridge prompt on Home / Studio.
    @Published public var standardBudgetStudioBridgePromptDismissed: Bool = UserDefaults.standard.bool(forKey: "buxmuse.standardBudgetStudioBridgePromptDismissed") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(standardBudgetStudioBridgePromptDismissed, forKey: Self.standardBudgetStudioBridgePromptDismissedKey)
        }
    }
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
    
    // MARK: - Workspace Preferences Settings
    @Published public var burnoutGuardEnabled: Bool = true
    @Published public var healthKitSyncEnabled: Bool = false
    @Published public var hasAcknowledgedHealthKitDisclaimer: Bool = false
    @Published public var manualSleepHours: Double = 7.5
    @Published public var manualStressLevel: Double = 5.0
    
    // MARK: - Data Guard Mode Settings
    @Published public var dataGuardModeEnabled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.dataguard.enabled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(dataGuardModeEnabled, forKey: "buxmuse.dataguard.enabled")
        }
    }

    // MARK: - Barter Logger Settings
    @Published public var barterLoggerEnabled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.barter.enabled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(barterLoggerEnabled, forKey: "buxmuse.barter.enabled")
        }
    }

    // MARK: - Anti-Scope Creep Settings
    @Published public var antiScopeCreepEnabled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.scopecreep.enabled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(antiScopeCreepEnabled, forKey: "buxmuse.scopecreep.enabled")
        }
    }

    // MARK: - Agreement Scratchpad Settings
    @Published public var agreementScratchpadEnabled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.agreementscratchpad.enabled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(agreementScratchpadEnabled, forKey: "buxmuse.agreementscratchpad.enabled")
        }
    }

    /// Default T&C clauses enabled for new agreement drafts.
    @Published public var agreementDefaultEnabledClauseIds: [String] = [] {
        didSet {
            guard isLoaded else { return }
            SettingsStore.saveAgreementDefaultClauseIds(agreementDefaultEnabledClauseIds)
        }
    }

    /// Default custom T&C text appended to new agreement drafts.
    @Published public var agreementDefaultCustomTerms: String = UserDefaults.standard.string(forKey: "buxmuse.agreement.terms.custom") ?? "" {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(agreementDefaultCustomTerms, forKey: "buxmuse.agreement.terms.custom")
        }
    }

    private static let agreementDefaultClauseIdsKey = "buxmuse.agreement.terms.defaultIds"

    /// Essential pack ids — keep aligned with `StudioAgreementTermsLibrary.clauseIds(for: .essential)`.
    private static let fallbackEssentialAgreementClauseIds: [String] = [
        "deposit", "payment-due", "cancellation-client", "scope-changes", "liability"
    ]

    private static func defaultAgreementClauseIds() -> [String] {
        if #available(iOS 26, *) {
            return StudioAgreementTermsLibrary.defaultEnabledClauseIds
        }
        return fallbackEssentialAgreementClauseIds
    }

    private static func loadAgreementDefaultClauseIds() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: agreementDefaultClauseIdsKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data),
              !decoded.isEmpty else {
            return defaultAgreementClauseIds()
        }
        return decoded
    }

    private static func saveAgreementDefaultClauseIds(_ ids: [String]) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: agreementDefaultClauseIdsKey)
    }

    // MARK: - Side-Hustle Matrix Settings
    @Published public var sideHustleMatrixEnabled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.sidehustle.enabled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(sideHustleMatrixEnabled, forKey: "buxmuse.sidehustle.enabled")
            if !sideHustleMatrixEnabled {
                HustleManager.shared.selectHustle(nil)
            }
        }
    }

    /// When a workspace is selected, include expenses with no workspace tag (shown with an Unassigned badge).
    @Published public var showUnassignedExpensesInWorkspace: Bool = {
        if UserDefaults.standard.object(forKey: "buxmuse.sidehustle.showUnassigned") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "buxmuse.sidehustle.showUnassigned")
    }() {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(showUnassignedExpensesInWorkspace, forKey: "buxmuse.sidehustle.showUnassigned")
        }
    }

    // MARK: - Payment Source Tracking (on by default — user can disable in Settings)
    @Published public var paymentSourceTrackingEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "buxmuse.paymentsource.enabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "buxmuse.paymentsource.enabled")
    }() {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(paymentSourceTrackingEnabled, forKey: "buxmuse.paymentsource.enabled")
        }
    }

    // MARK: - Dual-Cash Drawer Settings
    @Published public var dualCashDrawerEnabled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.cashdrawer.enabled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(dualCashDrawerEnabled, forKey: "buxmuse.cashdrawer.enabled")
        }
    }
    
    @Published public var primaryLocalCurrency: String = UserDefaults.standard.string(forKey: "buxmuse.cashdrawer.primaryCurrency") ?? "USD" {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(primaryLocalCurrency, forKey: "buxmuse.cashdrawer.primaryCurrency")
        }
    }
    
    @Published public var secondaryTradingCurrency: String = UserDefaults.standard.string(forKey: "buxmuse.cashdrawer.secondaryCurrency") ?? "DOP" {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(secondaryTradingCurrency, forKey: "buxmuse.cashdrawer.secondaryCurrency")
        }
    }
    
    @Published public var cashLocalBalanceValue: Double = UserDefaults.standard.double(forKey: "buxmuse.cashdrawer.localBalance") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(cashLocalBalanceValue, forKey: "buxmuse.cashdrawer.localBalance")
        }
    }
    
    @Published public var cashSecondaryBalanceValue: Double = UserDefaults.standard.double(forKey: "buxmuse.cashdrawer.secondaryBalance") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(cashSecondaryBalanceValue, forKey: "buxmuse.cashdrawer.secondaryBalance")
        }
    }
    
    // MARK: - Security Settings
    @Published public var biometricLockEnabled: Bool = false
    @Published public var requireBiometricOnLaunch: Bool = false
    @Published public var lockAfterInactivityMinutes: Int = 1 // 1 minute
    @Published public var privacyBlurInAppSwitching: Bool = true
    @Published public var cancelledSubscriptionMerchants: [String] = []

    // MARK: - Data Settings
    @Published public var allowLocalBackups: Bool = true
    @Published public var autoBackupFrequency: AutoBackupFrequency = .weekly
    @Published public var customBackupIntervalDays: Int = 3
    @Published public var includeStudioDataInExports: Bool = true
    @Published public var includeAnalyticsInExports: Bool = false
    @Published public var lastExportDate: Date? = nil
    
    // MARK: - Developer Options
    @Published public var enableDebugOverlay: Bool = false
    @Published public var showPerformanceMetrics: Bool = false
    
    // MARK: - Dashboard FAB (iPad)
    @Published public var ipadFabShortcut: DashboardFabPadShortcut = {
        if let raw = UserDefaults.standard.string(forKey: "buxmuse.ipadFabShortcut") {
            if raw == "tips" { return .themes }
            if let value = DashboardFabPadShortcut(rawValue: raw) {
                return value
            }
        }
        return .themes
    }() {
        didSet {
            guard isLoaded else { return }
            if studioEnabled,
               ipadFabShortcut == .scanReceipt || ipadFabShortcut == .newInvoice {
                ipadFabShortcut = .themes
            }
            UserDefaults.standard.set(ipadFabShortcut.rawValue, forKey: "buxmuse.ipadFabShortcut")
        }
    }

    // MARK: - Dashboard Greeting Settings
    @Published public var greetingHeaderEnabled: Bool = true
    @Published public var greetingShowIcon: Bool = true
    @Published public var greetingFontStyle: GreetingFontStyle = .playful
    
    // MARK: - Onboarding Settings
    @Published public var hasCompletedOnboarding: Bool = false

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
    private var pendingSaveWork: DispatchWorkItem?
    private static let saveDebounceInterval: TimeInterval = 0.4
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
        let solarContrastModeEnabled: Bool?
        
        let weekStartDay: WeekStartDay
        
        let budgetingMode: BudgetingMode
        let defaultBudgetPeriod: DefaultBudgetPeriod
        let showBudgetWarnings: Bool
        let autoAdjustBudgetsFromHistory: Bool
        let customBudgetProfiles: [CustomBudgetProfile]
        let simpleBudgetLimit: Decimal?
        let simpleBudgetCycle: SimpleBudgetCycle?
        let simpleBudgetPeriodAnchor: Date?
        let incomeFundingSource: IncomeFundingSource?
        let includeSimpleStudioIncomeInBudget: Bool?
        let includeProStudioIncomeInBudget: Bool?
        let customBudgetLimit: Decimal?
        let customBudgetPeriod: DefaultBudgetPeriod?
        let budgetApproachingThresholdPercent: Int?

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
        let burnoutGuardEnabled: Bool?
        let healthKitSyncEnabled: Bool?
        let hasAcknowledgedHealthKitDisclaimer: Bool?
        let manualSleepHours: Double?
        let manualStressLevel: Double?
        
        let biometricLockEnabled: Bool
        let requireBiometricOnLaunch: Bool
        let lockAfterInactivityMinutes: Int
        let privacyBlurInAppSwitching: Bool
        let cancelledSubscriptionMerchants: [String]?
        
        let allowLocalBackups: Bool
        let autoBackupFrequency: AutoBackupFrequency
        let customBackupIntervalDays: Int?
        let includeStudioDataInExports: Bool
        let includeAnalyticsInExports: Bool
        let lastExportDate: Date?
        
        let enableDebugOverlay: Bool
        let showPerformanceMetrics: Bool
        let hasCompletedOnboarding: Bool?
        
        let greetingHeaderEnabled: Bool?
        let greetingShowIcon: Bool?
        let greetingFontStyle: GreetingFontStyle?

        enum CodingKeys: String, CodingKey {
            case firstName, lastName, userDisplayName, profileAvatarData, preferredNameStyle
            case themeMode, accentColorId, neutralAccentId, useGlassmorphism, brandThemesEnabled, reducedMotion
            case solarContrastModeEnabled
            case weekStartDay, budgetingMode, defaultBudgetPeriod
            case showBudgetWarnings, autoAdjustBudgetsFromHistory, customBudgetProfiles
            case simpleBudgetLimit, simpleBudgetCycle, simpleBudgetPeriodAnchor, incomeFundingSource
            case includeSimpleStudioIncomeInBudget
            case includeProStudioIncomeInBudget
            case customBudgetLimit, customBudgetPeriod, budgetApproachingThresholdPercent
            case studioEnabled, freelanceEnabled
            case studioProfileId, freelanceProfileId
            case studioMode, studioPersona, studioPersonaConfigured
            case notificationsEnabled, budgetAlertsEnabled, billRemindersEnabled
            case studioInvoiceRemindersEnabled, freelanceInvoiceRemindersEnabled
            case taxDeadlineRemindersEnabled, dailySummaryEnabled
            case quietHoursStartHour, quietHoursStartMinute, quietHoursEndHour, quietHoursEndMinute
            case burnoutGuardEnabled, healthKitSyncEnabled, hasAcknowledgedHealthKitDisclaimer, manualSleepHours, manualStressLevel
            case biometricLockEnabled, requireBiometricOnLaunch, lockAfterInactivityMinutes
            case privacyBlurInAppSwitching, cancelledSubscriptionMerchants
            case allowLocalBackups, autoBackupFrequency, customBackupIntervalDays, hasCompletedOnboarding
            case includeStudioDataInExports, includeFreelanceDataInExports
            case includeAnalyticsInExports, lastExportDate
            case enableDebugOverlay, showPerformanceMetrics
            case greetingHeaderEnabled, greetingShowIcon, greetingFontStyle
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
            solarContrastModeEnabled = try c.decodeIfPresent(Bool.self, forKey: .solarContrastModeEnabled) ?? false
            weekStartDay = try c.decode(WeekStartDay.self, forKey: .weekStartDay)
            budgetingMode = try c.decode(BudgetingMode.self, forKey: .budgetingMode)
            defaultBudgetPeriod = try c.decode(DefaultBudgetPeriod.self, forKey: .defaultBudgetPeriod)
            showBudgetWarnings = try c.decode(Bool.self, forKey: .showBudgetWarnings)
            autoAdjustBudgetsFromHistory = try c.decode(Bool.self, forKey: .autoAdjustBudgetsFromHistory)
            customBudgetProfiles = try c.decode([CustomBudgetProfile].self, forKey: .customBudgetProfiles)
            simpleBudgetLimit = try c.decodeIfPresent(Decimal.self, forKey: .simpleBudgetLimit)
            simpleBudgetCycle = try c.decodeIfPresent(SimpleBudgetCycle.self, forKey: .simpleBudgetCycle)
            simpleBudgetPeriodAnchor = try c.decodeIfPresent(Date.self, forKey: .simpleBudgetPeriodAnchor)
            incomeFundingSource = try c.decodeIfPresent(IncomeFundingSource.self, forKey: .incomeFundingSource)
            includeSimpleStudioIncomeInBudget = try c.decodeIfPresent(Bool.self, forKey: .includeSimpleStudioIncomeInBudget)
            includeProStudioIncomeInBudget = try c.decodeIfPresent(Bool.self, forKey: .includeProStudioIncomeInBudget)
            customBudgetLimit = try c.decodeIfPresent(Decimal.self, forKey: .customBudgetLimit)
            customBudgetPeriod = try c.decodeIfPresent(DefaultBudgetPeriod.self, forKey: .customBudgetPeriod)
            budgetApproachingThresholdPercent = try c.decodeIfPresent(Int.self, forKey: .budgetApproachingThresholdPercent)
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
            self.burnoutGuardEnabled = try c.decodeIfPresent(Bool.self, forKey: .burnoutGuardEnabled) ?? true
            self.healthKitSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .healthKitSyncEnabled) ?? false
            self.hasAcknowledgedHealthKitDisclaimer = try c.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedHealthKitDisclaimer) ?? false
            self.manualSleepHours = try c.decodeIfPresent(Double.self, forKey: .manualSleepHours) ?? 7.5
            self.manualStressLevel = try c.decodeIfPresent(Double.self, forKey: .manualStressLevel) ?? 5.0
            biometricLockEnabled = try c.decode(Bool.self, forKey: .biometricLockEnabled)
            requireBiometricOnLaunch = try c.decode(Bool.self, forKey: .requireBiometricOnLaunch)
            lockAfterInactivityMinutes = try c.decode(Int.self, forKey: .lockAfterInactivityMinutes)
            privacyBlurInAppSwitching = try c.decode(Bool.self, forKey: .privacyBlurInAppSwitching)
            cancelledSubscriptionMerchants = try c.decodeIfPresent([String].self, forKey: .cancelledSubscriptionMerchants)
            allowLocalBackups = try c.decode(Bool.self, forKey: .allowLocalBackups)
            autoBackupFrequency = try c.decode(AutoBackupFrequency.self, forKey: .autoBackupFrequency)
            customBackupIntervalDays = try c.decodeIfPresent(Int.self, forKey: .customBackupIntervalDays) ?? 3
            includeStudioDataInExports = try c.decodeIfPresent(Bool.self, forKey: .includeStudioDataInExports)
                ?? c.decodeIfPresent(Bool.self, forKey: .includeFreelanceDataInExports) ?? true
            includeAnalyticsInExports = try c.decode(Bool.self, forKey: .includeAnalyticsInExports)
            lastExportDate = try c.decodeIfPresent(Date.self, forKey: .lastExportDate)
            enableDebugOverlay = try c.decode(Bool.self, forKey: .enableDebugOverlay)
            showPerformanceMetrics = try c.decode(Bool.self, forKey: .showPerformanceMetrics)
            hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
            greetingHeaderEnabled = try c.decodeIfPresent(Bool.self, forKey: .greetingHeaderEnabled)
            greetingShowIcon = try c.decodeIfPresent(Bool.self, forKey: .greetingShowIcon)
            greetingFontStyle = try c.decodeIfPresent(GreetingFontStyle.self, forKey: .greetingFontStyle)
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
            solarContrastModeEnabled: Bool?,
            weekStartDay: WeekStartDay,
            budgetingMode: BudgetingMode,
            defaultBudgetPeriod: DefaultBudgetPeriod,
            showBudgetWarnings: Bool,
            autoAdjustBudgetsFromHistory: Bool,
            customBudgetProfiles: [CustomBudgetProfile],
            simpleBudgetLimit: Decimal?,
            simpleBudgetCycle: SimpleBudgetCycle?,
            simpleBudgetPeriodAnchor: Date?,
            incomeFundingSource: IncomeFundingSource?,
            includeSimpleStudioIncomeInBudget: Bool?,
            includeProStudioIncomeInBudget: Bool?,
            customBudgetLimit: Decimal?,
            customBudgetPeriod: DefaultBudgetPeriod?,
            budgetApproachingThresholdPercent: Int?,
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
            burnoutGuardEnabled: Bool?,
            healthKitSyncEnabled: Bool?,
            hasAcknowledgedHealthKitDisclaimer: Bool?,
            manualSleepHours: Double?,
            manualStressLevel: Double?,
            biometricLockEnabled: Bool,
            requireBiometricOnLaunch: Bool,
            lockAfterInactivityMinutes: Int,
            privacyBlurInAppSwitching: Bool,
            cancelledSubscriptionMerchants: [String]?,
            allowLocalBackups: Bool,
            autoBackupFrequency: AutoBackupFrequency,
            customBackupIntervalDays: Int?,
            includeStudioDataInExports: Bool,
            includeAnalyticsInExports: Bool,
            lastExportDate: Date?,
            enableDebugOverlay: Bool,
            showPerformanceMetrics: Bool,
            hasCompletedOnboarding: Bool?,
            greetingHeaderEnabled: Bool?,
            greetingShowIcon: Bool?,
            greetingFontStyle: GreetingFontStyle?
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
            self.solarContrastModeEnabled = solarContrastModeEnabled ?? false
            self.weekStartDay = weekStartDay
            self.budgetingMode = budgetingMode
            self.defaultBudgetPeriod = defaultBudgetPeriod
            self.showBudgetWarnings = showBudgetWarnings
            self.autoAdjustBudgetsFromHistory = autoAdjustBudgetsFromHistory
            self.customBudgetProfiles = customBudgetProfiles
            self.simpleBudgetLimit = simpleBudgetLimit
            self.simpleBudgetCycle = simpleBudgetCycle
            self.simpleBudgetPeriodAnchor = simpleBudgetPeriodAnchor
            self.incomeFundingSource = incomeFundingSource
            self.includeSimpleStudioIncomeInBudget = includeSimpleStudioIncomeInBudget ?? false
            self.includeProStudioIncomeInBudget = includeProStudioIncomeInBudget ?? false
            self.customBudgetLimit = customBudgetLimit
            self.customBudgetPeriod = customBudgetPeriod
            self.budgetApproachingThresholdPercent = budgetApproachingThresholdPercent
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
            self.burnoutGuardEnabled = burnoutGuardEnabled ?? true
            self.healthKitSyncEnabled = healthKitSyncEnabled ?? false
            self.hasAcknowledgedHealthKitDisclaimer = hasAcknowledgedHealthKitDisclaimer ?? false
            self.manualSleepHours = manualSleepHours ?? 7.5
            self.manualStressLevel = manualStressLevel ?? 5.0
            self.biometricLockEnabled = biometricLockEnabled
            self.requireBiometricOnLaunch = requireBiometricOnLaunch
            self.lockAfterInactivityMinutes = lockAfterInactivityMinutes
            self.privacyBlurInAppSwitching = privacyBlurInAppSwitching
            self.cancelledSubscriptionMerchants = cancelledSubscriptionMerchants
            self.allowLocalBackups = allowLocalBackups
            self.autoBackupFrequency = autoBackupFrequency
            self.customBackupIntervalDays = customBackupIntervalDays
            self.includeStudioDataInExports = includeStudioDataInExports
            self.includeAnalyticsInExports = includeAnalyticsInExports
            self.lastExportDate = lastExportDate
            self.enableDebugOverlay = enableDebugOverlay
            self.showPerformanceMetrics = showPerformanceMetrics
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.greetingHeaderEnabled = greetingHeaderEnabled ?? true
            self.greetingShowIcon = greetingShowIcon ?? true
            self.greetingFontStyle = greetingFontStyle ?? .playful
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
            try c.encode(solarContrastModeEnabled, forKey: .solarContrastModeEnabled)
            try c.encode(weekStartDay, forKey: .weekStartDay)
            try c.encode(budgetingMode, forKey: .budgetingMode)
            try c.encode(defaultBudgetPeriod, forKey: .defaultBudgetPeriod)
            try c.encode(showBudgetWarnings, forKey: .showBudgetWarnings)
            try c.encode(autoAdjustBudgetsFromHistory, forKey: .autoAdjustBudgetsFromHistory)
            try c.encode(customBudgetProfiles, forKey: .customBudgetProfiles)
            try c.encodeIfPresent(simpleBudgetLimit, forKey: .simpleBudgetLimit)
            try c.encodeIfPresent(simpleBudgetCycle, forKey: .simpleBudgetCycle)
            try c.encodeIfPresent(simpleBudgetPeriodAnchor, forKey: .simpleBudgetPeriodAnchor)
            try c.encodeIfPresent(incomeFundingSource, forKey: .incomeFundingSource)
            try c.encodeIfPresent(includeSimpleStudioIncomeInBudget, forKey: .includeSimpleStudioIncomeInBudget)
            try c.encodeIfPresent(includeProStudioIncomeInBudget, forKey: .includeProStudioIncomeInBudget)
            try c.encodeIfPresent(customBudgetLimit, forKey: .customBudgetLimit)
            try c.encodeIfPresent(customBudgetPeriod, forKey: .customBudgetPeriod)
            try c.encodeIfPresent(budgetApproachingThresholdPercent, forKey: .budgetApproachingThresholdPercent)
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
            try c.encode(burnoutGuardEnabled, forKey: .burnoutGuardEnabled)
            try c.encode(healthKitSyncEnabled, forKey: .healthKitSyncEnabled)
            try c.encode(hasAcknowledgedHealthKitDisclaimer, forKey: .hasAcknowledgedHealthKitDisclaimer)
            try c.encode(manualSleepHours, forKey: .manualSleepHours)
            try c.encode(manualStressLevel, forKey: .manualStressLevel)
            try c.encode(biometricLockEnabled, forKey: .biometricLockEnabled)
            try c.encode(requireBiometricOnLaunch, forKey: .requireBiometricOnLaunch)
            try c.encode(lockAfterInactivityMinutes, forKey: .lockAfterInactivityMinutes)
            try c.encode(privacyBlurInAppSwitching, forKey: .privacyBlurInAppSwitching)
            try c.encodeIfPresent(cancelledSubscriptionMerchants, forKey: .cancelledSubscriptionMerchants)
            try c.encode(allowLocalBackups, forKey: .allowLocalBackups)
            try c.encode(autoBackupFrequency, forKey: .autoBackupFrequency)
            try c.encode(customBackupIntervalDays, forKey: .customBackupIntervalDays)
            try c.encode(includeStudioDataInExports, forKey: .includeStudioDataInExports)
            try c.encode(includeAnalyticsInExports, forKey: .includeAnalyticsInExports)
            try c.encodeIfPresent(lastExportDate, forKey: .lastExportDate)
            try c.encode(enableDebugOverlay, forKey: .enableDebugOverlay)
            try c.encode(showPerformanceMetrics, forKey: .showPerformanceMetrics)
            try c.encodeIfPresent(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
            try c.encodeIfPresent(greetingHeaderEnabled, forKey: .greetingHeaderEnabled)
            try c.encodeIfPresent(greetingShowIcon, forKey: .greetingShowIcon)
            try c.encodeIfPresent(greetingFontStyle, forKey: .greetingFontStyle)
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
                self.brandThemesEnabled = payload.brandThemesEnabled ?? false
                self.reducedMotion = payload.reducedMotion
                self.solarContrastModeEnabled = payload.solarContrastModeEnabled ?? false
                
                self.weekStartDay = payload.weekStartDay
                
                self.budgetingMode = payload.budgetingMode
                self.defaultBudgetPeriod = payload.defaultBudgetPeriod
                self.showBudgetWarnings = payload.showBudgetWarnings
                self.autoAdjustBudgetsFromHistory = payload.autoAdjustBudgetsFromHistory
                self.customBudgetProfiles = payload.customBudgetProfiles.filter { $0.name != "Standard Essentials" }
                self.simpleBudgetLimit = payload.simpleBudgetLimit ?? 1000
                self.simpleBudgetCycle = payload.simpleBudgetCycle ?? .monthFirst
                self.simpleBudgetPeriodAnchor = payload.simpleBudgetPeriodAnchor ?? Date()
                self.incomeFundingSource = payload.incomeFundingSource ?? .other
                self.includeSimpleStudioIncomeInBudget = payload.includeSimpleStudioIncomeInBudget ?? false
                self.includeProStudioIncomeInBudget = payload.includeProStudioIncomeInBudget ?? false
                self.customBudgetLimit = payload.customBudgetLimit ?? 50
                self.customBudgetPeriod = payload.customBudgetPeriod ?? .weekly
                self.budgetApproachingThresholdPercent = payload.budgetApproachingThresholdPercent ?? 80
                migrateLegacyCustomBudgetModeIfNeeded()
                normalizeEnvelopeCategoryStorageIfNeeded()

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
                self.burnoutGuardEnabled = payload.burnoutGuardEnabled ?? true
                self.healthKitSyncEnabled = payload.healthKitSyncEnabled ?? false
                self.hasAcknowledgedHealthKitDisclaimer = payload.hasAcknowledgedHealthKitDisclaimer ?? false
                self.manualSleepHours = payload.manualSleepHours ?? 7.5
                self.manualStressLevel = payload.manualStressLevel ?? 5.0
                
                self.biometricLockEnabled = payload.biometricLockEnabled
                self.requireBiometricOnLaunch = payload.requireBiometricOnLaunch
                self.lockAfterInactivityMinutes = payload.lockAfterInactivityMinutes
                self.privacyBlurInAppSwitching = payload.privacyBlurInAppSwitching
                self.cancelledSubscriptionMerchants = payload.cancelledSubscriptionMerchants ?? []
                UserDefaults.standard.set(self.cancelledSubscriptionMerchants, forKey: Self.cancelledSubscriptionsDefaultsKey)
                
                self.allowLocalBackups = payload.allowLocalBackups
                self.autoBackupFrequency = payload.autoBackupFrequency
                self.customBackupIntervalDays = payload.customBackupIntervalDays ?? 3
                self.includeStudioDataInExports = payload.includeStudioDataInExports
                self.includeAnalyticsInExports = payload.includeAnalyticsInExports
                self.lastExportDate = payload.lastExportDate
                
                self.enableDebugOverlay = payload.enableDebugOverlay
                self.showPerformanceMetrics = payload.showPerformanceMetrics
                self.hasCompletedOnboarding = payload.hasCompletedOnboarding ?? true
                self.greetingHeaderEnabled = payload.greetingHeaderEnabled ?? true
                self.greetingShowIcon = payload.greetingShowIcon ?? true
                self.greetingFontStyle = payload.greetingFontStyle ?? .playful

                loadInvoicePaymentPreferences()
                loadMileagePreferences()
                loadStudioDiscoveryPreference()
                loadAgreementPreferences()
                
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
        self.solarContrastModeEnabled = false
        self.brandThemesEnabled = false
        self.landingBackdropEnabled = true
        UserDefaults.standard.set(true, forKey: "buxmuse.landingBackdrop.enabled")
        self.useGlassmorphism = true
        self.accentColorId = AppTheme.buxDefault.name
        self.neutralAccentId = BuxSystemAccent.systemBlue.rawValue
        self.weekStartDay = .monday
        self.budgetingMode = .simple
        self.defaultBudgetPeriod = .monthly
        self.studioEnabled = false
        self.notificationsEnabled = true
        self.burnoutGuardEnabled = true
        self.healthKitSyncEnabled = false
        self.hasAcknowledgedHealthKitDisclaimer = false
        self.manualSleepHours = 7.5
        self.manualStressLevel = 5.0
        self.biometricLockEnabled = false
        self.sideHustleMatrixEnabled = false
        self.showUnassignedExpensesInWorkspace = true
        self.paymentSourceTrackingEnabled = true
        self.dualCashDrawerEnabled = false
        self.primaryLocalCurrency = "USD"
        self.secondaryTradingCurrency = "DOP"
        self.cashLocalBalanceValue = 0.0
        self.cashSecondaryBalanceValue = 0.0
        self.customBudgetProfiles = []
        self.simpleBudgetLimit = 1000
        self.simpleBudgetCycle = .monthFirst
        self.simpleBudgetPeriodAnchor = Date()
        self.incomeFundingSource = .other
        self.customBudgetLimit = 50
        self.customBudgetPeriod = .weekly
        self.budgetApproachingThresholdPercent = 80
        self.customBackupIntervalDays = 3
        self.hasCompletedOnboarding = false
        self.greetingHeaderEnabled = true
        self.greetingShowIcon = true
        self.greetingFontStyle = .playful
        loadInvoicePaymentPreferences()
        loadMileagePreferences()
        loadStudioDiscoveryPreference()
        loadAgreementPreferences()
        save()
    }

    private func loadAgreementPreferences() {
        agreementDefaultEnabledClauseIds = Self.loadAgreementDefaultClauseIds()
        if let custom = UserDefaults.standard.string(forKey: "buxmuse.agreement.terms.custom") {
            agreementDefaultCustomTerms = custom
        }
    }

    private static let studioDiscoveryDismissedKey = "studio_discovery_offer_dismissed"
    private static let standardBudgetStudioBridgePromptDismissedKey = "buxmuse.standardBudgetStudioBridgePromptDismissed"

    public func dismissStudioDiscoveryOffer() {
        studioDiscoveryOfferDismissed = true
        UserDefaults.standard.set(true, forKey: Self.studioDiscoveryDismissedKey)
    }

    public func dismissStandardBudgetStudioBridgePrompt() {
        standardBudgetStudioBridgePromptDismissed = true
    }

    private func loadStudioDiscoveryPreference() {
        studioDiscoveryOfferDismissed = UserDefaults.standard.bool(forKey: Self.studioDiscoveryDismissedKey)
        standardBudgetStudioBridgePromptDismissed = UserDefaults.standard.bool(forKey: Self.standardBudgetStudioBridgePromptDismissedKey)
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
    
    /// Fixes envelope rows that stored a localized category label instead of English catalog keys.
    func normalizeEnvelopeCategoryStorageIfNeeded() {
        var changed = false
        for profileIndex in customBudgetProfiles.indices {
            for categoryIndex in customBudgetProfiles[profileIndex].categories.indices {
                if customBudgetProfiles[profileIndex].categories[categoryIndex].normalizeStoredCategoryLink() {
                    changed = true
                }
            }
        }
        if changed { save() }
    }

    /// Merges legacy Custom budgeting mode into Simple (weekly / monthly / daily caps).
    func migrateLegacyCustomBudgetModeIfNeeded() {
        guard budgetingMode == .custom else { return }
        budgetingMode = .simple
        simpleBudgetLimit = customBudgetLimit
        switch customBudgetPeriod {
        case .weekly:
            simpleBudgetCycle = .weekly
        case .monthly:
            simpleBudgetCycle = .monthFirst
        case .custom:
            simpleBudgetCycle = .daily
        }
    }

    /// Coalesces rapid edits (sliders, typing) into one disk write — same payload as before.
    public func save() {
        pendingSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        pendingSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDebounceInterval, execute: work)
    }

    /// Flushes any pending debounced save and writes immediately (export, import, reset).
    public func saveImmediately() {
        pendingSaveWork?.cancel()
        pendingSaveWork = nil
        performSave()
    }

    private func performSave() {
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
            solarContrastModeEnabled: solarContrastModeEnabled,
            weekStartDay: weekStartDay,
            budgetingMode: budgetingMode,
            defaultBudgetPeriod: defaultBudgetPeriod,
            showBudgetWarnings: showBudgetWarnings,
            autoAdjustBudgetsFromHistory: autoAdjustBudgetsFromHistory,
            customBudgetProfiles: customBudgetProfiles,
            simpleBudgetLimit: simpleBudgetLimit,
            simpleBudgetCycle: simpleBudgetCycle,
            simpleBudgetPeriodAnchor: simpleBudgetPeriodAnchor,
            incomeFundingSource: incomeFundingSource,
            includeSimpleStudioIncomeInBudget: includeSimpleStudioIncomeInBudget,
            includeProStudioIncomeInBudget: includeProStudioIncomeInBudget,
            customBudgetLimit: customBudgetLimit,
            customBudgetPeriod: customBudgetPeriod,
            budgetApproachingThresholdPercent: budgetApproachingThresholdPercent,
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
            burnoutGuardEnabled: burnoutGuardEnabled,
            healthKitSyncEnabled: healthKitSyncEnabled,
            hasAcknowledgedHealthKitDisclaimer: hasAcknowledgedHealthKitDisclaimer,
            manualSleepHours: manualSleepHours,
            manualStressLevel: manualStressLevel,
            biometricLockEnabled: biometricLockEnabled,
            requireBiometricOnLaunch: requireBiometricOnLaunch,
            lockAfterInactivityMinutes: lockAfterInactivityMinutes,
            privacyBlurInAppSwitching: privacyBlurInAppSwitching,
            cancelledSubscriptionMerchants: cancelledSubscriptionMerchants,
            allowLocalBackups: allowLocalBackups,
            autoBackupFrequency: autoBackupFrequency,
            customBackupIntervalDays: customBackupIntervalDays,
            includeStudioDataInExports: includeStudioDataInExports,
            includeAnalyticsInExports: includeAnalyticsInExports,
            lastExportDate: lastExportDate,
            enableDebugOverlay: enableDebugOverlay,
            showPerformanceMetrics: showPerformanceMetrics,
            hasCompletedOnboarding: hasCompletedOnboarding,
            greetingHeaderEnabled: greetingHeaderEnabled,
            greetingShowIcon: greetingShowIcon,
            greetingFontStyle: greetingFontStyle
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

    public func exportArchiveSettingsData() -> Data? {
        saveImmediately()
        return try? Data(contentsOf: storeURL)
    }

    public func importArchiveSettingsData(_ data: Data) throws {
        try data.write(to: storeURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        isLoaded = false
        loadStore()
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

    func resolvedAppearanceSummary(themeManager: ThemeManager, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        if brandThemesEnabled {
            return BuxCatalogLabel.string(themeManager.current.name, locale: locale)
        }
        return resolvedSystemAccent().localizedDisplayName(locale: locale)
    }

    func applyBrandThemesAppearance(to themeManager: ThemeManager) {
        if brandThemesEnabled {
            themeManager.applyTheme(resolvedBrandTheme())
        } else {
            themeManager.applyTheme(AppTheme.standardNeutral(accent: resolvedSystemAccent()))
        }
    }

    /// Accent rim on cards from landing backdrop — themed presets or neutral ambient glow.
    var showsLandingCardShine: Bool {
        brandThemesEnabled || landingBackdropEnabled
    }

    /// Persist appearance + sync ThemeManager (call from theme picker).
    func persistThemeSelection(_ theme: AppTheme, themeManager: ThemeManager) {
        accentColorId = theme.name
        themeManager.applyTheme(theme)
        save()
    }
}
