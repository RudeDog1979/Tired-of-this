//
//  BuxAppLockOverlay.swift
//  BuxMuse
//
//  Enforces biometric / PIN unlock when security settings require it.
//

import SwiftUI
import LocalAuthentication

struct BuxAppLockOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let onUnlocked: () -> Void

    @State private var enteredPIN = ""
    @State private var errorMessage: String?
    @State private var isAuthenticating = false

    private var hasPasscode: Bool {
        SettingsStore.shared.hasAppPasscode
    }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThickMaterial)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(themeManager.current.accentColor)

                Text("BuxMuse Vault Active")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text("Authenticate to continue")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)

                if SettingsStore.shared.biometricLockEnabled {
                    Button(action: attemptBiometricUnlock) {
                        Label("Unlock with Face ID / Touch ID", systemImage: "faceid")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(themeManager.current.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(BuxMicroShrinkStyle())
                    .disabled(isAuthenticating)
                }

                if hasPasscode {
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .fill(index < enteredPIN.count ? themeManager.current.accentColor : Color.clear)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(themeManager.current.accentColor, lineWidth: 1.5))
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                            ForEach(1...9, id: \.self) { num in
                                pinKey("\(num)")
                            }
                            Color.clear.frame(height: 56)
                            pinKey("0")
                            Button(action: deletePIN) {
                                Image(systemName: "delete.left.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    .frame(width: 56, height: 56)
                            }
                            .buttonStyle(BuxMicroShrinkStyle())
                        }
                        .padding(.horizontal, 48)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            if SettingsStore.shared.biometricLockEnabled {
                attemptBiometricUnlock()
            }
        }
    }

    private func pinKey(_ digit: String) -> some View {
        Button(action: { appendPIN(digit) }) {
            Text(digit)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                )
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }

    private func appendPIN(_ digit: String) {
        guard enteredPIN.count < 4 else { return }
        errorMessage = nil
        enteredPIN.append(digit)
        if enteredPIN.count == 4 {
            verifyPIN()
        }
    }

    private func deletePIN() {
        errorMessage = nil
        if !enteredPIN.isEmpty {
            enteredPIN.removeLast()
        }
    }

    private func verifyPIN() {
        guard let stored = KeychainHelper.shared.retrievePasscode() else {
            errorMessage = "No passcode configured."
            enteredPIN = ""
            return
        }
        if enteredPIN == stored {
            onUnlocked()
        } else {
            errorMessage = "Incorrect passcode."
            enteredPIN = ""
        }
    }

    private func attemptBiometricUnlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil

        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to unlock BuxMuse"
            ) { success, authError in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    if success {
                        onUnlocked()
                    } else if let authError {
                        errorMessage = authError.localizedDescription
                    }
                }
            }
        } else {
            isAuthenticating = false
            if !hasPasscode {
                errorMessage = error?.localizedDescription ?? "Biometrics unavailable."
            }
        }
    }
}
