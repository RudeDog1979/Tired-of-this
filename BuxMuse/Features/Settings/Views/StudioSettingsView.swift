//
//  StudioSettingsView.swift
//  BuxMuse
//
//  Freelance Hub master preferences — business identity and invoicing defaults.
//  Region, currency, and tax registration live in global Settings / Tax Profile.
//

import SwiftUI

struct StudioSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var appDataManager: AppDataManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @ObservedObject private var store = SettingsStore.shared
    @EnvironmentObject private var studioStore: StudioStore

    @State private var displayName = ""
    @State private var businessName = ""
    @State private var businessType: BusinessType = .freelancer
    @State private var paymentTerms = 30
    @State private var hourlyRate = ""
    @State private var logoData: Data?

    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    private var studioToggleOn: Bool {
        store.studioEnabled || navigationCoordinator.studioUnlockAwaitingCommit
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            BuxHeroMeshBackground()

            Form {
                if !store.studioEnabled {
                    Section {
                        Text("Studio adds invoices, mileage, receipts, and tax planning tools as an extra tab. Turn it on when you need it — your everyday Home and Expenses tabs stay the same.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("STUDIO") {
                    Toggle(isOn: studioToggleBinding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Studio Tab")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text("Invoices, expenses, tax tools, and client CRM")
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                        }
                    }
                    .padding(.vertical, 4)
                }

                if store.studioEnabled {
                    Section("BUSINESS PROFILE") {
                        PhotoPickCropRow(
                            title: "Company Logo",
                            subtitle: "Shown on exported invoice PDFs",
                            imageData: logoData,
                            cropShape: .roundedRectangle(cornerRadius: 12),
                            cropTitle: "Crop Logo",
                            previewSize: 64,
                            previewCornerRadius: 12
                        ) { data in
                            logoData = data
                            saveStudioProfile()
                        }

                        TextField("Full Name", text: $displayName)
                        TextField("Business Name", text: $businessName)

                        Picker("Business Type", selection: $businessType) {
                            ForEach(BusinessType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    }

                    Section("GLOBAL LOCALE") {
                        NavigationLink {
                            RegionCurrencySettingsView()
                        } label: {
                            HStack {
                                Text("Region & Currency")
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                Spacer()
                                Text("\(appSettingsManager.selectedCountry.flag) \(appSettingsManager.selectedCountry.name) · \(appSettingsManager.selectedCurrency.id)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .buxLabelSecondary()
                                    .lineLimit(1)
                            }
                        }

                        NavigationLink {
                            StudioTaxReferenceView()
                                .environmentObject(themeManager)
                                .environmentObject(appSettingsManager)
                                .environmentObject(appDataManager)
                                .environmentObject(studioStore)
                        } label: {
                            HStack {
                                Text("Tax Profile")
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                Spacer()
                                if studioStore.taxProfile.isTaxProfileConfigured {
                                    Text(studioStore.taxProfile.selectedTaxCountry ?? "Custom")
                                        .font(.system(size: 12, weight: .semibold))
                                        .buxLabelSecondary()
                                } else {
                                    Text("Not configured")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }

                    Section("INVOICING DEFAULTS") {
                        Stepper("Payment Terms: \(paymentTerms) Days", value: $paymentTerms, in: 0...120, step: 1)

                        HStack {
                            Text("Default Hourly Rate")
                            Spacer()
                            TextField("Rate", text: $hourlyRate)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }
            }
            .buxThemedFormStyle()
        }
        .navigationTitle("Studio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadStudioProfile() }
        .onChange(of: store.studioEnabled) { _, isEnabled in
            if isEnabled {
                loadStudioProfile()
            } else {
                store.save()
            }
        }
        .onChange(of: displayName) { _, _ in saveStudioProfile() }
        .onChange(of: businessName) { _, _ in saveStudioProfile() }
        .onChange(of: businessType) { _, _ in saveStudioProfile() }
        .onChange(of: paymentTerms) { _, _ in saveStudioProfile() }
        .onChange(of: hourlyRate) { _, _ in saveStudioProfile() }
    }

    private var studioToggleBinding: Binding<Bool> {
        Binding(
            get: { studioToggleOn },
            set: { enabled in
                if enabled {
                    guard !store.studioEnabled else { return }
                    navigationCoordinator.beginStudioUnlock()
                } else {
                    navigationCoordinator.cancelStudioUnlockIfPending()
                    store.studioEnabled = false
                    store.save()
                }
            }
        )
    }

    private func loadStudioProfile() {
        let p = studioStore.profile
        displayName = p.displayName
        businessName = p.businessName
        businessType = p.businessType
        paymentTerms = p.defaultInvoicePaymentTerms
        logoData = p.logoData
        hourlyRate = p.defaultHourlyRate.map { "\($0)" } ?? ""
    }

    private func saveStudioProfile() {
        var profile = studioStore.profile
        profile.displayName = displayName
        profile.businessName = businessName
        profile.businessType = businessType
        profile.defaultInvoicePaymentTerms = paymentTerms
        profile.logoData = logoData
        profile.defaultHourlyRate = Decimal(string: hourlyRate)
        studioStore.updateProfile(profile)
    }
}
