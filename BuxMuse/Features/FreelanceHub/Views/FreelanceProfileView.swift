//
//  FreelanceProfileView.swift
//  BuxMuse
//
//  Interactive Profile Sandbox allowing custom business defaults and logo upload.
//

import SwiftUI
import PhotosUI

struct FreelanceProfileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: FreelanceStore
    
    @State private var displayName = ""
    @State private var businessName = ""
    @State private var countryCode = ""
    @State private var currencyCode = ""
    @State private var businessType: BusinessType = .freelancer
    @State private var vatRegistered = false
    @State private var paymentTerms = 30
    @State private var hourlyRate = ""
    
    // Photo selection state
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedLogoData: Data? = nil
    
    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            Form {
                Section("BUSINESS DETAILS") {
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
                            
                            Text("Stored locally in local Sandbox.")
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
                    
                    TextField("Currency Code (e.g. USD, EUR)", text: $currencyCode)
                        .autocapitalization(.allCharacters)
                    
                    Toggle("VAT/GST Registered", isOn: $vatRegistered)
                }
                
                Section("INVOICING DEFAULTS") {
                    Stepper("Payment Terms: \(paymentTerms) Days", value: $paymentTerms, in: 0...120, step: 1)
                    
                    TextField("Default Hourly Rate", text: $hourlyRate)
                        .keyboardType(.decimalPad)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Freelance Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                    dismiss()
                }
                .disabled(displayName.isEmpty || businessName.isEmpty)
            }
        }
        .onAppear {
            loadProfile()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    self.selectedLogoData = data
                }
            }
        }
    }
    
    private func loadProfile() {
        let p = store.profile
        displayName = p.displayName
        businessName = p.businessName
        countryCode = p.countryCode
        currencyCode = p.currencyCode
        businessType = p.businessType
        vatRegistered = p.vatRegistered
        paymentTerms = p.defaultInvoicePaymentTerms
        selectedLogoData = p.logoData
        if let rate = p.defaultHourlyRate {
            hourlyRate = "\(rate)"
        }
    }
    
    private func saveProfile() {
        var profile = store.profile
        profile.displayName = displayName
        profile.businessName = businessName
        profile.countryCode = countryCode
        profile.currencyCode = currencyCode
        profile.businessType = businessType
        profile.vatRegistered = vatRegistered
        profile.defaultInvoicePaymentTerms = paymentTerms
        profile.logoData = selectedLogoData
        profile.defaultHourlyRate = Decimal(string: hourlyRate)
        store.updateProfile(profile)
    }
}
