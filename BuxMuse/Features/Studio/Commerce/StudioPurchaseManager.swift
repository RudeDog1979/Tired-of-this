//
//  StudioPurchaseManager.swift
//  BuxMuse — StoreKit 2: base app subscription, 7-day trial, Studio add-ons.
//

import Combine
import Foundation
import StoreKit

enum StudioPurchaseError: LocalizedError {
    case productUnavailable
    case purchasePending
    case userCancelled
    case unverifiedTransaction
    case subscriptionRequired
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "This product is not available right now. Try again in a moment."
        case .purchasePending:
            return "Your purchase is pending approval."
        case .userCancelled:
            return nil
        case .unverifiedTransaction:
            return "We could not verify this purchase with Apple."
        case .subscriptionRequired:
            return "An active BuxMuse subscription is required."
        case .unknown:
            return "Something went wrong with the purchase."
        }
    }
}

enum BuxMuseBillingPeriod: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var baseProductID: BuxMuseProductID {
        switch self {
        case .monthly: return .baseMonthly
        case .yearly: return .baseYearly
        }
    }

    var studioProProductID: BuxMuseProductID {
        switch self {
        case .monthly: return .studioProMonthly
        case .yearly: return .studioProYearly
        }
    }
}

typealias PremiumBillingPeriod = BuxMuseBillingPeriod

@MainActor
final class StudioPurchaseManager: ObservableObject {
    static let shared = StudioPurchaseManager()

    @Published private(set) var products: [StoreKit.Product] = []
    @Published private(set) var baseSubscriptionActive = false
    @Published private(set) var ownsSimpleOneTimePurchase = false
    @Published private(set) var proSubscriptionActive = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var lastErrorMessage: String?
    @Published private(set) var entitlementsDidLoad = false
    @Published private(set) var didLoadProducts = false

    private var updatesTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let settings = SettingsStore.shared

    private init() {
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Access

    var isTrialActive: Bool {
        settings.isPremiumTrialActive
    }

    var trialDaysRemaining: Int {
        settings.premiumTrialDaysRemaining
    }

    /// Full app access: active BuxMuse sub or 7-day trial.
    var hasActiveSubscription: Bool {
        baseSubscriptionActive || settings.isPremiumTrialActive || settings.premiumLegacyEntitled
    }

    /// Simple Studio while BuxMuse is active (Pro sub includes Simple).
    var hasSimpleStudio: Bool {
        guard hasActiveSubscription else { return false }
        return ownsSimpleOneTimePurchase || proSubscriptionActive || settings.studioLegacySimpleEntitled
    }

    var hasProStudio: Bool {
        guard hasActiveSubscription else { return false }
        return proSubscriptionActive || settings.studioLegacyProEntitled
    }

    func product(for id: BuxMuseProductID) -> StoreKit.Product? {
        products.first { $0.id == id.rawValue }
    }

    func displayPrice(for id: BuxMuseProductID) -> String? {
        product(for: id)?.displayPrice
    }

    // MARK: - Lifecycle

    func start() {
        reconcileLegacyEntitlementsIfNeeded()
        settings.ensurePremiumTrialStarted()
        objectWillChange.send()
        updatesTask?.cancel()
        updatesTask = Task { await listenForTransactions() }
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            didLoadProducts = true
        }
        do {
            products = try await StoreKit.Product.products(for: BuxMuseProductID.allCases.map(\.rawValue))
                .sorted { lhs, rhs in lhs.price < rhs.price }
            if products.isEmpty {
                lastErrorMessage = BuxCatalogLabel.string(
                    "App Store products could not be loaded. For Xcode testing, run from the BuxMuse scheme with the StoreKit configuration file. For TestFlight, upload a build and use a Sandbox Apple ID.",
                    locale: BuxInterfaceLocale.currentInterfaceLocale
                )
            }
        } catch {
            lastErrorMessage = StoreKitPurchaseErrorMapper.message(
                for: error,
                locale: BuxInterfaceLocale.currentInterfaceLocale
            )
        }
    }

