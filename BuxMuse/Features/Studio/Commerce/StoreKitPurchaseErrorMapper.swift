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
            switch purchaseError {
            case .invalidQuantity:
                return BuxCatalogLabel.string("Invalid purchase quantity.", locale: locale)
            case .productUnavailable:
                return BuxCatalogLabel.string("This product is not available right now. Try again in a moment.", locale: locale)
            @unknown default:
                break
            }
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
}
