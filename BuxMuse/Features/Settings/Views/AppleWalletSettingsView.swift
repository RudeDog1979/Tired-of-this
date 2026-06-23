//
//  AppleWalletSettingsView.swift
//  BuxMuse
//
//  Apple Wallet / FinanceKit transaction synchronization cockpit.
//

import SwiftUI

struct AppleWalletSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @ObservedObject private var store = SettingsStore.shared
    @StateObject private var syncManager = BuxFinanceKitManager.shared
    @State private var showSyncSheet = false

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Apple Wallet Integration") {
                Toggle(isOn: walletSyncToggle) {
                    VStack(alignment: .leading, spacing: 3) {
                        BuxCatalogDynamicText(key: "Sync Apple Wallet")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Download card and account transactions directly from Apple Wallet.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .buxFormFieldPadding()

                if let error = syncManager.lastSyncError {
                    Text(BuxFinanceKitManager.localizedSyncErrorMessage(error, locale: appSettingsManager.interfaceLocale))
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                if store.appleWalletSyncEnabled {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    Toggle(isOn: $store.appleWalletAutoSyncEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            BuxCatalogDynamicText(key: "Background Auto-Sync")
                                .font(.system(size: 15, weight: .semibold))
                            BuxCatalogDynamicText(key: "Automatically sync new transactions in the background when they occur.")
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                    .buxFormFieldPadding()
                }
            }

            if store.appleWalletSyncEnabled {
                BuxFormSection(title: "Import History") {
                    Button {
                        showSyncSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .semibold))
                            BuxCatalogDynamicText(key: "Import Historical Transactions")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(themeManager.chevronMuted(for: colorScheme))
                        }
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    }
                }
            }
        }
        .buxCatalogNavigationTitle("Apple Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSyncSheet) {
            AppleWalletSyncSheet()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
                .presentationDetents([.fraction(0.38), .medium])
                .presentationCornerRadius(28)
                .buxThemedSheetContent()
        }
    }

    private var walletSyncToggle: Binding<Bool> {
        Binding(
            get: { store.appleWalletSyncEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await syncManager.ensureAuthorizedForWalletAccess()
                        store.appleWalletSyncEnabled = granted
                    }
                } else {
                    store.appleWalletSyncEnabled = false
                    syncManager.clearLastSyncError()
                }
            }
        )
    }
}
