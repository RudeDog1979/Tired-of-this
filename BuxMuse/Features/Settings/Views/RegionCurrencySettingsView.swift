//
//  RegionCurrencySettingsView.swift
//  BuxMuse
//
//  Localization options, week start customizations, formatting previews.
//

import SwiftUI

struct RegionCurrencySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared
    
    @State private var showCurrencySheet = false
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            Form {
                Section("ACTIVE LOCALE & FORMATTING") {
                    Button(action: { showCurrencySheet = true }) {
                        HStack {
                            Text("Preferred Currency")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Spacer()
                            Text("\(appSettingsManager.selectedCurrency.flag) \(appSettingsManager.selectedCurrency.id)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeManager.current.accentColor)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                    
                    HStack {
                        Text("Formatting Preview")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text(appSettingsManager.format(Decimal(12345.67)))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Section("REGIONAL RULES") {
                    Picker("Start of Week", selection: $store.weekStartDay) {
                        ForEach(WeekStartDay.allCases) { day in
                            Text(day.rawValue).tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("LOCALE POLICY")) {
                    Text("All regional formatting and calculations are computed locally using Swift Locales. Your finance metrics never leave BuxMuse.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Currency & Region")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCurrencySheet) {
            CurrencyRegionPickerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: store.weekStartDay) { _, _ in store.save() }
    }
}
