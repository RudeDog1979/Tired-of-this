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
            BuxFormSection(title: "Dual-Cash Drawer") {
                NavigationLink {
                    DualCashDrawerSettingsView()
                        .environmentObject(themeManager)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cash Drawer")
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

            BuxFormSection(title: "Barter & Trade") {
                NavigationLink {
                    BarterLoggerSettingsView()
                        .environmentObject(themeManager)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Barter Logger")
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
        .navigationTitle("Cash & Barter")
        .navigationBarTitleDisplayMode(.inline)
    }
}
