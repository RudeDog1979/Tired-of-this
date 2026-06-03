//
//  StudioSEModuleViews.swift
//  BuxMuse
//
//  Self-employed OS module views — display Brain snapshots only.
//

import SwiftUI

// MARK: - Income Tax Calculator

struct StudioIncomeTaxCalculatorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        let snapshot = studioBrain.incomeTaxDisplay

        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    heroCard(snapshot)

                    if !snapshot.ratesConfigured {
                        ratesHintCard
                    }

                    breakdownCard(snapshot)
                    TaxReferenceDisclaimerNote()
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
                .environment(\.studioEnhancedTint, true)
            }
        }
        .buxCatalogNavigationTitle("Income Tax Calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func heroCard(_ snapshot: IncomeTaxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: "ESTIMATED ANNUAL TAX")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            Text(snapshot.totalEstimatedTaxFormatted)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.accentColor)
            Text(
                BuxLocalizedString.format(
                    "Effective rate %lld%% on recorded income",
                    locale: appSettingsManager.interfaceLocale,
                    snapshot.effectiveRatePercent
                )
            )
                .font(.system(size: 12))
                .buxLabelSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BuxLayout.section)
        .seCard(colorScheme: colorScheme, themeManager: themeManager)
    }

    private var ratesHintCard: some View {
        NavigationLink {
            StudioTaxReferenceView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.orange)
                BuxCatalogDynamicText(key: "Set your effective income and self-employed tax rates in Tax Profile to enable calculations.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .buxLabelSecondary()
            }
            .padding(BuxLayout.section)
            .seCard(colorScheme: colorScheme, themeManager: themeManager)
        }
        .buttonStyle(BuxPressFeedbackStyle())
    }

    private func breakdownCard(_ snapshot: IncomeTaxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxCatalogDynamicText(key: "BREAKDOWN")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            seRow("Gross income", snapshot.totalIncomeFormatted)
            seRow("Deductible expenses", snapshot.deductibleExpensesFormatted, color: .green)
            seRow("Taxable income", snapshot.taxableIncomeFormatted)
            Divider()
            seRow("Income tax", snapshot.incomeTaxFormatted)
            seRow("Self-employed tax", snapshot.selfEmployedTaxFormatted)
            seRow("Indirect tax (net)", snapshot.indirectTaxNetFormatted)
        }
        .padding(BuxLayout.section)
        .seCard(colorScheme: colorScheme, themeManager: themeManager)
    }

    private func seRow(_ title: String, _ value: String, color: Color? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .buxLabelSecondary()
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color ?? (themeManager.labelPrimary(for: colorScheme)))
        }
    }
}

// MARK: - Quarterly Tax

struct StudioQuarterlyTaxView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioBrain: StudioBrain

    var body: some View {
        let snapshot = studioBrain.quarterlyDisplay

        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.quarterLabel.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                        Text(snapshot.totalDueFormatted)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text(snapshot.periodRangeLabel)
                            .font(.system(size: 12))
                            .buxLabelSecondary()
                        Text(snapshot.nextPaymentLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.current.accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BuxLayout.section)
                    .seCard(colorScheme: colorScheme, themeManager: themeManager)

                    VStack(alignment: .leading, spacing: 12) {
                        BuxCatalogDynamicText(key: "QUARTERLY SPLIT")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                        seMetric("Income tax", snapshot.incomeTaxFormatted)
                        seMetric("Self-employed tax", snapshot.selfEmployedTaxFormatted)
                        seMetric("Indirect tax", snapshot.indirectTaxFormatted)
                        Divider()
                        seMetric("Suggested set-aside", snapshot.setAsideFormatted, bold: true)
                    }
                    .padding(BuxLayout.section)
                    .seCard(colorScheme: colorScheme, themeManager: themeManager)

                    TaxReferenceDisclaimerNote()
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
                .environment(\.studioEnhancedTint, true)
            }
        }
        .buxCatalogNavigationTitle("Quarterly Tax")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func seMetric(_ title: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: bold ? 14 : 13, weight: bold ? .bold : .regular))
            Spacer()
            Text(value)
                .font(.system(size: bold ? 15 : 13, weight: bold ? .bold : .semibold, design: .rounded))
        }
    }
}

