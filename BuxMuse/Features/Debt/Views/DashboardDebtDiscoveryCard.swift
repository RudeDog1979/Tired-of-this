//
//  DashboardDebtDiscoveryCard.swift
//  BuxMuse
//
//  Home prompt until the user enables debt tracking and logs their first balance.
//

import SwiftUI

struct DashboardDebtDiscoveryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var debtEngine: DebtEngine
    @EnvironmentObject private var tutorialCoordinator: AppTutorialCoordinator
    @ObservedObject private var store = SettingsStore.shared

    @State private var showAddSheet = false

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: store.consumerDebtEnabled ? "creditcard.and.123" : "creditcard.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if store.consumerDebtEnabled {
                            BuxCatalogText.text("Log your first debt")
                        } else {
                            BuxCatalogText.text("Track what you owe")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                    Group {
                        if store.consumerDebtEnabled {
                            BuxCatalogText.text("Banks, family loans, and informal lenders — all in one place.")
                        } else {
                            BuxCatalogText.text("Turn on consumer debt tracking to see balances, reminders, and payoff insights.")
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    if !store.consumerDebtEnabled {
                        store.consumerDebtEnabled = true
                        store.save()
                        PersonalCloudSyncEngine.shared.scheduleSettingsPush()
                    }
                    showAddSheet = true
                } label: {
                    Group {
                        if store.consumerDebtEnabled {
                            BuxCatalogText.text("Log debt")
                        } else {
                            BuxCatalogText.text("Turn on & log debt")
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)

                Button {
                    store.debtDiscoveryDeferred = true
                    store.save()
                } label: {
                    BuxCatalogText.text("Not now")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(BuxTokens.section)
        .dashboardMaterialCardChrome(.outlined)
        .tutorialAnchor(.homeDebtDiscovery, coordinator: tutorialCoordinator)
        .sheet(isPresented: $showAddSheet) {
            DebtEditorSheet()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(debtEngine)
        }
    }
}
