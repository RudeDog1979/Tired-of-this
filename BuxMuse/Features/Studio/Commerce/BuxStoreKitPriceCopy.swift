//
//  BuxStoreKitPriceCopy.swift
//  BuxMuse — Localized price / period labels from StoreKit Product (no hardcoded currency).
//

import Foundation
import StoreKit

/// Builds paywall copy from StoreKit 2 `Product.displayPrice` and subscription period.
/// Never embeds £ / $ / € — Apple injects the correct storefront currency.
enum BuxStoreKitPriceCopy {
    /// Localized price only, e.g. "$4.99", "£4.99", "€4,99".
    static func displayPrice(for product: StoreKit.Product?) -> String? {
        product?.displayPrice
    }

    /// Price with billing period from the product itself, e.g. "$4.99/month".
    static func pricePerPeriodLabel(for product: StoreKit.Product?, locale: Locale) -> String? {
        guard let product else { return nil }
        guard let period = product.subscription?.subscriptionPeriod else {
            return product.displayPrice
        }
        let price = product.displayPrice
        switch period.unit {
        case .day:
            return BuxLocalizedString.format("%@/day", locale: locale, price)
        case .week:
            return BuxLocalizedString.format("%@/week", locale: locale, price)
        case .month:
            return period.value == 1
                ? BuxLocalizedString.format("%@/month", locale: locale, price)
                : BuxLocalizedString.format("%@/%lld months", locale: locale, price, Int64(period.value))
        case .year:
            return period.value == 1
                ? BuxLocalizedString.format("%@/year", locale: locale, price)
                : BuxLocalizedString.format("%@/%lld years", locale: locale, price, Int64(period.value))
        @unknown default:
            return price
        }
    }

    /// Compact CTA period suffix for buttons, e.g. "$4.99/mo".
    static func compactPricePerPeriodLabel(for product: StoreKit.Product?, locale: Locale) -> String? {
        guard let product else { return nil }
        guard let period = product.subscription?.subscriptionPeriod else {
            return product.displayPrice
        }
        let price = product.displayPrice
        switch period.unit {
        case .month:
            return BuxLocalizedString.format("%@/mo", locale: locale, price)
        case .year:
            return BuxLocalizedString.format("%@/yr", locale: locale, price)
        case .week:
            return BuxLocalizedString.format("%@/wk", locale: locale, price)
        case .day:
            return BuxLocalizedString.format("%@/day", locale: locale, price)
        @unknown default:
            return price
        }
    }

    /// Standard subscribe CTA — price from Apple only.
    static func subscribeCTA(for product: StoreKit.Product?, locale: Locale) -> String {
        if let priced = compactPricePerPeriodLabel(for: product, locale: locale) {
            return BuxLocalizedString.format("Subscribe — %@", locale: locale, priced)
        }
        return BuxCatalogLabel.string("Subscribe", locale: locale)
    }

    /// Pro upgrade CTA — price from Apple only.
    static func upgradeToProCTA(for product: StoreKit.Product?, locale: Locale) -> String {
        if let priced = compactPricePerPeriodLabel(for: product, locale: locale) {
            return BuxLocalizedString.format("Upgrade to BuxMuse Pro — %@", locale: locale, priced)
        }
        return BuxCatalogLabel.string("Upgrade to BuxMuse Pro", locale: locale)
    }

    /// Standard subscribe CTA — price from Apple only; trial CTA from StoreKit intro offer.
    static func subscribeOrTrialCTA(
        for product: StoreKit.Product?,
        introEligible: Bool,
        locale: Locale
    ) -> String {
        if introEligible, BuxStoreKitIntroOfferCopy.hasFreeTrialOffer(product: product) {
            return BuxStoreKitIntroOfferCopy.startTrialCTA(for: product, locale: locale)
        }
        return subscribeCTA(for: product, locale: locale)
    }

    /// Subtitle from StoreKit price + optional intro trial length (no hardcoded currency or days).
    static func standardSubtitle(
        product: StoreKit.Product?,
        introEligible: Bool,
        locale: Locale
    ) -> String {
        if introEligible,
           let trial = BuxStoreKitIntroOfferCopy.trialLengthLabel(for: product, locale: locale) {
            if let after = pricePerPeriodLabel(for: product, locale: locale) {
                return BuxLocalizedString.format("%@ · then %@", locale: locale, trial, after)
            }
            return trial
        }
        if let priced = pricePerPeriodLabel(for: product, locale: locale) {
            return BuxLocalizedString.format("Standard · %@", locale: locale, priced)
        }
        return BuxCatalogLabel.string("Standard · personal finance + Simple Studio", locale: locale)
    }
}
