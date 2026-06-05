//
//  HealthKitConsentSheet.swift
//  BuxMuse
//
//  In-app privacy disclaimer before the system HealthKit permission dialog.
//

import SwiftUI

struct HealthKitConsentSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxTokens.block) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.green)
                            BuxCatalogDynamicText(key: "Apple Health & your privacy")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        }

                        BuxCatalogDynamicText(key: "BuxMuse never sees your Health data on our servers — there are no BuxMuse servers for your finances or wellness. Sleep data stays on this iPhone.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, BuxTokens.section)

                    VStack(alignment: .leading, spacing: 14) {
                        bullet("bed.double.fill", "Reads sleep analysis from Apple Health when you allow it")
                        bullet("iphone", "Processed on-device to improve your Creative Energy score")
                        bullet("lock.shield.fill", "Never uploaded, sold, or shared by BuxMuse")
                        bullet("arrow.uturn.backward", "Turn off anytime in Settings or iOS Health → Data Access")
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    BuxCatalogDynamicText(key: "Only Apple’s system permission dialog can grant access. BuxMuse cannot read Health data until you approve there.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.bottom, BuxTokens.sheetBottomClearance)
            }
            .background(themeManager.screenBackground(for: colorScheme).ignoresSafeArea())
            .buxCatalogNavigationTitle("Health access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    BuxButton(
                        title: "Continue to Apple Health",
                        systemImage: "heart.fill",
                        role: .primary,
                        expands: true
                    ) {
                        dismiss()
                        onContinue()
                    }
                    BuxButton(
                        title: "Not now",
                        systemImage: "xmark",
                        role: .secondary,
                        expands: true
                    ) {
                        dismiss()
                    }
                }
                .padding(.horizontal, BuxTokens.marginRegular)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .buxThemedSheetContent()
        .buxInterfaceLocale()
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.current.accentColor)
                .frame(width: 22)
            BuxCatalogDynamicText(key: text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
