//
//  StoreKitPurchaseErrorMapper.swift
//  BuxMuse — Actionable copy for StoreKit purchase failures.
//

import Foundation
import StoreKit

enum StoreKitPurchaseErrorMapper {
    nonisolated static func message(for error: Error, locale: Locale) -> String {
        if let studioError = error as? StudioPurchaseError {
            return studioError.errorDescription ?? BuxCatalogLabel.string("Something went wrong with the purchase.", locale: locale)
        }

        if let purchaseError = error as? Product.PurchaseError {
            return purchaseErrorMessage(for: purchaseError, locale: locale)
        }

        let nsError = error as NSError
        if nsError.domain == SKErrorDomain {
            switch SKError.Code(rawValue: nsError.code) {
            case .paymentCancelled:
                return BuxCatalogLabel.string("Purchase cancelled.", locale: locale)
            case .paymentNotAllowed:
                return BuxCatalogLabel.string("In-app purchases are not allowed on this device. Check Screen Time restrictions.", locale: locale)
            case .storeProductNotAvailable:
                return BuxCatalogLabel.string(
                    "This product is not available from the App Store yet. Upload a build with in-app purchases enabled, then test with a Sandbox Apple ID.",
                    locale: locale
                )
            case .cloudServiceNetworkConnectionFailed, .cloudServicePermissionDenied:
                return BuxCatalogLabel.string("Could not reach the App Store. Check your connection and try again.", locale: locale)
            default:
                break
            }
        }

        if nsError.localizedDescription.localizedCaseInsensitiveContains("unable to complete request") {
            return BuxCatalogLabel.string(
                "Apple could not complete this purchase. Sign in with a Sandbox Apple ID under Settings → Developer → Sandbox Apple ID (or App Store → Sandbox Account), then try again.",
                locale: locale
            )
        }

        return error.localizedDescription
    }

    /// `if` chains avoid non-exhaustive `switch` when StoreKit adds SDK-only cases (e.g. iOS 26.5+).
    nonisolated private static func purchaseErrorMessage(
        for purchaseError: Product.PurchaseError,
        locale: Locale
    ) -> String {
        if purchaseError == .invalidQuantity {
            return BuxCatalogLabel.string("Invalid purchase quantity.", locale: locale)
        }
        if purchaseError == .productUnavailable {
            return BuxCatalogLabel.string("This product is not available right now. Try again in a moment.", locale: locale)
        }
        if purchaseError == .purchaseNotAllowed {
            return BuxCatalogLabel.string("In-app purchases are not allowed on this device. Check Screen Time restrictions.", locale: locale)
        }
        if purchaseError == .ineligibleForOffer {
            return BuxCatalogLabel.string("You are not eligible for this offer.", locale: locale)
        }
        if purchaseError == .invalidOfferIdentifier
            || purchaseError == .invalidOfferPrice
            || purchaseError == .invalidOfferSignature
            || purchaseError == .missingOfferParameters {
            return BuxCatalogLabel.string("This offer could not be applied. Try again without a promo code.", locale: locale)
        }
        if #available(iOS 26.5, macOS 26.5, tvOS 26.5, watchOS 26.5, visionOS 26.5, *) {
            if purchaseError == .paymentMethodBindingConfigurationRequired {
                return BuxCatalogLabel.string(
                    "Add or confirm your payment method in Settings, then try again.",
                    locale: locale
                )
            }
        }
        return BuxCatalogLabel.string("Something went wrong with the purchase.", locale: locale)
    }
}
