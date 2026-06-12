//
//  BurnoutDashboardWidget.swift
//  BuxMuse
//  Features/Insights/
//
//  Premium SwiftUI Dashboard Widget displaying Creative Energy & Burnout Index.
//

import SwiftUI
import HealthKit

public struct BurnoutDashboardWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var goalsViewModel: GoalsViewModel
    @EnvironmentObject private var insightsViewModel: InsightsViewModel
    @EnvironmentObject private var studioStore: StudioStore
    
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var engine = BurnoutEngine.shared
    
    @State private var localSleepHours: Double = 7.5
    @State private var localStressLevel: Double = 5.0
    @State private var isEditingSliders = false
    @State private var alertGlowPhase = false
    
    public init() {}
    
    private var energyColor: Color {
        let pct = engine.currentStatus.creativeEnergyPercent
        if pct > 75.0 {
            return Color(red: 46/255, green: 204/255, blue: 113/255) // Green
        } else if pct > 45.0 {
            return Color.orange
        } else {
            return Color.red
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(energyColor)
                    
                    BuxCatalogText.text("Creative Energy")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }
                
                Spacer()
                
                if !settings.healthKitSyncEnabled {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isEditingSliders.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            BuxCatalogText.text(isEditingSliders ? "Done" : "Tune")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    .buttonStyle(BuxMicroShrinkStyle())
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "applewatch.side.right")
                        BuxCatalogText.text("Synced")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 16) {
                // Circle creative battery gauge
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5).opacity(colorScheme == .dark ? 0.3 : 0.5), lineWidth: 10)
                        .frame(width: 82, height: 82)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(engine.currentStatus.creativeEnergyPercent / 100.0))
                        .stroke(
                            AngularGradient(
                                colors: [energyColor, energyColor.opacity(0.7), energyColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 82, height: 82)
                        .rotationEffect(.degrees(-90))
                        .animation(.buxBounce, value: engine.currentStatus.creativeEnergyPercent)
                    
                    VStack(spacing: 0) {
                        Text(
                            BuxLocalizedString.format(
                                "%lld%%",
                                locale: appSettingsManager.interfaceLocale,
                                Int(engine.currentStatus.creativeEnergyPercent)
                            )
                        )
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        
                        BuxCatalogText.text("battery")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    }
                }
                .padding(.leading, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        Text(
                            BuxLocalizedString.format(
                                "Work logged: %@ hrs",
                                locale: appSettingsManager.interfaceLocale,
                                String(format: "%.1f", engine.currentStatus.workHours)
                            )
                        )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.indigo)
                        Text(
                            BuxLocalizedString.format(
                                "Sleep: %@ hrs",
                                locale: appSettingsManager.interfaceLocale,
                                String(format: "%.1f", engine.currentStatus.sleepHours)
                            )
                        )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text(
                            BuxLocalizedString.format(
                                "Anxiety count: %lld",
                                locale: appSettingsManager.interfaceLocale,
                                engine.currentStatus.stressExpenseCount
                            )
                        )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            if isEditingSliders && !settings.healthKitSyncEnabled {
                Divider().opacity(0.08)
                    .transition(.opacity)
                
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            BuxCatalogText.text("Night sleep duration")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                            Spacer()
                            Text(
                                BuxLocalizedString.format(
                                    "%@ hours",
                                    locale: appSettingsManager.interfaceLocale,
                                    String(format: "%.1f", localSleepHours)
                                )
                            )
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        }
                        Slider(value: $localSleepHours, in: 4.0...10.0, step: 0.5)
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            BuxCatalogText.text("Subjective stress zone")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                            Spacer()
                            Text(
                                BuxLocalizedString.format(
                                    "Level %lld/10",
                                    locale: appSettingsManager.interfaceLocale,
                                    Int(localStressLevel)
                                )
                            )
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(Color.orange)
                        }
                        Slider(value: $localStressLevel, in: 1.0...10.0, step: 1.0)
                            .tint(Color.orange)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .onChange(of: localSleepHours) { _, val in
                    settings.manualSleepHours = val
                    triggerRecalculate()
                }
                .onChange(of: localStressLevel) { _, val in
                    settings.manualStressLevel = val
                    triggerRecalculate()
                }
            }
            
            if engine.currentStatus.stressIndex >= 0.85 {
                Divider().opacity(0.08)
                    .transition(.opacity)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.trianglebadge.exclamationmark.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                        BuxCatalogText.text("High Stress Alert")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    }
                    BuxCatalogText.text("Your stress index has breached the 0.85 threshold. We suggest enabling Sunset mode to reduce cognitive overload and ocular strain.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    
                    if themeManager.current.id != "sunsetVibes" {
                        Button(action: {
                            themeManager.select(.sunsetVibes)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sun.horizon.fill")
                                BuxCatalogText.text("Switch to Sunset Theme")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }
                        .buttonStyle(BuxMicroShrinkStyle())
                    }
                }
                .padding(8)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(12)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding(BuxTokens.section)
        .dashboardMaterialCardChrome(.outlined)
        .buxInterfaceLocale()
        .onAppear {
            localSleepHours = settings.manualSleepHours
            localStressLevel = settings.manualStressLevel
            triggerRecalculate()
        }
        .task {
            triggerRecalculate()
        }
    }
    
    private func triggerRecalculate() {
        Task {
            let txs = financialBridge.engine.allTransactions()
            let projects = studioStore.projects
            await engine.recalculate(projects: projects, transactions: txs, settings: settings)
        }
    }
}
