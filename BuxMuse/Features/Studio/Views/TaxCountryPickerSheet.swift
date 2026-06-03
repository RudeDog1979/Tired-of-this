//
//  TaxCountryPickerSheet.swift
//  BuxMuse
//
//  Searchable country preset picker — loads all countries dynamically from JSON.
//

import SwiftUI

struct TaxCountryPickerSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var taxManager = TaxManager.shared

    @Binding var searchQuery: String
    var onSelect: (TaxInfo) -> Void

    private var filteredCountries: [TaxInfo] {
        TaxPresetLoader.filteredCountries(matching: searchQuery)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .buxLabelSecondary()
                        TextField("Search country, ISO, or region", text: $searchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(12)
                    .buxThemedInputPlate(cornerRadius: 12)
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.vertical, 10)

                    HStack {
                        Text(
                            BuxLocalizedString.format(
                                "%lld countries",
                                locale: appSettingsManager.interfaceLocale,
                                Int64(filteredCountries.count)
                            )
                        )
                            .font(.system(size: 11, weight: .semibold))
                            .buxLabelSecondary()
                        Spacer()
                        if let updated = taxManager.catalogUpdatedAt {
                            Text(
                                BuxLocalizedString.format(
                                    "Updated %@",
                                    locale: appSettingsManager.interfaceLocale,
                                    updated
                                )
                            )
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(themeManager.current.accentColor.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.bottom, 6)

                    if filteredCountries.isEmpty {
                        VStack(spacing: 12) {
                            if taxManager.isLoading {
                                ProgressView()
                                BuxCatalogDynamicText(key: "Loading tax presets…")
                                    .font(.system(size: 14, weight: .medium))
                                    .buxLabelSecondary()
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 28))
                                    .buxLabelSecondary()
                                BuxCatalogDynamicText(key: "No countries available")
                                    .font(.system(size: 15, weight: .semibold))
                                if let error = taxManager.lastLoadError {
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                } else {
                                    BuxCatalogDynamicText(key: "Check your connection or try again later.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 40)
                    } else {
                        List {
                            ForEach(filteredCountries) { country in
                                Button {
                                    onSelect(country)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(country.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                        HStack(spacing: 6) {
                                            Text(country.isoCode)
                                            if let region = country.region {
                                                Text("•")
                                                Text(region)
                                            }
                                            if let currency = country.currency {
                                                Text("•")
                                                Text(currency)
                                            }
                                        }
                                        .font(.system(size: 11, weight: .medium))
                                        .buxLabelSecondary()
                                        Text(country.presetLineSummary)
                                            .font(.system(size: 11, weight: .medium))
                                            .buxLabelSecondary()
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)
                                    }
                                    .padding(.vertical, 4)
                                    .studioThemedListRowCard()
                                }
                                .studioThemedListRowChrome()
                            }
                        }
                        .studioThemedListRows()
                    }
                }
            }
            .buxCatalogNavigationTitle("Choose Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .task {
                await TaxPresetLoader.ensureCatalogLoaded()
            }
            .environment(\.studioEnhancedTint, true)
            .buxStudioSheetContent()
        }
    }
}
