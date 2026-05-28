//
//  RegionCurrencySettingsView.swift
//  BuxMuse
//
//  Global country and currency — single source of truth for the whole app.
//

import SwiftUI

struct RegionCurrencySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared

    @State private var showCountrySheet = false
    @State private var showCurrencySheet = false
    @State private var pendingCountry: CountrySetting?
    @State private var showCurrencySuggestion = false

    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            BuxHeroMeshBackground()

            Form {
                Section("YOUR REGION") {
                    Button(action: { showCountrySheet = true }) {
                        HStack {
                            Text("Country / Region")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Spacer()
                            Text("\(appSettingsManager.selectedCountry.flag) \(appSettingsManager.selectedCountry.id)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeManager.current.accentColor)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }

                    Text(appSettingsManager.selectedCountry.name)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Section("DISPLAY CURRENCY") {
                    Button(action: { showCurrencySheet = true }) {
                        HStack {
                            Text("Preferred Currency")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
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
                    Text("Country and currency apply across BuxMuse — dashboard, expenses, invoices, and tax tools. Auto-detected from your device on first launch; you can change either independently.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Currency & Region")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCountrySheet) {
            CountryPickerView { country in
                if country.defaultCurrencyCode != appSettingsManager.selectedCurrency.id,
                   AppSettingsManager.availableCurrencies.contains(where: { $0.id == country.defaultCurrencyCode }) {
                    pendingCountry = country
                    showCurrencySuggestion = true
                } else {
                    appSettingsManager.updateCountry(country, suggestCurrency: false)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .environment(\.settingsEnhancedTint, true)
        }
        .sheet(isPresented: $showCurrencySheet) {
            CurrencyRegionPickerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .environment(\.settingsEnhancedTint, true)
        }
        .confirmationDialog(
            "Update currency too?",
            isPresented: $showCurrencySuggestion,
            titleVisibility: .visible
        ) {
            Button("Use \(pendingCountry?.defaultCurrencyCode ?? "local") currency") {
                if let pendingCountry {
                    appSettingsManager.updateCountry(pendingCountry, suggestCurrency: true)
                }
                pendingCountry = nil
            }
            Button("Keep \(appSettingsManager.selectedCurrency.id)") {
                if let pendingCountry {
                    appSettingsManager.updateCountry(pendingCountry, suggestCurrency: false)
                }
                pendingCountry = nil
            }
            Button("Cancel", role: .cancel) {
                pendingCountry = nil
            }
        } message: {
            Text("\(pendingCountry?.name ?? "This country") typically uses \(pendingCountry?.defaultCurrencyCode ?? "a local currency").")
        }
        .onChange(of: store.weekStartDay) { _, _ in store.save() }
    }
}

// MARK: - Country picker sheet

struct CountryPickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    let onSelect: (CountrySetting) -> Void

    private var filteredCountries: [CountrySetting] {
        CountryCatalog.filtered(matching: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Country / Region")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text("Used for tax presets, formatting, and regional defaults")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .frame(width: 32, height: 32)
                        .background(themeManager.chipMutedFill(for: colorScheme))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 16)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search country or code...", text: $searchText)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .settingsThemedCardChrome(cornerRadius: 14)
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(filteredCountries) { country in
                        Button {
                            onSelect(country)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(country.flag).font(.system(size: 24))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(country.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    Text("\(country.id) · typical \(country.defaultCurrencyCode)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if appSettingsManager.selectedCountry.id == country.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.current.accentColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .settingsThemedCardChrome(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.bottom, 24)
            }
        }
        .background {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                BuxHeroMeshBackground()
            }
            .ignoresSafeArea()
        }
        .buxThemedPresentation()
        .environment(\.settingsEnhancedTint, true)
    }
}
