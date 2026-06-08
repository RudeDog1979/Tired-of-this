//
//  SecuritySettingsView.swift
//  BuxMuse
//
//  Biometric lock parameters, secure PIN setup, and switcher blur.
//

import SwiftUI
import LocalAuthentication

struct SecuritySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var store = SettingsStore.shared
    
    @State private var showPasscodeSetup = false
    @State private var showPasscodeClearConfirmation = false
    @State private var biometricErrorMsg: String? = nil
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Biometric access") {
                Toggle(isOn: Binding(
                    get: { store.biometricLockEnabled },
                    set: { enable in
                        if enable {
                            requestBiometricAuth { success in
                                if success {
                                    store.biometricLockEnabled = true
                                    store.save()
                                }
                            }
                        } else {
                            store.biometricLockEnabled = false
                            store.save()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Face ID / Touch ID")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Fast, private verification via Apple Secure Enclave")
                            .font(.system(size: 11))
                            .buxLabelSecondary()
                    }
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()

                if store.biometricLockEnabled {
                    BuxFormRowDivider()
                    Toggle(isOn: $store.requireBiometricOnLaunch) {
                        Text(BuxCatalogLabel.string("Require lock on app launch", locale: appSettingsManager.interfaceLocale))
                    }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Picker(selection: $store.lockAfterInactivityMinutes) {
                        BuxCatalogDynamicText(key: "Immediately").tag(0)
                        BuxCatalogDynamicText(key: "1 minute").tag(1)
                        BuxCatalogDynamicText(key: "5 minutes").tag(5)
                        BuxCatalogDynamicText(key: "15 minutes").tag(15)
                    } label: {
                        Text(BuxCatalogLabel.string("Lock after inactivity", locale: appSettingsManager.interfaceLocale))
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                }
            }

            BuxFormSection(title: "PIN passcode") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Secure app passcode")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        BuxCatalogDynamicText(key: "Numeric secondary passcode backup")
                            .font(.system(size: 11))
                            .buxLabelSecondary()
                    }
                    Spacer()

                    if store.hasAppPasscode {
                        Button(role: .destructive) {
                            showPasscodeClearConfirmation = true
                        } label: {
                            Text(BuxCatalogLabel.string("Disable PIN", locale: appSettingsManager.interfaceLocale))
                        }
                        .font(.system(size: 14, weight: .bold))
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { showPasscodeSetup = true }) {
                            BuxCatalogDynamicText(key: "Enable PIN")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .buxFormFieldPadding()
            }

            BuxFormSection(title: "Privacy shield") {
                Toggle(isOn: $store.privacyBlurInAppSwitching) {
                    VStack(alignment: .leading, spacing: 2) {
                        BuxCatalogDynamicText(key: "Blur in app switcher")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Hides your financial sheets when toggling tasks")
                            .font(.system(size: 11))
                            .buxLabelSecondary()
                    }
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()
            }
        }
        .buxCatalogNavigationTitle("Security & privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPasscodeSetup) {
            PasscodeSetupSheet { pin in
                store.setPasscode(pin)
                store.save()
            }
            .environment(\.settingsEnhancedTint, true)
            .buxThemedSheetContent()
        }
        .confirmationDialog(BuxCatalogLabel.string("Disable PIN Code?", locale: appSettingsManager.interfaceLocale), isPresented: $showPasscodeClearConfirmation, titleVisibility: .visible) {
            Button(BuxCatalogLabel.string("Remove Passcode", locale: appSettingsManager.interfaceLocale), role: .destructive) {
                store.clearPasscode()
                store.save()
            }
            Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            BuxCatalogDynamicText(key: "This will delete your local generic password from Apple Keychain.")
        }
        .onChange(of: store.requireBiometricOnLaunch) { _, _ in store.save() }
        .onChange(of: store.lockAfterInactivityMinutes) { _, _ in store.save() }
        .onChange(of: store.privacyBlurInAppSwitching) { _, _ in store.save() }
        .alert(BuxCatalogLabel.string("Security Lock Error", locale: appSettingsManager.interfaceLocale), isPresented: Binding(
            get: { biometricErrorMsg != nil },
            set: { isShown in
                if !isShown {
                    biometricErrorMsg = nil
                }
            }
        )) {
            Button(BuxCatalogLabel.string("OK", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            if let error = biometricErrorMsg {
                Text(error)
            }
        }
    }
    
    // MARK: - Biometric Helper
    
    private func requestBiometricAuth(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = BuxCatalogLabel.string("Authenticate to unlock BuxMuse security", locale: appSettingsManager.interfaceLocale)
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if let authError = authenticationError {
                        self.biometricErrorMsg = authError.localizedDescription
                    }
                    completion(success)
                }
            }
        } else {
            DispatchQueue.main.async {
                self.biometricErrorMsg = error?.localizedDescription ?? BuxCatalogLabel.string("Face ID or Touch ID is not supported or not enrolled on this device. Please verify your iOS Settings.", locale: appSettingsManager.interfaceLocale)
                completion(false)
            }
        }
    }
}