    func refreshEntitlements() async {
        var baseSub = false
        var simpleOneTime = false
        var pro = false

        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: result) else { continue }
            guard let product = BuxMuseProductID(rawValue: transaction.productID) else { continue }
            switch product {
            case .baseMonthly, .baseYearly:
                baseSub = true
            case .studioSimple:
                simpleOneTime = true
            case .studioProMonthly, .studioProYearly:
                pro = true
            }
        }

        baseSubscriptionActive = baseSub
        ownsSimpleOneTimePurchase = simpleOneTime
        proSubscriptionActive = pro
        entitlementsDidLoad = true
        applyEntitlementsToSettings()
        objectWillChange.send()
    }

    func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = StoreKitPurchaseErrorMapper.message(
                for: error,
                locale: BuxInterfaceLocale.currentInterfaceLocale
            )
        }
    }

    func userFacingErrorMessage(for error: Error, locale: Locale) -> String {
        StoreKitPurchaseErrorMapper.message(for: error, locale: locale)
    }

    @discardableResult
    func purchase(_ productID: BuxMuseProductID) async throws -> Bool {
        if productID == .studioSimple, !hasActiveSubscription {
            throw StudioPurchaseError.subscriptionRequired
        }
        if productID.isStudioPro, !hasActiveSubscription {
            throw StudioPurchaseError.subscriptionRequired
        }

        guard let product = product(for: productID) else {
            await loadProducts()
            guard let retryProduct = product(for: productID) else {
                throw StudioPurchaseError.productUnavailable
            }
            return try await purchaseProduct(retryProduct, productID: productID)
        }
        return try await purchaseProduct(product, productID: productID)
    }

    func purchaseBaseSubscription(period: BuxMuseBillingPeriod) async throws -> Bool {
        try await purchase(period.baseProductID)
    }

    func purchaseProStudio(period: BuxMuseBillingPeriod) async throws -> Bool {
        try await purchase(period.studioProProductID)
    }

    private func purchaseProduct(_ product: StoreKit.Product, productID: BuxMuseProductID) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw NSError(
                domain: (error as NSError).domain,
                code: (error as NSError).code,
                userInfo: [NSLocalizedDescriptionKey: StoreKitPurchaseErrorMapper.message(
                    for: error,
                    locale: BuxInterfaceLocale.currentInterfaceLocale
                )]
            )
        }

        switch result {
        case .success(let verification):
            guard let transaction = verifiedTransaction(from: verification) else {
                throw StudioPurchaseError.unverifiedTransaction
            }
            await transaction.finish()
            await refreshEntitlements()
            if productID.isStudioPro {
                settings.studioMode = .pro
            } else if productID == .studioSimple, settings.studioMode == .pro, !hasProStudio {
                settings.studioMode = .simple
            }
            applyEntitlementsToSettings()
            return true
        case .userCancelled:
            throw StudioPurchaseError.userCancelled
        case .pending:
            throw StudioPurchaseError.purchasePending
        @unknown default:
            throw StudioPurchaseError.unknown
        }
    }

    func applyEntitlementsToSettings() {
        guard entitlementsDidLoad else { return }

        guard hasSimpleStudio else {
            // Keep Studio on for legacy/pre-IAP installs until the user explicitly turns it off.
            if settings.studioLegacySimpleEntitled || settings.studioLegacyProEntitled {
                return
            }
            if settings.studioEnabled {
                settings.studioEnabled = false
                settings.save()
            }
            return
        }

        if hasProStudio {
            settings.studioMode = .pro
        } else if settings.studioMode == .pro {
            settings.studioMode = .simple
        }
        if !settings.studioEnabled {
            settings.studioEnabled = true
        }
        settings.save()
    }

    private func reconcileLegacyEntitlementsIfNeeded() {
        guard !settings.studioIAPLegacyReconciled else { return }
        settings.studioIAPLegacyReconciled = true

        let existingUser = settings.hasCompletedOnboarding
        if existingUser {
            settings.premiumLegacyEntitled = true
        }
        if settings.studioEnabled {
            settings.studioLegacySimpleEntitled = true
            if settings.studioMode == .pro {
                settings.studioLegacyProEntitled = true
            }
        }
        settings.save()
    }

    private func listenForTransactions() async {
        for await result in StoreKit.Transaction.updates {
            guard let transaction = verifiedTransaction(from: result) else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func verifiedTransaction(from result: StoreKit.VerificationResult<StoreKit.Transaction>) -> StoreKit.Transaction? {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            return nil
        }
    }
}

// MARK: - Legacy API aliases

extension StudioPurchaseManager {
    var hasPremiumAccess: Bool { hasActiveSubscription }
    var premiumSubscriptionActive: Bool { baseSubscriptionActive }
    var isPremiumTrialActive: Bool { isTrialActive }
    var premiumTrialDaysRemaining: Int { trialDaysRemaining }
    var purchasedSimple: Bool { ownsSimpleOneTimePurchase || proSubscriptionActive }

    func purchasePremium(period: BuxMuseBillingPeriod) async throws -> Bool {
        try await purchaseBaseSubscription(period: period)
    }
}
