//
//  MileageSettingsView.swift
//  BuxMuse
//
//  Studio mileage allowance and optional auto-location for trip logging.
//

import SwiftUI

struct MileageSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Auto-location for mileage") {
                Toggle(loc("Auto-location for mileage"), isOn: $store.autoLocationForMileage)
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                BuxCatalogDynamicText(key: "When enabled, trip sheets can capture your current place name for start or end.")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
                    .buxFormFieldPadding()
            }

            BuxFormSection(title: "Mileage rate") {
                HStack {
                    BuxCatalogDynamicText(key: "Allowance per mile")
                    Spacer()
                    TextField("0.45", value: $store.mileageRatePerUnitValue, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 88)
                }
                .buxFormFieldPadding()
                BuxCatalogDynamicText(key: "Applied to business-purpose trips in Studio deductions and tax estimates.")
                    .font(.system(size: 12))
                    .buxLabelSecondary()
                    .buxFormFieldPadding()
            }
        }
        .buxCatalogNavigationTitle("Mileage log")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.isSettingsContext, true)
        .onChange(of: store.autoLocationForMileage) { _, _ in store.save() }
        .onChange(of: store.mileageRatePerUnitValue) { _, _ in store.save() }
    }
}
