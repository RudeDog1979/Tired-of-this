//
//  BarterLoggerSettingsView.swift
//  BuxMuse
//  Features/Settings/Views/
//
//  Settings panel to enable / configure the Barter & Trade Logger.
//

import SwiftUI

struct BarterLoggerSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Barter & Trade Logger") {
                Toggle(isOn: $store.barterLoggerEnabled.animation(.spring(response: 0.3, dampingFraction: 0.75))) {
                    VStack(alignment: .leading, spacing: 3) {
                        BuxCatalogDynamicText(key: "Enable Barter Logger")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Unlocks \"Barter / Exchange\" payment method in every transaction. Log skill swaps, trade deals, and non-cash exchanges.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color.orange)
                .buxFormFieldPadding()
            }

            if store.barterLoggerEnabled {
                BuxFormSection(title: "How it works") {
                    VStack(alignment: .leading, spacing: 10) {
                        barterInfoRow(
                            icon: "arrow.left.arrow.right.circle.fill",
                            color: .orange,
                            title: "Log any trade or exchange",
                            body: "When logging an expense, choose \"Barter / Exchange\" as the payment method. Describe what you gave and what you received."
                        )
                        Divider().opacity(0.1)
                        barterInfoRow(
                            icon: "doc.text.magnifyingglass",
                            color: .blue,
                            title: "Estimated value tracking",
                            body: "Optionally enter the estimated monetary value of the barter for record-keeping and tax documentation."
                        )
                        Divider().opacity(0.1)
                        barterInfoRow(
                            icon: "chart.bar.fill",
                            color: .purple,
                            title: "Barter insight card",
                            body: "BuxMuse shows a summary of your total barter activity in the Insights tab — total estimated value and trade count."
                        )
                    }
                    .buxFormFieldPadding()
                }
            }
        }
        .buxCatalogNavigationTitle("Barter & Trade Logger")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func barterInfoRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                Text(body)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
