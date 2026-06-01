//
//  BurnoutGuardSettingsView.swift
//  BuxMuse
//
//  Creative Energy widget — manual tuning on Simple; HealthKit sync on Pro.
//

import SwiftUI

struct BurnoutGuardSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @ObservedObject private var store = SettingsStore.shared

    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?
    @State private var healthKitDenied = false

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Creative Energy widget") {
                Toggle(isOn: $store.burnoutGuardEnabled.animation(.spring(response: 0.3, dampingFraction: 0.75))) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Show on Home dashboard")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Tracks workload, sleep, and stress signals into a Creative Energy score.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()
            }

            if store.burnoutGuardEnabled {
                BuxFormSection(title: "Manual tuning (Simple & Pro)") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Default sleep hours")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(String(format: "%.1f hrs", store.manualSleepHours))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.current.accentColor)
                            }
                            Slider(value: $store.manualSleepHours, in: 4...10, step: 0.5)
                                .tint(themeManager.current.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Default stress level")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("\(Int(store.manualStressLevel))/10")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            Slider(value: $store.manualStressLevel, in: 1...10, step: 1)
                                .tint(.orange)
                        }
                    }
                    .buxFormFieldPadding()
                }

                BuxFormSection(title: "Apple Health sync") {
                    if StudioFeatureGate.isPro {
                        Toggle(isOn: healthKitBinding) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("Sync sleep from HealthKit")
                                        .font(.system(size: 15, weight: .semibold))
                                    ProFeatureBadge(compact: true)
                                }
                                Text("Uses last week's sleep analysis when authorized. Falls back to manual values if unavailable.")
                                    .font(.system(size: 12, weight: .medium))
                                    .buxLabelSecondary()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(.green)
                        .buxFormFieldPadding()

                        if healthKitDenied {
                            Text("Health access was denied. Enable Sleep in Settings → Health → Data Access, or keep using manual sliders.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                                .buxFormFieldPadding()
                        }
                    } else {
                        Button {
                            proUpsellFeature = .burnoutHealthKit
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "applewatch.side.right")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text("HealthKit sleep sync")
                                            .font(.system(size: 15, weight: .bold))
                                        ProFeatureBadge(compact: true)
                                    }
                                    Text("Upgrade to Pro Studio for automatic sleep scoring from Apple Health.")
                                        .font(.system(size: 12, weight: .medium))
                                        .buxLabelSecondary()
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .buxLabelSecondary()
                            }
                            .buxFormFieldPadding()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Creative Energy")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.burnoutGuardEnabled) { _, _ in store.save() }
        .onChange(of: store.manualSleepHours) { _, _ in store.save() }
        .onChange(of: store.manualStressLevel) { _, _ in store.save() }
        .sheet(item: $proUpsellFeature) { feature in
            StudioProUpsellSheet(feature: feature)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(studioStore)
                .environmentObject(simpleStudioStore)
        }
    }

    private var healthKitBinding: Binding<Bool> {
        Binding(
            get: { store.healthKitSyncEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let ok = await BurnoutEngine.shared.requestHealthKitAuthorization()
                        await MainActor.run {
                            if ok {
                                store.healthKitSyncEnabled = true
                                healthKitDenied = false
                            } else {
                                store.healthKitSyncEnabled = false
                                healthKitDenied = true
                            }
                            store.save()
                        }
                    }
                } else {
                    store.healthKitSyncEnabled = false
                    store.save()
                }
            }
        )
    }
}
