//
//  StudioWorkClockPlanSection.swift
//  BuxMuse
//
//  Shared planned-time UI for Pro + Simple work clock (merge, no removals).
//

import SwiftUI

struct StudioWorkClockPlanCopy {
    let toggleTitle: String
    let toggleSubtitle: String
    let startHint: String
    let goalLabel: String
    let editEstimateTitle: String
    let extendTitle: String
    let liveActivityHint: String
    let pauseToggleTitle: String
    let pauseToggleSubtitle: String

    static let pro = StudioWorkClockPlanCopy(
        toggleTitle: "Estimated job time",
        toggleSubtitle: "Shows progress on Lock Screen and Dynamic Island",
        startHint: "Press Start to lock your estimate and show progress on the Lock Screen and Dynamic Island.",
        goalLabel: "Goal",
        editEstimateTitle: "Edit estimate",
        extendTitle: "Need more time?",
        liveActivityHint: "Turn on Live Activities for BuxMuse in Settings → BuxMuse.",
        pauseToggleTitle: "Auto-pause at estimate",
        pauseToggleSubtitle: "Stops the clock when you hit the goal (you can add time after)."
    )

    static let simple = StudioWorkClockPlanCopy(
        toggleTitle: "How long should this take?",
        toggleSubtitle: "Shows your little walker on the Lock Screen as you go",
        startHint: "Tap Start — then your phone shows how far through the job you are.",
        goalLabel: "Agreed time",
        editEstimateTitle: "Change time",
        extendTitle: "Need more time?",
        liveActivityHint: "Turn on Live Activities for BuxMuse in Settings → BuxMuse.",
        pauseToggleTitle: "Stop when time is up",
        pauseToggleSubtitle: "Clock pauses at the agreed time (add more if you need to)."
    )
}

struct StudioWorkClockPlanSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let copy: StudioWorkClockPlanCopy
    let accent: Color
    @Binding var hasPlan: Bool
    @Binding var planHours: Int
    @Binding var planMinutes: Int
    @Binding var autoPauseAtEnd: Bool
    let planLocked: Bool
    let timerRunning: Bool
    let lockedPlanLabel: String
    let showStartHint: Bool
    let showExtendControls: Bool
    let jobAlert: StudioTimerJobAlert
    let alertTitle: (StudioTimerJobAlert) -> String
    let alertMessage: (StudioTimerJobAlert) -> String
    var onUnlockPlan: () -> Void
    var onExtend30m: () -> Void
    var onExtend1h: () -> Void
    var budgetShortcutLabel: String?
    var onApplyBudgetShortcut: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            Toggle(isOn: $hasPlan) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy.toggleTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    Text(copy.toggleSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
            }
            .disabled(planLocked)

            if !StudioTimerLiveActivityManager.isSupported {
                Text(copy.liveActivityHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }

            if showStartHint {
                Text(copy.startHint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }

            if hasPlan {
                Toggle(isOn: $autoPauseAtEnd) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy.pauseToggleTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        Text(copy.pauseToggleSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    }
                }
                .disabled(planLocked)

                if planLocked {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy.goalLabel)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                            Text(lockedPlanLabel)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        }
                        Spacer()
                        if !timerRunning {
                            Button(copy.editEstimateTitle, action: onUnlockPlan)
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                } else {
                    HStack(spacing: BuxTokens.tight) {
                        Picker(BuxCatalogLabel.string("Hours", locale: appSettingsManager.interfaceLocale), selection: $planHours) {
                            ForEach(0..<13, id: \.self) { hour in
                                Text(
                                    BuxLocalizedString.format(
                                        "%lldh",
                                        locale: appSettingsManager.interfaceLocale,
                                        Int64(hour)
                                    )
                                )
                                .tag(hour)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker(BuxCatalogLabel.string("Minutes", locale: appSettingsManager.interfaceLocale), selection: $planMinutes) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { m in
                                Text(
                                    BuxLocalizedString.format(
                                        "%lldm",
                                        locale: appSettingsManager.interfaceLocale,
                                        Int64(m)
                                    )
                                )
                                .tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .disabled(planLocked)
                    .opacity(planLocked ? 0.45 : 1)

                    if let budgetShortcutLabel, let onApplyBudgetShortcut {
                        Button(budgetShortcutLabel, action: onApplyBudgetShortcut)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }

                workClockAlertBanner

                if showExtendControls {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(copy.extendTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                        HStack(spacing: BuxTokens.tight) {
                            BuxActionButton(
                                title: "+30m",
                                systemImage: "plus",
                                role: .secondary,
                                accent: accent,
                                expands: true,
                                action: onExtend30m
                            )
                            BuxActionButton(
                                title: "+1h",
                                systemImage: "plus",
                                role: .secondary,
                                accent: accent,
                                expands: true,
                                action: onExtend1h
                            )
                        }
                    }
                }
            }
        }
        .padding(BuxLayout.section)
        .studioThemedCardChrome(cornerRadius: 14)
        .padding(.horizontal, BuxLayout.marginHorizontal)
    }

    @ViewBuilder
    private var workClockAlertBanner: some View {
        switch jobAlert {
        case .none:
            EmptyView()
        case .approaching:
            alertChip(
                title: alertTitle(jobAlert),
                message: alertMessage(jobAlert),
                tint: .orange
            )
        case .atGoal:
            alertChip(
                title: alertTitle(jobAlert),
                message: alertMessage(jobAlert),
                tint: accent
            )
        case .overtime:
            alertChip(
                title: alertTitle(jobAlert),
                message: alertMessage(jobAlert),
                tint: .red
            )
        }
    }

    private func alertChip(title: String, message: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
