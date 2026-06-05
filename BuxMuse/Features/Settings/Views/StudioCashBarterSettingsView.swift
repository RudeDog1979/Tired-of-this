//
//  StudioCashBarterSettingsView.swift
//  BuxMuse
//
//  Combined Cash Drawer + Barter settings (Studio tools).
//

import SwiftUI

struct StudioCashBarterSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Dual-cash drawer") {
                NavigationLink {
                    DualCashDrawerSettingsView()
                        .environmentObject(themeManager)
                        .environment(\.isSettingsContext, true)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            BuxCatalogDynamicText(key: "Cash drawer")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text(store.dualCashDrawerEnabled ? "On" : "Off")
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                        }
                        Spacer()
                        BuxChevron()
                    }
                    .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "Barter & trade") {
                NavigationLink {
                    BarterLoggerSettingsView()
                        .environmentObject(themeManager)
                        .environment(\.isSettingsContext, true)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            BuxCatalogDynamicText(key: "Barter logger")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text(store.barterLoggerEnabled ? "On" : "Off")
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                        }
                        Spacer()
                        BuxChevron()
                    }
                    .buxFormFieldPadding()
                }
            }
        }
        .buxCatalogNavigationTitle("Cash & barter")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.isSettingsContext, true)
    }
}