// MARK: - PIN Passcode Setup Sheet

struct PasscodeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    let onSave: (String) -> Void
    
    @State private var passcodeStep = 1 // 1: Enter, 2: Confirm
    @State private var enteredPIN = ""
    @State private var confirmedPIN = ""
    @State private var errorMsg: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 12) {
                    Text(BuxCatalogLabel.string(passcodeStep == 1 ? "Enter a 4-Digit Passcode" : "Confirm your Passcode", locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    
                    BuxCatalogDynamicText(key: "This code secures BuxMuse locally on your device.")
                        .font(.system(size: 13))
                        .buxLabelSecondary()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // PIN dots indicators
                HStack(spacing: 18) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(indicatorColor(for: index))
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(themeManager.current.accentColor, lineWidth: 1.5))
                    }
                }
                .padding(.vertical, 8)
                
                if let error = errorMsg {
                    Text(error)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Keypad grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 3), spacing: 20) {
                    ForEach(1...9, id: \.self) { num in
                        keypadButton(text: "\(num)")
                    }
                    
                    // Empty bottom-left
                    Spacer()
                    
                    keypadButton(text: "0")
                    
                    // Delete button
                    Button(action: deleteLastDigit) {
                        ZStack {
                            Circle().fill(Color.clear)
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 24))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        }
                        .frame(width: 72, height: 72)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
            }
            .background {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
        }
    }
    
    private func indicatorColor(for index: Int) -> Color {
        let currentString = passcodeStep == 1 ? enteredPIN : confirmedPIN
        if index < currentString.count {
            return themeManager.contrastAccentColor(for: colorScheme)
        } else {
            return Color.clear
        }
    }
    
    private func keypadButton(text: String) -> some View {
        Button(action: { digitPressed(text) }) {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                Text(text)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }
    
    private func digitPressed(_ digit: String) {
        errorMsg = nil
        if passcodeStep == 1 {
            if enteredPIN.count < 4 {
                enteredPIN.append(digit)
                if enteredPIN.count == 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.passcodeStep = 2
                    }
                }
            }
        } else {
            if confirmedPIN.count < 4 {
                confirmedPIN.append(digit)
                if confirmedPIN.count == 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if self.enteredPIN == self.confirmedPIN {
                            self.onSave(self.enteredPIN)
                            self.dismiss()
                        } else {
                            self.confirmedPIN = ""
                            self.enteredPIN = ""
                            self.passcodeStep = 1
                            self.errorMsg = BuxCatalogLabel.string("PINs do not match. Try again.", locale: appSettingsManager.interfaceLocale)
                        }
                    }
                }
            }
        }
    }
    
    private func deleteLastDigit() {
        errorMsg = nil
        if passcodeStep == 1 {
            if !enteredPIN.isEmpty {
                enteredPIN.removeLast()
            }
        } else {
            if !confirmedPIN.isEmpty {
                confirmedPIN.removeLast()
            }
        }
    }
}
