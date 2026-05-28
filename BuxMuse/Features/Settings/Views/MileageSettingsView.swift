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
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
            Form {
                Section {
                    Toggle("Auto-location for mileage", isOn: $store.autoLocationForMileage)
                        .tint(themeManager.current.accentColor)
                    Text("When enabled, trip sheets can capture your current place name for start or end.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                } header: {
                    Text("AUTO-LOCATION FOR MILEAGE")
                }

                Section {
                    HStack {
                        Text("Allowance per mile")
                        Spacer()
                        TextField("0.45", value: $store.mileageRatePerUnitValue, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 88)
                    }
                    Text("Applied to business-purpose trips in Studio deductions and tax estimates.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                } header: {
                    Text("MILEAGE RATE")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Mileage Log")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.autoLocationForMileage) { _, _ in store.save() }
        .onChange(of: store.mileageRatePerUnitValue) { _, _ in store.save() }
    }
}