// MARK: - Compliance Assistant

struct StudioComplianceAssistantView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.studioHubEmbedded) private var studioHubEmbedded
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var studioBrain: StudioBrain

    var body: some View {
        let snapshot = studioBrain.complianceDisplay

        ZStack {
            if !studioHubEmbedded {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    if !snapshot.warnings.isEmpty {
                        BuxCatalogDynamicText(key: "WARNINGS")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                        ForEach(snapshot.warnings) { item in
                            complianceCard(item)
                        }
                    }

                    Text("FAQ")
                        .font(.system(size: 11, weight: .bold))
                        .buxLabelSecondary()
                    ForEach(snapshot.faq) { item in
                        complianceCard(item)
                    }

                    TaxReferenceDisclaimerNote()
                    Spacer().frame(height: 40)
                }
                .studioHubEmbeddedHorizontalPadding()
                .padding(.top, BuxLayout.tight)
                .environment(\.studioEnhancedTint, true)
            }
        }
        .buxCatalogNavigationTitle(studioHubEmbedded ? "" : "Compliance Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func complianceCard(_ item: ComplianceItemDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                severityIcon(item.severity)
                Text(item.question)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
            Text(item.answer)
                .font(.system(size: 12))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BuxLayout.section)
        .seCard(colorScheme: colorScheme, themeManager: themeManager)
    }

    private func severityIcon(_ severity: String) -> some View {
        let color: Color = switch severity {
        case "high": .red
        case "medium": .orange
        default: .blue
        }
        return Image(systemName: severity == "info" ? "info.circle.fill" : "exclamationmark.triangle.fill")
            .foregroundColor(color)
            .font(.system(size: 14))
    }
}

// MARK: - Home Dashboard Widget

struct StudioDashboardWidget: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var studioBrain: StudioBrain

    private var display: SelfEmployedDashboardDisplay {
        studioBrain.selfEmployedDashboardDisplay
    }

    var body: some View {
        if display.hasData {
            BuxCardButton(action: {
                navigationCoordinator.selectedTab = .studio
            }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label {
                            BuxCatalogDynamicText(key: "Studio")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.current.accentColor)
                        } icon: {
                            StudioTabIcon(isSelected: true)
                                .foregroundStyle(themeManager.current.accentColor)
                                .frame(width: 18, height: 18)
                        }
                        Spacer()
                        Text(
                            BuxLocalizedString.format(
                                "Runway %@",
                                locale: appSettingsManager.interfaceLocale,
                                display.runwayMonthsFormatted
                            )
                        )
                            .font(.system(size: 10, weight: .bold))
                            .buxLabelSecondary()
                    }

                    HStack(spacing: BuxLayout.section) {
                        widgetMetric("Income", display.incomeFormatted)
                        widgetMetric("Expenses", display.expensesFormatted)
                        widgetMetric("Net", display.netProfitFormatted)
                    }

                    HStack(spacing: BuxLayout.section) {
                        widgetMetric("Est. tax", display.estimatedTaxFormatted)
                        widgetMetric("Quarter due", display.quarterlyDueFormatted)
                        widgetMetric("Rate", "\(display.effectiveRatePercent)%")
                    }
                }
                .padding(BuxLayout.section)
            }
            .buttonStyle(BuxDashboardCardButtonStyle())
            .buxMaterialCardChrome(.outlined)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func widgetMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BuxCatalogText.text(title)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .buxLabelSecondary()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared card modifier

private extension View {
    func seCard(colorScheme: ColorScheme, themeManager: ThemeManager) -> some View {
        studioThemedCardChrome(cornerRadius: BuxMaterialChrome.cardCornerRadius)
    }
}
