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
    @Published public var simpleBudgetLimit: Decimal = 0
    @Published public var simpleBudgetCycle: SimpleBudgetCycle = .monthFirst
    @Published public var simpleBudgetPeriodAnchor: Date = Date()
    @Published public var incomeFundingSource: IncomeFundingSource = .salary
    @Published public var salaryPayProfile: SalaryPayProfile = .empty
    /// When enabled, Simple Studio money-in entries count toward Standard budget earned income for the pay period.
    @Published public var includeSimpleStudioIncomeInBudget: Bool = false
    /// When enabled, paid Pro Studio invoices count toward Standard budget earned income for the pay period.
    @Published public var includeProStudioIncomeInBudget: Bool = false
    @Published public var customBudgetLimit: Decimal = 50
    @Published public var customBudgetPeriod: DefaultBudgetPeriod = .weekly
    @Published public var budgetApproachingThresholdPercent: Int = 80
    @Published public var budgetQuickSetupCompleted: Bool = UserDefaults.standard.bool(forKey: "buxmuse.budgetQuickSetupCompleted") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(budgetQuickSetupCompleted, forKey: Self.budgetQuickSetupCompletedKey)
        }
    }
    
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
    @Published public var appTourFinished: Bool = UserDefaults.standard.bool(forKey: "buxmuse.appTour.finished") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(appTourFinished, forKey: Self.appTourFinishedKey)
        }
    }
    @Published public var appTourSkipped: Bool = UserDefaults.standard.bool(forKey: "buxmuse.appTour.skipped") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(appTourSkipped, forKey: Self.appTourSkippedKey)
        }
    }
    /// Ephemeral — set when onboarding completes; consumed to auto-start the interactive tour.
    @Published public var appTourPendingAutoStart: Bool = false
    @Published public var studioProfileId: UUID? = nil
    /// Simple (default) vs Pro Studio presentation.
    @Published public var studioMode: StudioMode = .simple
    @Published public var studioPersona: StudioPersona = .other
    @Published public var studioPersonaConfigured: Bool = false
    /// Pre-IAP installs that already unlocked Studio keep access after StoreKit ships.
    @Published public var studioLegacySimpleEntitled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.studio.legacySimple") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(studioLegacySimpleEntitled, forKey: "buxmuse.studio.legacySimple")
        }
    }
    @Published public var studioLegacyProEntitled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.studio.legacyPro") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(studioLegacyProEntitled, forKey: "buxmuse.studio.legacyPro")
        }
    }
    @Published public var studioIAPLegacyReconciled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.studio.iapLegacyReconciled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(studioIAPLegacyReconciled, forKey: "buxmuse.studio.iapLegacyReconciled")
        }
    }

    /// Premium access for installs that predated subscriptions (TestFlight grandfather).
    @Published public var premiumLegacyEntitled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.premium.legacyEntitled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(premiumLegacyEntitled, forKey: "buxmuse.premium.legacyEntitled")
        }
    }

    /// First launch timestamp for the 7-day Premium trial.
    @Published public var premiumTrialStartDate: Date? = {
        guard let interval = UserDefaults.standard.object(forKey: "buxmuse.premium.trialStart") as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }() {
        didSet {
            guard isLoaded else { return }
            if let premiumTrialStartDate {
                UserDefaults.standard.set(premiumTrialStartDate.timeIntervalSince1970, forKey: "buxmuse.premium.trialStart")
            } else {
                UserDefaults.standard.removeObject(forKey: "buxmuse.premium.trialStart")
            }
        }
    }

    static let premiumTrialLengthDays = 7

    var isPremiumTrialActive: Bool {
        guard let start = premiumTrialStartDate else { return false }
        guard !premiumLegacyEntitled else { return false }
        let elapsed = Date().timeIntervalSince(start)
        return elapsed < Double(Self.premiumTrialLengthDays) * 86_400
    }

    var premiumTrialDaysRemaining: Int {
        guard let start = premiumTrialStartDate else { return 0 }
        let end = start.addingTimeInterval(Double(Self.premiumTrialLengthDays) * 86_400)
        let remaining = end.timeIntervalSince(Date())
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / 86_400))
    }

    func ensurePremiumTrialStarted() {
        // Deprecated: trials are Apple-managed introductory offers. Kept for API compatibility.
    }

    // MARK: - Notifications Settings
    @Published public var notificationsEnabled: Bool = true
    @Published public var budgetAlertsEnabled: Bool = true
    @Published public var billRemindersEnabled: Bool = true
    @Published public var studioInvoiceRemindersEnabled: Bool = true
    @Published public var taxDeadlineRemindersEnabled: Bool = true
    @Published public var dailySummaryEnabled: Bool = false
    @Published public var quietHoursEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "buxmuse.quiethours.enabled") == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: "buxmuse.quiethours.enabled")
    }() {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(quietHoursEnabled, forKey: "buxmuse.quiethours.enabled")
        }
    }
    @Published public var dailyTipNotificationsEnabled: Bool = {
        if UserDefaults.standard.object(forKey: "buxmuse.dailytip.notifications") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "buxmuse.dailytip.notifications")
    }() {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(dailyTipNotificationsEnabled, forKey: "buxmuse.dailytip.notifications")
        }
    }
    @Published public var quietHoursStartHour: Int = 22
    @Published public var quietHoursStartMinute: Int = 0
    @Published public var quietHoursEndHour: Int = 7
    @Published public var quietHoursEndMinute: Int = 0
    
    // MARK: - Workspace Preferences Settings
    @Published public var burnoutGuardEnabled: Bool = true
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

    // MARK: - Apple Wallet / FinanceKit Settings
    @Published public var appleWalletSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.applewallet.enabled") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(appleWalletSyncEnabled, forKey: "buxmuse.applewallet.enabled")
        }
    }

    @Published public var appleWalletAutoSyncEnabled: Bool = UserDefaults.standard.bool(forKey: "buxmuse.applewallet.autosync") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(appleWalletAutoSyncEnabled, forKey: "buxmuse.applewallet.autosync")
        }
    }

    @Published public var appleWalletInitialSyncCompleted: Bool = UserDefaults.standard.bool(forKey: "buxmuse.applewallet.initialsync.done") {
        didSet {
            guard isLoaded else { return }
            UserDefaults.standard.set(appleWalletInitialSyncCompleted, forKey: "buxmuse.applewallet.initialsync.done")
        }
    }

    @Published public var appleWalletLastSyncDate: Date? = {
        let raw = UserDefaults.standard.double(forKey: "buxmuse.applewallet.lastsync")
        return raw > 0 ? Date(timeIntervalSince1970: raw) : nil
    }() {
        didSet {
            guard isLoaded else { return }
            if let appleWalletLastSyncDate {
                UserDefaults.standard.set(appleWalletLastSyncDate.timeIntervalSince1970, forKey: "buxmuse.applewallet.lastsync")
            } else {
                UserDefaults.standard.removeObject(forKey: "buxmuse.applewallet.lastsync")
            }
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
    
    // MARK: - Household iCloud Settings
    @Published public var householdCloudRecordName: String? = nil
    @Published public var householdShareURL: String? = nil
    @Published public var sharedEnvelopeProfileId: UUID? = nil
    @Published public var householdDisplayName: String? = nil
    @Published public var householdSharedZoneName: String? = nil
    @Published public var householdSharedZoneOwner: String? = nil

    // MARK: - Personal iCloud sync (same Apple ID across your devices)
    @Published public var personalCloudSyncEnabled: Bool = false

    // MARK: - Consumer debt tracking
    @Published public var consumerDebtEnabled: Bool = false
    @Published public var debtDiscoveryDeferred: Bool = false

    /// Mirrored into iCloud personal sync so currency, country, and language match across devices.
    @Published public var syncedCurrencyId: String? = nil
    @Published public var syncedCountryId: String? = nil
    @Published public var syncedInterfaceLanguageRaw: String? = nil

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
    /// When false (default), Vault Title emoji pin stays in Profile only — keeps Home hero quieter.
    @Published public var showVaultTitleOnHomeAvatar: Bool = false
    
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
    public private(set) var lastPersistedAt: Date?
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
        let salaryPayProfile: SalaryPayProfile?
        let includeSimpleStudioIncomeInBudget: Bool?
        let includeProStudioIncomeInBudget: Bool?
        let customBudgetLimit: Decimal?
        let customBudgetPeriod: DefaultBudgetPeriod?
        let budgetApproachingThresholdPercent: Int?
        let budgetQuickSetupCompleted: Bool?

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
        let showVaultTitleOnHomeAvatar: Bool?
        let householdCloudRecordName: String?
        let householdShareURL: String?
        let sharedEnvelopeProfileId: UUID?
        let householdDisplayName: String?
        let householdSharedZoneName: String?
        let householdSharedZoneOwner: String?
        let personalCloudSyncEnabled: Bool?
        let consumerDebtEnabled: Bool?
        let debtDiscoveryDeferred: Bool?
        let syncedCurrencyId: String?
        let syncedCountryId: String?
        let syncedInterfaceLanguageRaw: String?

        enum CodingKeys: String, CodingKey {
            case firstName, lastName, userDisplayName, profileAvatarData, preferredNameStyle
            case themeMode, accentColorId, neutralAccentId, useGlassmorphism, brandThemesEnabled, reducedMotion
            case solarContrastModeEnabled
            case weekStartDay, budgetingMode, defaultBudgetPeriod
            case showBudgetWarnings, autoAdjustBudgetsFromHistory, customBudgetProfiles
            case simpleBudgetLimit, simpleBudgetCycle, simpleBudgetPeriodAnchor, incomeFundingSource, salaryPayProfile
            case includeSimpleStudioIncomeInBudget
            case includeProStudioIncomeInBudget
            case customBudgetLimit, customBudgetPeriod, budgetApproachingThresholdPercent, budgetQuickSetupCompleted
            case studioEnabled, freelanceEnabled
            case studioProfileId, freelanceProfileId
            case studioMode, studioPersona, studioPersonaConfigured
            case notificationsEnabled, budgetAlertsEnabled, billRemindersEnabled
            case studioInvoiceRemindersEnabled, freelanceInvoiceRemindersEnabled
            case taxDeadlineRemindersEnabled, dailySummaryEnabled
            case quietHoursStartHour, quietHoursStartMinute, quietHoursEndHour, quietHoursEndMinute
            case burnoutGuardEnabled, manualSleepHours, manualStressLevel
            case biometricLockEnabled, requireBiometricOnLaunch, lockAfterInactivityMinutes
            case privacyBlurInAppSwitching, cancelledSubscriptionMerchants
            case allowLocalBackups, autoBackupFrequency, customBackupIntervalDays, hasCompletedOnboarding
            case includeStudioDataInExports, includeFreelanceDataInExports
            case includeAnalyticsInExports, lastExportDate
            case enableDebugOverlay, showPerformanceMetrics
            case greetingHeaderEnabled, greetingShowIcon, greetingFontStyle, showVaultTitleOnHomeAvatar
            case householdCloudRecordName, householdShareURL, sharedEnvelopeProfileId, householdDisplayName
            case householdSharedZoneName, householdSharedZoneOwner
            case personalCloudSyncEnabled
            case consumerDebtEnabled, debtDiscoveryDeferred
            case syncedCurrencyId, syncedCountryId, syncedInterfaceLanguageRaw
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
            salaryPayProfile = try c.decodeIfPresent(SalaryPayProfile.self, forKey: .salaryPayProfile)
            includeSimpleStudioIncomeInBudget = try c.decodeIfPresent(Bool.self, forKey: .includeSimpleStudioIncomeInBudget)
            includeProStudioIncomeInBudget = try c.decodeIfPresent(Bool.self, forKey: .includeProStudioIncomeInBudget)
            customBudgetLimit = try c.decodeIfPresent(Decimal.self, forKey: .customBudgetLimit)
            customBudgetPeriod = try c.decodeIfPresent(DefaultBudgetPeriod.self, forKey: .customBudgetPeriod)
            budgetApproachingThresholdPercent = try c.decodeIfPresent(Int.self, forKey: .budgetApproachingThresholdPercent)
            budgetQuickSetupCompleted = try c.decodeIfPresent(Bool.self, forKey: .budgetQuickSetupCompleted)
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
            showVaultTitleOnHomeAvatar = try c.decodeIfPresent(Bool.self, forKey: .showVaultTitleOnHomeAvatar)
            householdCloudRecordName = try c.decodeIfPresent(String.self, forKey: .householdCloudRecordName)
            householdShareURL = try c.decodeIfPresent(String.self, forKey: .householdShareURL)
            sharedEnvelopeProfileId = try c.decodeIfPresent(UUID.self, forKey: .sharedEnvelopeProfileId)
            householdDisplayName = try c.decodeIfPresent(String.self, forKey: .householdDisplayName)
            householdSharedZoneName = try c.decodeIfPresent(String.self, forKey: .householdSharedZoneName)
            householdSharedZoneOwner = try c.decodeIfPresent(String.self, forKey: .householdSharedZoneOwner)
            personalCloudSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .personalCloudSyncEnabled)
            consumerDebtEnabled = try c.decodeIfPresent(Bool.self, forKey: .consumerDebtEnabled)
            debtDiscoveryDeferred = try c.decodeIfPresent(Bool.self, forKey: .debtDiscoveryDeferred)
            syncedCurrencyId = try c.decodeIfPresent(String.self, forKey: .syncedCurrencyId)
            syncedCountryId = try c.decodeIfPresent(String.self, forKey: .syncedCountryId)
            syncedInterfaceLanguageRaw = try c.decodeIfPresent(String.self, forKey: .syncedInterfaceLanguageRaw)
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
            salaryPayProfile: SalaryPayProfile? = nil,
            includeSimpleStudioIncomeInBudget: Bool?,
            includeProStudioIncomeInBudget: Bool?,
            customBudgetLimit: Decimal?,
            customBudgetPeriod: DefaultBudgetPeriod?,
            budgetApproachingThresholdPercent: Int?,
            budgetQuickSetupCompleted: Bool? = nil,
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
            greetingFontStyle: GreetingFontStyle?,
            showVaultTitleOnHomeAvatar: Bool? = nil,
            householdCloudRecordName: String? = nil,
            householdShareURL: String? = nil,
            sharedEnvelopeProfileId: UUID? = nil,
            householdDisplayName: String? = nil,
            householdSharedZoneName: String? = nil,
            householdSharedZoneOwner: String? = nil,
            personalCloudSyncEnabled: Bool? = nil,
            consumerDebtEnabled: Bool? = nil,
            debtDiscoveryDeferred: Bool? = nil,
            syncedCurrencyId: String? = nil,
            syncedCountryId: String? = nil,
            syncedInterfaceLanguageRaw: String? = nil
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
            self.salaryPayProfile = salaryPayProfile
            self.includeSimpleStudioIncomeInBudget = includeSimpleStudioIncomeInBudget ?? false
            self.includeProStudioIncomeInBudget = includeProStudioIncomeInBudget ?? false
            self.customBudgetLimit = customBudgetLimit
            self.customBudgetPeriod = customBudgetPeriod
            self.budgetApproachingThresholdPercent = budgetApproachingThresholdPercent
            self.budgetQuickSetupCompleted = budgetQuickSetupCompleted
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
            self.showVaultTitleOnHomeAvatar = showVaultTitleOnHomeAvatar ?? false
            self.householdCloudRecordName = householdCloudRecordName
            self.householdShareURL = householdShareURL
            self.sharedEnvelopeProfileId = sharedEnvelopeProfileId
            self.householdDisplayName = householdDisplayName
            self.householdSharedZoneName = householdSharedZoneName
            self.householdSharedZoneOwner = householdSharedZoneOwner
            self.personalCloudSyncEnabled = personalCloudSyncEnabled ?? false
            self.consumerDebtEnabled = consumerDebtEnabled ?? false
            self.debtDiscoveryDeferred = debtDiscoveryDeferred ?? false
            self.syncedCurrencyId = syncedCurrencyId
            self.syncedCountryId = syncedCountryId
            self.syncedInterfaceLanguageRaw = syncedInterfaceLanguageRaw
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
            try c.encodeIfPresent(salaryPayProfile, forKey: .salaryPayProfile)
            try c.encodeIfPresent(includeSimpleStudioIncomeInBudget, forKey: .includeSimpleStudioIncomeInBudget)
            try c.encodeIfPresent(includeProStudioIncomeInBudget, forKey: .includeProStudioIncomeInBudget)
            try c.encodeIfPresent(customBudgetLimit, forKey: .customBudgetLimit)
            try c.encodeIfPresent(customBudgetPeriod, forKey: .customBudgetPeriod)
            try c.encodeIfPresent(budgetApproachingThresholdPercent, forKey: .budgetApproachingThresholdPercent)
            try c.encodeIfPresent(budgetQuickSetupCompleted, forKey: .budgetQuickSetupCompleted)
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
            try c.encodeIfPresent(showVaultTitleOnHomeAvatar, forKey: .showVaultTitleOnHomeAvatar)
            try c.encodeIfPresent(householdCloudRecordName, forKey: .householdCloudRecordName)
            try c.encodeIfPresent(householdShareURL, forKey: .householdShareURL)
            try c.encodeIfPresent(sharedEnvelopeProfileId, forKey: .sharedEnvelopeProfileId)
            try c.encodeIfPresent(householdDisplayName, forKey: .householdDisplayName)
            try c.encodeIfPresent(householdSharedZoneName, forKey: .householdSharedZoneName)
            try c.encodeIfPresent(householdSharedZoneOwner, forKey: .householdSharedZoneOwner)
            try c.encodeIfPresent(personalCloudSyncEnabled, forKey: .personalCloudSyncEnabled)
            try c.encodeIfPresent(consumerDebtEnabled, forKey: .consumerDebtEnabled)
            try c.encodeIfPresent(debtDiscoveryDeferred, forKey: .debtDiscoveryDeferred)
            try c.encodeIfPresent(syncedCurrencyId, forKey: .syncedCurrencyId)
            try c.encodeIfPresent(syncedCountryId, forKey: .syncedCountryId)
            try c.encodeIfPresent(syncedInterfaceLanguageRaw, forKey: .syncedInterfaceLanguageRaw)
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
                self.simpleBudgetLimit = payload.simpleBudgetLimit ?? 0
                self.simpleBudgetCycle = payload.simpleBudgetCycle ?? .monthFirst
                self.simpleBudgetPeriodAnchor = payload.simpleBudgetPeriodAnchor ?? Date()
                self.incomeFundingSource = payload.incomeFundingSource ?? .salary
                self.salaryPayProfile = payload.salaryPayProfile ?? .empty
                self.includeSimpleStudioIncomeInBudget = payload.includeSimpleStudioIncomeInBudget ?? false
                self.includeProStudioIncomeInBudget = payload.includeProStudioIncomeInBudget ?? false
                self.customBudgetLimit = payload.customBudgetLimit ?? 50
                self.customBudgetPeriod = payload.customBudgetPeriod ?? .weekly
                self.budgetApproachingThresholdPercent = payload.budgetApproachingThresholdPercent ?? 80
                if let completed = payload.budgetQuickSetupCompleted {
                    self.budgetQuickSetupCompleted = completed
                }
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
                self.showVaultTitleOnHomeAvatar = payload.showVaultTitleOnHomeAvatar ?? false
                self.householdCloudRecordName = payload.householdCloudRecordName
                self.householdShareURL = payload.householdShareURL
                self.sharedEnvelopeProfileId = payload.sharedEnvelopeProfileId
                self.householdDisplayName = payload.householdDisplayName
                self.householdSharedZoneName = payload.householdSharedZoneName
                self.householdSharedZoneOwner = payload.householdSharedZoneOwner
                self.personalCloudSyncEnabled = payload.personalCloudSyncEnabled ?? false
                self.consumerDebtEnabled = payload.consumerDebtEnabled ?? false
                self.debtDiscoveryDeferred = payload.debtDiscoveryDeferred ?? false
                self.syncedCurrencyId = payload.syncedCurrencyId
                self.syncedCountryId = payload.syncedCountryId
                self.syncedInterfaceLanguageRaw = payload.syncedInterfaceLanguageRaw

                loadInvoicePaymentPreferences()
                loadMileagePreferences()
                loadStudioDiscoveryPreference()
                loadAgreementPreferences()

                if let attrs = try? fm.attributesOfItem(atPath: path),
                   let modified = attrs[.modificationDate] as? Date {
                    lastPersistedAt = modified
                }
                
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
        self.profileAvatarData = nil
        self.preferredNameStyle = .fullName
        self.cancelledSubscriptionMerchants = []
        self.studioDiscoveryOfferDismissed = false
        self.standardBudgetStudioBridgePromptDismissed = false
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
        self.studioLegacySimpleEntitled = false
        self.studioLegacyProEntitled = false
        self.studioIAPLegacyReconciled = false
        self.premiumLegacyEntitled = false
        self.premiumTrialStartDate = nil
        self.notificationsEnabled = true
        self.burnoutGuardEnabled = true
        self.manualSleepHours = 7.5
        self.manualStressLevel = 5.0
        self.biometricLockEnabled = false
        self.sideHustleMatrixEnabled = false
        self.showUnassignedExpensesInWorkspace = true
        self.paymentSourceTrackingEnabled = true
        self.appleWalletSyncEnabled = false
        self.appleWalletAutoSyncEnabled = false
        self.appleWalletInitialSyncCompleted = false
        self.appleWalletLastSyncDate = nil
        self.dualCashDrawerEnabled = false
        self.primaryLocalCurrency = "USD"
        self.secondaryTradingCurrency = "DOP"
        self.cashLocalBalanceValue = 0.0
        self.cashSecondaryBalanceValue = 0.0
        self.customBudgetProfiles = []
        self.simpleBudgetLimit = 0
        self.simpleBudgetCycle = .monthFirst
        self.simpleBudgetPeriodAnchor = Date()
        self.incomeFundingSource = .salary
        self.salaryPayProfile = .empty
        self.customBudgetLimit = 50
        self.customBudgetPeriod = .weekly
        self.budgetApproachingThresholdPercent = 80
        self.customBackupIntervalDays = 3
        self.hasCompletedOnboarding = false
        self.personalCloudSyncEnabled = false
        self.consumerDebtEnabled = false
        self.debtDiscoveryDeferred = false
        self.budgetQuickSetupCompleted = false
        self.householdCloudRecordName = nil
        self.householdShareURL = nil
        self.sharedEnvelopeProfileId = nil
        self.householdDisplayName = nil
        self.householdSharedZoneName = nil
        self.householdSharedZoneOwner = nil
        self.greetingHeaderEnabled = true
        self.greetingShowIcon = true
        self.greetingFontStyle = .playful
        self.showVaultTitleOnHomeAvatar = false
        resetAppTourProgress()
        loadInvoicePaymentPreferences()
        loadMileagePreferences()
        loadStudioDiscoveryPreference()
        loadAgreementPreferences()
        save(notifyCloudSync: false)
    }

    private func loadAgreementPreferences() {
        agreementDefaultEnabledClauseIds = Self.loadAgreementDefaultClauseIds()
        if let custom = UserDefaults.standard.string(forKey: "buxmuse.agreement.terms.custom") {
            agreementDefaultCustomTerms = custom
        }
    }

    private static let studioDiscoveryDismissedKey = "studio_discovery_offer_dismissed"
    private static let standardBudgetStudioBridgePromptDismissedKey = "buxmuse.standardBudgetStudioBridgePromptDismissed"
    private static let appTourFinishedKey = "buxmuse.appTour.finished"
    private static let appTourSkippedKey = "buxmuse.appTour.skipped"
    private static let budgetQuickSetupCompletedKey = "buxmuse.budgetQuickSetupCompleted"

    public func dismissStudioDiscoveryOffer() {
        studioDiscoveryOfferDismissed = true
        UserDefaults.standard.set(true, forKey: Self.studioDiscoveryDismissedKey)
    }

    public func dismissStandardBudgetStudioBridgePrompt() {
        standardBudgetStudioBridgePromptDismissed = true
    }

    public func resetAppTourProgress() {
        appTourFinished = false
        appTourSkipped = false
        appTourPendingAutoStart = false
        UserDefaults.standard.removeObject(forKey: Self.appTourFinishedKey)
        UserDefaults.standard.removeObject(forKey: Self.appTourSkippedKey)
    }

    private func loadStudioDiscoveryPreference() {
        studioDiscoveryOfferDismissed = UserDefaults.standard.bool(forKey: Self.studioDiscoveryDismissedKey)
        standardBudgetStudioBridgePromptDismissed = UserDefaults.standard.bool(forKey: Self.standardBudgetStudioBridgePromptDismissedKey)
        appTourFinished = UserDefaults.standard.bool(forKey: Self.appTourFinishedKey)
        appTourSkipped = UserDefaults.standard.bool(forKey: Self.appTourSkippedKey)
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
    public func save(notifyCloudSync: Bool = true) {
        pendingSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performSave(notifyCloudSync: notifyCloudSync)
        }
        pendingSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.saveDebounceInterval, execute: work)
    }

    /// Flushes any pending debounced save and writes immediately (export, import, reset).
    public func saveImmediately(notifyCloudSync: Bool = true) {
        pendingSaveWork?.cancel()
        pendingSaveWork = nil
        performSave(notifyCloudSync: notifyCloudSync)
    }

    private func performSave(notifyCloudSync: Bool = true) {
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
            salaryPayProfile: salaryPayProfile,
            includeSimpleStudioIncomeInBudget: includeSimpleStudioIncomeInBudget,
            includeProStudioIncomeInBudget: includeProStudioIncomeInBudget,
            customBudgetLimit: customBudgetLimit,
            customBudgetPeriod: customBudgetPeriod,
            budgetApproachingThresholdPercent: budgetApproachingThresholdPercent,
            budgetQuickSetupCompleted: budgetQuickSetupCompleted,
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
            greetingFontStyle: greetingFontStyle,
            showVaultTitleOnHomeAvatar: showVaultTitleOnHomeAvatar,
            householdCloudRecordName: householdCloudRecordName,
            householdShareURL: householdShareURL,
            sharedEnvelopeProfileId: sharedEnvelopeProfileId,
            householdDisplayName: householdDisplayName,
            householdSharedZoneName: householdSharedZoneName,
            householdSharedZoneOwner: householdSharedZoneOwner,
            personalCloudSyncEnabled: personalCloudSyncEnabled,
            consumerDebtEnabled: consumerDebtEnabled,
            debtDiscoveryDeferred: debtDiscoveryDeferred,
            syncedCurrencyId: syncedCurrencyId,
            syncedCountryId: syncedCountryId,
            syncedInterfaceLanguageRaw: syncedInterfaceLanguageRaw
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storeURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            lastPersistedAt = Date()
            if notifyCloudSync {
                PersonalSettingsDomainSync.refreshDomainRevisions(from: self)
                NotificationCenter.default.post(name: .buxMuseSettingsDidPersist, object: nil)
            }
        } catch {
            print("SettingsStore: failed to save JSON payload: \(error)")
        }
    }
    
    // MARK: - Actions
    
    public func resetAllData() {
        clearPasscode()
        if FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.removeItem(at: storeURL)
        }
        isLoaded = false
        seedDefaults()
        Task { @MainActor in
            BuxPresenceStreakStore.shared.resetAll()
        }
    }

    public func exportArchiveSettingsData() -> Data? {
        saveImmediately(notifyCloudSync: false)
        return try? Data(contentsOf: storeURL)
    }

    /// Whether an exported settings blob reflects real user configuration (not factory defaults).
    public static func archiveContainsUserData(_ data: Data) -> Bool {
        struct Probe: Decodable {
            var hasCompletedOnboarding: Bool?
            var budgetQuickSetupCompleted: Bool?
            var simpleBudgetLimit: Decimal?
            var firstName: String?
            var personalCloudSyncEnabled: Bool?
        }
        if let probe = try? JSONDecoder().decode(Probe.self, from: data) {
            if probe.hasCompletedOnboarding == true { return true }
            if probe.personalCloudSyncEnabled == true { return true }
            if probe.budgetQuickSetupCompleted == true { return true }
            if probe.firstName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false { return true }
        }
        return data.count > 900
    }

    public func importArchiveSettingsData(_ data: Data) throws {
        try data.write(to: storeURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        isLoaded = false
        loadStore()
        NotificationCenter.default.post(name: .buxMuseSettingsArchiveDidImport, object: nil)
    }

    /// Forces a disk reload — used when converting legacy iCloud settings blobs into domain records.
    public func reloadFromDiskForSyncMigration() {
        isLoaded = false
        loadStore()
    }

    func pushRegionalPreferences(from appSettings: AppSettingsManager) {
        syncedCurrencyId = appSettings.selectedCurrency.id
        syncedCountryId = appSettings.selectedCountry.id
        syncedInterfaceLanguageRaw = appSettings.interfaceLanguage.rawValue
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
