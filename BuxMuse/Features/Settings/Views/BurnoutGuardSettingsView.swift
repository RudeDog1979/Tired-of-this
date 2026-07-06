//
//  BurnoutGuardSettingsView.swift
//  BuxMuse
//
//  Creative Energy widget — manual sleep and stress tuning.
//

import SwiftUI

struct BurnoutGuardSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Creative energy widget") {
                Toggle(isOn: $store.burnoutGuardEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        BuxCatalogDynamicText(key: "Show on Home dashboard")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Tracks workload, sleep, and stress signals into a Creative Energy score.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()
            }

            if store.burnoutGuardEnabled {
                BuxFormSection(title: "Manual tuning") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                BuxCatalogDynamicText(key: "Default sleep hours")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(
                                    BuxLocalizedString.format(
                                        "%.1f hrs",
                                        locale: appSettingsManager.interfaceLocale,
                                        store.manualSleepHours
                                    )
                                )
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            }
                            Slider(value: $store.manualSleepHours, in: 4...10, step: 0.5)
                                .tint(themeManager.contrastAccentColor(for: colorScheme))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                BuxCatalogDynamicText(key: "Default stress level")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(
                                    BuxLocalizedString.format(
                                        "%lld/10",
                                        locale: appSettingsManager.interfaceLocale,
                                        Int64(store.manualStressLevel)
                                    )
                                )
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                            }
                            Slider(value: $store.manualStressLevel, in: 1...10, step: 1)
                                .tint(.orange)
                        }
                    }
                    .buxFormFieldPadding()

                    BuxCatalogDynamicText(key: "Sleep and stress values stay on this iPhone. Adjust them anytime from Home → Money Map or here in Settings.")
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)
                        .buxFormFieldPadding()
                }
            }
        }
        .buxCatalogNavigationTitle("Creative energy")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.isSettingsContext, true)
        .onChange(of: store.burnoutGuardEnabled) { _, _ in store.save() }
        .onChange(of: store.manualSleepHours) { _, _ in store.save() }
        .onChange(of: store.manualStressLevel) { _, _ in store.save() }
    }
}
