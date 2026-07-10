//
//  BuxRestorePurchasesButton.swift
//  BuxMuse — Visible secondary Restore Purchases control for paywalls.
//

import SwiftUI

/// Full-width secondary button so Restore Purchases is obvious for App Review.
struct BuxRestorePurchasesButton: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var purchaseManager = StudioPurchaseManager.shared

    var body: some View {
        BuxButton(
            title: "Restore purchases",
            systemImage: "arrow.clockwise",
            role: .secondary,
            expands: true,
            isEnabled: !purchaseManager.isRestoring
        ) {
            Task { await purchaseManager.restorePurchases() }
        }
        .environmentObject(themeManager)
        .accessibilityIdentifier("buxmuse.restorePurchases")
    }
}
