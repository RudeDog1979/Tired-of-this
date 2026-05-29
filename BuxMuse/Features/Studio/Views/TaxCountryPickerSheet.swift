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
                    .background(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.vertical, 10)

                    Text("\(filteredCountries.count) countries")
                        .font(.system(size: 11, weight: .semibold))
                        .buxLabelSecondary()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, BuxLayout.marginHorizontal)
                        .padding(.bottom, 6)

                    if filteredCountries.isEmpty {
                        VStack(spacing: 12) {
                            if taxManager.isLoading {
                                ProgressView()
                                Text("Loading tax presets…")
                                    .font(.system(size: 14, weight: .medium))
                                    .buxLabelSecondary()
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 28))
                                    .buxLabelSecondary()
                                Text("No countries available")
                                    .font(.system(size: 15, weight: .semibold))
                                if let error = taxManager.lastLoadError {
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 24)
                                } else {
                                    Text("Check your connection or try again later.")
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
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Choose Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
