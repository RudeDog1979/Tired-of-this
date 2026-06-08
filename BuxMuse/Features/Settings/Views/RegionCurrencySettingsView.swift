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

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Your region") {
                Button(action: { showCountrySheet = true }) {
                    HStack {
                        BuxCatalogDynamicText(key: "Country / region")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        Text(
                            BuxLocalizedString.format(
                                "%@ %@",
                                locale: appSettingsManager.interfaceLocale,
                                appSettingsManager.selectedCountry.flag,
                                appSettingsManager.selectedCountry.id
                            )
                        )
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .buxChevronMuted()
                    }
                }
                .buttonStyle(.plain)
                .buxFormFieldPadding()
                Text(appSettingsManager.selectedCountry.name)
                    .font(.system(size: 12))
                    .buxLabelSecondary()
                    .buxFormFieldPadding()
            }

            BuxFormSection(title: "Display currency") {
                Button(action: { showCurrencySheet = true }) {
                    HStack {
                        BuxCatalogDynamicText(key: "Preferred currency")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Spacer()
                        Text(
                            BuxLocalizedString.format(
                                "%@ %@",
                                locale: appSettingsManager.interfaceLocale,
                                appSettingsManager.selectedCurrency.flag,
                                appSettingsManager.selectedCurrency.id
                            )
                        )
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .buxChevronMuted()
                    }
                }
                .buttonStyle(.plain)
                .buxFormFieldPadding()
                BuxFormRowDivider()
                HStack {
                    BuxCatalogDynamicText(key: "Formatting preview")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(appSettingsManager.format(Decimal(12345.67)))
                        .font(.system(size: 14, weight: .medium))
                        .buxLabelSecondary()
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Regional rules") {
                Picker(selection: $store.weekStartDay) {
                    ForEach(WeekStartDay.allCases) { day in
                        Text(day.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(day)
                    }
                } label: {
                    Text(BuxCatalogLabel.string("Start of week", locale: appSettingsManager.interfaceLocale))
                }
                .pickerStyle(.menu)
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "App language") {
                Picker(selection: interfaceLanguageBinding) {
                    ForEach(AppInterfaceLanguage.allCases) { language in
                        Text(language.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(language)
                    }
                } label: {
                    BuxCatalogText.text("App language")
                }
                .pickerStyle(.menu)
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()
                BuxFormRowDivider()
                BuxCatalogDynamicText(key: "Choose UI language independently of country. Example: United Kingdom region with Spanish UI. Currency formatting still follows your preferred currency above.")
                    .font(.system(size: 11))
                    .buxLabelSecondary()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .buxFormFieldPadding()
            }
        }
        .id(appSettingsManager.interfaceLanguage.rawValue)
        .buxCatalogNavigationTitle("Currency & region")
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
            .buxThemedSheetContent()
        }
        .sheet(isPresented: $showCurrencySheet) {
            CurrencyRegionPickerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .environment(\.settingsEnhancedTint, true)
                .buxThemedSheetContent()
        }
        .confirmationDialog(
            BuxCatalogLabel.string("Update currency too?", locale: appSettingsManager.interfaceLocale),
            isPresented: $showCurrencySuggestion,
            titleVisibility: .visible
        ) {
            Button {
                if let pendingCountry {
                    appSettingsManager.updateCountry(pendingCountry, suggestCurrency: true)
                }
                pendingCountry = nil
            } label: {
                Text(
                    BuxLocalizedString.format(
                        "Use %@ currency",
                        locale: appSettingsManager.interfaceLocale,
                        pendingCountry?.defaultCurrencyCode
                            ?? BuxCatalogLabel.string("local", locale: appSettingsManager.interfaceLocale)
                    )
                )
            }
            Button {
                if let pendingCountry {
                    appSettingsManager.updateCountry(pendingCountry, suggestCurrency: false)
                }
                pendingCountry = nil
            } label: {
                Text(
                    BuxLocalizedString.format(
                        "Keep %@",
                        locale: appSettingsManager.interfaceLocale,
                        appSettingsManager.selectedCurrency.id
                    )
                )
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {
                pendingCountry = nil
            }
        } message: {
            Text(
                BuxLocalizedString.format(
                    "%@ typically uses %@.",
                    locale: appSettingsManager.interfaceLocale,
                    pendingCountry?.name ?? BuxCatalogLabel.string("This country", locale: appSettingsManager.interfaceLocale),
                    pendingCountry?.defaultCurrencyCode ?? BuxCatalogLabel.string("a local currency", locale: appSettingsManager.interfaceLocale)
                )
            )
        }
        .onChange(of: store.weekStartDay) { _, _ in store.save() }
    }

    private var interfaceLanguageBinding: Binding<AppInterfaceLanguage> {
        Binding(
            get: { appSettingsManager.interfaceLanguage },
            set: { appSettingsManager.updateInterfaceLanguage($0) }
        )
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
                    BuxCatalogDynamicText(key: "Country / region")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    BuxCatalogDynamicText(key: "Used for tax presets, formatting, and regional defaults")
                        .font(.system(size: 13, weight: .medium))
                        .buxLabelSecondary()
                }
                Spacer()
                BuxToolbarCloseButton { dismiss() }
            }
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 16)

            HStack {
                Image(systemName: "magnifyingglass")
                    .buxLabelSecondary()
                TextField(BuxCatalogLabel.string("Search country or code...", locale: appSettingsManager.interfaceLocale), text: $searchText)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").buxLabelSecondary()
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
                                    Text(
                                        BuxLocalizedString.format(
                                            "%@ · typical %@",
                                            locale: appSettingsManager.interfaceLocale,
                                            country.id,
                                            country.defaultCurrencyCode
                                        )
                                    )
                                        .font(.system(size: 11, weight: .medium))
                                        .buxLabelSecondary()
                                }
                                Spacer()
                                if appSettingsManager.selectedCountry.id == country.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
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
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
        }
        .buxThemedPresentation()
        .environment(\.settingsEnhancedTint, true)
    }
}
