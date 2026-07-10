//
//  BuxStoreKitIntroOfferCopy.swift
//  BuxMuse — Introductory offer labels from StoreKit Product only (no hardcoded durations).
//

import Foundation
import StoreKit

enum BuxStoreKitIntroOfferCopy {
    struct ActiveIntroOfferStatus: Equatable {
        var isActive = false
        var daysRemaining: Int?
    }

    static func isEligibleForIntroOffer(product: StoreKit.Product?) async -> Bool {
        guard let subscription = product?.subscription else { return false }
        return await subscription.isEligibleForIntroOffer
    }

    static func activeIntroOfferStatus(for product: StoreKit.Product?) async -> ActiveIntroOfferStatus {
        guard let subscription = product?.subscription else { return ActiveIntroOfferStatus() }

        let statuses: [Product.SubscriptionInfo.Status]
        do {
            statuses = try await subscription.status
        } catch {
            return ActiveIntroOfferStatus()
        }

        for status in statuses {
            guard status.state == .subscribed else { continue }
            guard case .verified(let transaction) = status.transaction else { continue }
            guard isIntroductoryTransaction(transaction) else { continue }

            var result = ActiveIntroOfferStatus(isActive: true, daysRemaining: nil)
            if case .verified(let renewalInfo) = status.renewalInfo,
               let renewalDate = renewalInfo.renewalDate {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: renewalDate).day ?? 0
                result.daysRemaining = max(0, days)
            }
            return result
        }

        return ActiveIntroOfferStatus()
    }

    private static func isIntroductoryTransaction(_ transaction: StoreKit.Transaction) -> Bool {
        transaction.offer?.type == .introductory
    }

    /// True when the product has a free-trial introductory offer configured in StoreKit / Connect.
    static func hasFreeTrialOffer(product: StoreKit.Product?) -> Bool {
        product?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// Length only from StoreKit intro period, e.g. "7-day free trial", "1-week free trial".
    static func trialLengthLabel(for product: StoreKit.Product?, locale: Locale) -> String? {
        guard let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }

        let value = offer.period.value
        switch offer.period.unit {
        case .day:
            return BuxLocalizedString.format("%lld-day free trial", locale: locale, Int64(value))
        case .week:
            return BuxLocalizedString.format("%lld-week free trial", locale: locale, Int64(value))
        case .month:
            return BuxLocalizedString.format("%lld-month free trial", locale: locale, Int64(value))
        case .year:
            return BuxLocalizedString.format("%lld-year free trial", locale: locale, Int64(value))
        @unknown default:
            return BuxCatalogLabel.string("Free trial", locale: locale)
        }
    }

    static func subscribeAfterTrialLabel(
        for product: StoreKit.Product?,
        locale: Locale
    ) -> String? {
        guard let product,
              product.subscription?.introductoryOffer?.paymentMode == .freeTrial else { return nil }
        return BuxLocalizedString.format(
            "Then %@. Cancel anytime in Settings.",
            locale: locale,
            product.displayPrice
        )
    }

    /// Primary CTA when eligible for StoreKit free trial.
    static func startTrialCTA(for product: StoreKit.Product?, locale: Locale) -> String {
        if let trial = trialLengthLabel(for: product, locale: locale) {
            return BuxLocalizedString.format("Start %@", locale: locale, trial)
        }
        return BuxCatalogLabel.string("Start free trial", locale: locale)
    }

    /// Bullet: "{trial}, then billed through Apple"
    static func trialThenBilledBullet(for product: StoreKit.Product?, locale: Locale) -> String? {
        guard let trial = trialLengthLabel(for: product, locale: locale) else { return nil }
        return BuxLocalizedString.format("%@, then billed through Apple", locale: locale, trial)
    }

    /// Header when blocking + eligible: "Start your {trial} to continue using BuxMuse."
    static func startTrialToContinueHeader(for product: StoreKit.Product?, locale: Locale) -> String {
        if let trial = trialLengthLabel(for: product, locale: locale) {
            return BuxLocalizedString.format(
                "Start your %@ to continue using BuxMuse.",
                locale: locale,
                trial
            )
        }
        return BuxCatalogLabel.string("Subscribe to continue using BuxMuse.", locale: locale)
    }

    /// Non-blocking header when eligible: "Try BuxMuse Standard free — {trial}. Includes Simple Studio."
    static func tryStandardFreeHeader(for product: StoreKit.Product?, locale: Locale) -> String {
        if let trial = trialLengthLabel(for: product, locale: locale) {
            return BuxLocalizedString.format(
                "Try BuxMuse Standard free — %@. Includes Simple Studio.",
                locale: locale,
                trial
            )
        }
        return BuxCatalogLabel.string(
            "BuxMuse Standard includes personal finance and Simple Studio.",
            locale: locale
        )
    }

    /// Settings subtitle when intro-eligible.
    static func trialAvailableSettingsSubtitle(for product: StoreKit.Product?, locale: Locale) -> String {
        if let trial = trialLengthLabel(for: product, locale: locale) {
            return BuxLocalizedString.format("%@ available", locale: locale, trial)
        }
        return BuxCatalogLabel.string("Free trial available", locale: locale)
    }
}
