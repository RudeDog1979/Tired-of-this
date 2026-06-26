//
//  AppleWalletSyncSheet.swift
//  BuxMuse
//
//  Premium segmented sheet for selecting FinanceKit historical import range.
//

import SwiftUI

struct AppleWalletSyncSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    
    @StateObject private var syncManager = BuxFinanceKitManager.shared
    @State private var selectedRange: FinanceKitImportRange = .oneMonth
    @State private var showingSuccess = false
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header Indicator
                Capsule()
                    .fill(themeManager.labelPrimary(for: colorScheme).opacity(0.15))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                // Title Group
                HStack(spacing: 12) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.title)
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(BuxLocalizedString.string("Apple Wallet Import", locale: appSettingsManager.interfaceLocale))
                            .font(.headline)
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        
                        Text(BuxLocalizedString.string("Download Cash, Card, and Savings transactions", locale: appSettingsManager.interfaceLocale))
                            .font(.caption)
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                if syncManager.isSyncing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                        
                        Text(BuxLocalizedString.string("Downloading transaction data...", locale: appSettingsManager.interfaceLocale))
                            .font(.subheadline)
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                    .frame(height: 120)
                } else if showingSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text(BuxLocalizedString.string("Sync Complete!", locale: appSettingsManager.interfaceLocale))
                            .font(.headline)
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    }
                    .frame(height: 120)
                    .onAppear {
                        // Play a light haptic tap on success
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            dismiss()
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        // Range Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text(BuxLocalizedString.string("Historical Import Period", locale: appSettingsManager.interfaceLocale))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                .padding(.horizontal, 24)
                            
                            Picker(
                                BuxLocalizedString.string("Import Period", locale: appSettingsManager.interfaceLocale),
                                selection: $selectedRange
                            ) {
                                ForEach(FinanceKitImportRange.allCases) { range in
                                    Text(range.localizedDisplayName(locale: appSettingsManager.interfaceLocale)).tag(range)
                                }
                            }
                            .buxThemedSegmentedPicker()
                            .padding(.horizontal, 20)
                        }
                        
                        // Error message banner
                        if let error = syncManager.lastSyncError {
                            Text(BuxFinanceKitManager.localizedSyncErrorMessage(error, locale: appSettingsManager.interfaceLocale))
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        // Action Buttons
                        HStack(spacing: 16) {
                            BuxButton(
                                title: BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale),
                                role: .secondary,
                                size: .regular
                            ) {
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            
                            BuxButton(
                                title: BuxCatalogLabel.string("Import Data", locale: appSettingsManager.interfaceLocale),
                                role: .primary,
                                size: .regular
                            ) {
                                triggerSync()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    private func triggerSync() {
        // Trigger haptic button press
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            let authorized = await syncManager.ensureAuthorizedForWalletAccess()
            if authorized {
                await syncManager.syncTransactions(range: selectedRange)
                if syncManager.lastSyncError == nil {
                    brain.refreshExpensesAfterWalletSync()
                    showingSuccess = true
                }
            }
        }
    }
}
