//
//  FreelanceSettingsView.swift
//  BuxMuse
//
//  Freelance Hub master preferences and corporate invoicing settings.
//

import SwiftUI
import PhotosUI

struct FreelanceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared
    
    // Connects directly to FreelanceStore for seamless hub persistence
    @EnvironmentObject private var freelanceStore: FreelanceStore
    
    @State private var displayName = ""
    @State private var businessName = ""
    @State private var countryCode = ""
    @State private var businessType: BusinessType = .freelancer
    @State private var vatRegistered = false
    @State private var paymentTerms = 30
    @State private var hourlyRate = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedLogoData: Data? = nil
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            Form {
                Section("HUB SWITCHBOARD") {
                    Toggle(isOn: $store.freelanceEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Freelance Hub")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            Text("Unlock billing, invoices, client CRM, and document scans")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if store.freelanceEnabled {
                    Section("BUSINESS PROFILE DETAILS") {
                        HStack(spacing: BuxLayout.section) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                if let data = selectedLogoData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(themeManager.current.accentColor.opacity(0.12))
                                            .frame(width: 64, height: 64)
                                        
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(themeManager.current.accentColor)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Company Logo")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                
                                Text("Displayed on PDF client invoices.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        TextField("Full Name", text: $displayName)
                        TextField("Business Name", text: $businessName)
                        
                        Picker("Business Type", selection: $businessType) {
                            ForEach(BusinessType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    }
                    
                    Section("REGIONAL SETTINGS") {
                        TextField("Country Code (e.g. US, UK)", text: $countryCode)
                            .autocapitalization(.allCharacters)
                        
                        Toggle("VAT/GST Registered", isOn: $vatRegistered)
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
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Freelance Hub")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFreelanceProfile()
        }
        .onChange(of: store.freelanceEnabled) { _, _ in store.save() }
        .onChange(of: displayName) { _, _ in saveFreelanceProfile() }
        .onChange(of: businessName) { _, _ in saveFreelanceProfile() }
        .onChange(of: countryCode) { _, _ in saveFreelanceProfile() }
        .onChange(of: businessType) { _, _ in saveFreelanceProfile() }
        .onChange(of: vatRegistered) { _, _ in saveFreelanceProfile() }
        .onChange(of: paymentTerms) { _, _ in saveFreelanceProfile() }
        .onChange(of: hourlyRate) { _, _ in saveFreelanceProfile() }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    self.selectedLogoData = data
                    saveFreelanceProfile()
                }
            }
        }
    }
    
    private func loadFreelanceProfile() {
        let p = freelanceStore.profile
        displayName = p.displayName
        businessName = p.businessName
        countryCode = p.countryCode
        businessType = p.businessType
        vatRegistered = p.vatRegistered
        paymentTerms = p.defaultInvoicePaymentTerms
        selectedLogoData = p.logoData
        if let rate = p.defaultHourlyRate {
            hourlyRate = "\(rate)"
        } else {
            hourlyRate = ""
        }
    }
    
    private func saveFreelanceProfile() {
        var profile = freelanceStore.profile
        profile.displayName = displayName
        profile.businessName = businessName
        profile.countryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "US" : countryCode
        profile.businessType = businessType
        profile.vatRegistered = vatRegistered
        profile.defaultInvoicePaymentTerms = paymentTerms
        profile.logoData = selectedLogoData
        if let decimalRate = Decimal(string: hourlyRate) {
            profile.defaultHourlyRate = decimalRate
        } else {
            profile.defaultHourlyRate = nil
        }
        freelanceStore.updateProfile(profile)
    }
}
