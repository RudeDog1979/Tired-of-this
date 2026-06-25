//
//  BuxStoreKitIntroOfferCopy.swift
//  BuxMuse — Introductory offer labels for paywalls.
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
}
