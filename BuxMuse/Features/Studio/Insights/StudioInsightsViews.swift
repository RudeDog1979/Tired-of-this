//
//  StudioInsightsViews.swift
//  BuxMuse
//

import SwiftUI

struct StudioInsightsHubSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let snapshot: StudioInsightsSnapshot
    var onOpenDashboard: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            HStack {
                BuxCatalogDynamicText(key: "STUDIO INSIGHTS")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
                Spacer()
                if onOpenDashboard != nil {
                    Button {
                        onOpenDashboard?()
                    } label: {
                        BuxCatalogText.text("See all")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(snapshot.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                if snapshot.scopeAlerts > 0 {
                    insightChip(
                        BuxLocalizedString.format(
                            "Scope alerts: %lld",
                            locale: appSettingsManager.interfaceLocale,
                            Int64(snapshot.scopeAlerts)
                        ),
                        icon: "scope",
                        color: .orange
                    )
                }
                if snapshot.timeLeakageHours >= 1 {
                    insightChip(
                        BuxLocalizedString.format(
                            "Time leakage: %.1fh non-billable",
                            locale: appSettingsManager.interfaceLocale,
                            snapshot.timeLeakageHours
                        ),
                        icon: "drop.triangle",
                        color: .blue
                    )
                }

                if let tip = snapshot.rateOptimizerTip {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text(tip)
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(snapshot.metrics.prefix(4)) { row in
                        metricTile(row)
                    }
                }
            }
            .padding(BuxLayout.section)
            .studioThemedCardChrome(cornerRadius: 20)
        }
    }

    private func insightChip(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func metricTile(_ row: StudioInsightRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: row.systemImage)
                .font(.system(size: 14))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            Text(row.value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            Text(row.title)
                .font(.system(size: 10, weight: .bold))
                .buxLabelSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct StudioInsightsDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore

    private var snapshot: StudioInsightsSnapshot {
        StudioInsightsEngine.build(
            projects: store.projects,
            invoices: store.invoices,
            receipts: store.receipts,
            simpleEntries: simpleStudioStore.entries,
            profile: store.profile,
            locale: appSettingsManager.interfaceLocale,
            currencyFormat: { appSettingsManager.format($0) }
        )
    }

    var body: some View {
        StudioThemedListBackdrop {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxTokens.block) {
                    StudioProToolScreenHeader(titleKey: "Studio Insights")
                        .studioProToolScrollPlacement()

                    Text(snapshot.headline)
                    .font(.system(size: 16, weight: .bold))
                    .padding(.horizontal, BuxTokens.marginRegular)

                if let tip = snapshot.rateOptimizerTip {
                    BuxThemedCardForm {
                        BuxFormSection(title: BuxCatalogLabel.string("Rate optimizer", locale: appSettingsManager.interfaceLocale)) {
                            Text(tip)
                                .font(.system(size: 13, weight: .medium))
                                .buxFormFieldPadding()
                        }
                    }
                    .padding(.horizontal, BuxTokens.marginRegular)
                }

                ForEach(snapshot.metrics) { row in
                    HStack(spacing: 14) {
                        Image(systemName: row.systemImage)
                            .font(.system(size: 22))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(.system(size: 12, weight: .bold))
                                .buxLabelSecondary()
                            Text(row.value)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(row.subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .buxLabelSecondary()
                        }
                        Spacer()
                    }
                    .padding(BuxLayout.section)
                    .studioThemedCardChrome(cornerRadius: 16)
                    .padding(.horizontal, BuxTokens.marginRegular)
                }
                }
                .studioProToolScreenScrollChrome()
            }
            .buxSoftScrollChrome()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
    }
}
