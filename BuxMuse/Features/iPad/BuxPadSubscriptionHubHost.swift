//
//  BuxPadSubscriptionHubHost.swift
//  BuxMuse — iPad Subscription Hub inspector/sheet host.
//

import SwiftUI

struct BuxPadSubscriptionHubHost: View {
    @Binding var isPresented: Bool
    let engine: FinancialIntelligenceEngine
    let settingsManager: AppSettingsManager
    let hubSnapshot: SubscriptionHubSnapshot

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain

    var body: some View {
        SubscriptionHubView(
            isPresented: $isPresented,
            engine: engine,
            settingsManager: settingsManager,
            hubSnapshot: hubSnapshot,
            onCancelSubscription: { name in
                try? brain.cancelSubscription(merchantName: name)
            }
        )
        .environmentObject(settingsManager)
        .environmentObject(themeManager)
        .environment(\.buxPadInspectorColumn, true)
    }
}
