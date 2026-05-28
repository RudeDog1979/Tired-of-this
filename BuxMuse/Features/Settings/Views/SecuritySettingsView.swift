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
    @ObservedObject private var store = SettingsStore.shared
    
    @State private var showPasscodeSetup = false
    @State private var showPasscodeClearConfirmation = false
    @State private var biometricErrorMsg: String? = nil
    
    private var bgColor: Color {
        themeManager.screenBackground(for: colorScheme)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            BuxHeroMeshBackground()

            Form {
                Section("BIOMETRIC ACCESS") {
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
                            Text("Face ID / Touch ID")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Fast, private verification via Apple Secure Enclave")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if store.biometricLockEnabled {
                        Toggle("Require Lock on App Launch", isOn: $store.requireBiometricOnLaunch)
                        
                        Picker("Lock After Inactivity", selection: $store.lockAfterInactivityMinutes) {
                            Text("Immediately").tag(0)
                            Text("1 Minute").tag(1)
                            Text("5 Minutes").tag(5)
                            Text("15 Minutes").tag(15)
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("PIN PASSCODE") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Secure App Passcode")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Text("Numeric secondary passcode backup")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        if store.hasAppPasscode {
                            Button(action: { showPasscodeClearConfirmation = true }) {
                                Text("Disable PIN")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: { showPasscodeSetup = true }) {
                                Text("Enable PIN")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("PRIVACY SHIELD") {
                    Toggle(isOn: $store.privacyBlurInAppSwitching) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Blur in App Switcher")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Hides your financial sheets when toggling tasks")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Security & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPasscodeSetup) {
            PasscodeSetupSheet { pin in
                store.setPasscode(pin)
                store.save()
            }
            .environment(\.settingsEnhancedTint, true)
        }
        .confirmationDialog("Disable PIN Code?", isPresented: $showPasscodeClearConfirmation, titleVisibility: .visible) {
            Button("Remove Passcode", role: .destructive) {
                store.clearPasscode()
                store.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete your local generic password from Apple Keychain.")
        }
        .onChange(of: store.requireBiometricOnLaunch) { _, _ in store.save() }
        .onChange(of: store.lockAfterInactivityMinutes) { _, _ in store.save() }
        .onChange(of: store.privacyBlurInAppSwitching) { _, _ in store.save() }
        .alert("Security Lock Error", isPresented: Binding(
            get: { biometricErrorMsg != nil },
            set: { isShown in
                if !isShown {
                    biometricErrorMsg = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
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
            let reason = "Authenticate to unlock BuxMuse security"
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
                self.biometricErrorMsg = error?.localizedDescription ?? "Face ID or Touch ID is not supported or not enrolled on this device. Please verify your iOS Settings."
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
                    Text(passcodeStep == 1 ? "Enter a 4-Digit Passcode" : "Confirm your Passcode")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    
                    Text("This code secures BuxMuse locally on your device.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
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
                ZStack {
                    themeManager.screenBackground(for: colorScheme)
                    BuxHeroMeshBackground()
                }
                .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func indicatorColor(for index: Int) -> Color {
        let currentString = passcodeStep == 1 ? enteredPIN : confirmedPIN
        if index < currentString.count {
            return themeManager.current.accentColor
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
                            self.errorMsg = "PINs do not match. Try again."
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
