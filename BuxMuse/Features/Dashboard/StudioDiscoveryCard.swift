//
//  StudioDiscoveryCard.swift
//  BuxMuse
//
//  Optional Studio upsell when the tab is off (first-run friendly).
//

import SwiftUI

struct StudioDiscoveryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: BuxToolbarMetrics.iconPointSize, weight: .semibold))
                    .foregroundColor(themeManager.current.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Self-employed?")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text("Turn on Studio for invoices, mileage, and tax estimates — optional, in Settings.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    store.dismissStudioDiscoveryOffer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            Button {
                store.dismissStudioDiscoveryOffer()
                navigationCoordinator.openStudioSettings()
            } label: {
                Text("See Studio in Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(BuxPressFeedbackStyle())
            .background {
                Capsule(style: .continuous)
                    .fill(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
            }
            .foregroundColor(themeManager.current.accentColor)
        }
        .padding(14)
        .dashboardMaterialCardChrome(.outlined)
    }
}
