//
//  SubscriptionsSettingsEmbedView.swift
//  BuxMuse
//  Features/Settings/Views/
//
//  Embeds Subscription Hub inside Settings navigation (iPhone + iPad split).
//

import SwiftUI

struct SubscriptionsSettingsEmbedView: View {
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isPresented = true

    var body: some View {
        SubscriptionHubView(
            isPresented: $isPresented,
            engine: financialBridge.engine,
            settingsManager: appSettingsManager,
            hubSnapshot: brain.subscriptionHubSnapshot,
            onCancelSubscription: { name in
                try? brain.cancelSubscription(merchantName: name)
            }
        )
        .environmentObject(themeManager)
    }
}
