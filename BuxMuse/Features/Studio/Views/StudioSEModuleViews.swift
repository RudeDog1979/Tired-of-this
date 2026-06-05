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
        .buxCatalogNavigationTitle("Income tax calculator")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func heroCard(_ snapshot: IncomeTaxDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: "Estimated annual tax")
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
            BuxCatalogDynamicText(key: "Breakdown")
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
            Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
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
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        let snapshot = studioBrain.quarterlyDisplay

        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.quarterLabel)
                            .font(.system(size: 11, weight: .semibold))
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
                        BuxCatalogDynamicText(key: "Quarterly split")
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
        .buxCatalogNavigationTitle("Quarterly tax")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func seMetric(_ title: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
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
                        BuxCatalogDynamicText(key: "Warnings")
                            .font(.system(size: 11, weight: .bold))
                            .buxLabelSecondary()
                        ForEach(snapshot.warnings) { item in
                            complianceCard(item)
                        }
                    }

                    BuxCatalogDynamicText(key: "FAQ")
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
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text("S")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient(
                                    colors: [themeManager.current.accentColor, themeManager.current.accentColor.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                            Text(BuxLocalizedString.string("tudio", locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [themeManager.current.accentColor, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                        .shadow(color: themeManager.current.accentColor.opacity(0.25), radius: 3, x: 0, y: 1)
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            widgetMetric("Income", display.incomeFormatted, systemIcon: "arrow.down.right.circle.fill", iconColor: .green)
                            widgetMetric("Expenses", display.expensesFormatted, systemIcon: "arrow.up.left.circle.fill", iconColor: .orange)
                            widgetMetric("Net", display.netProfitFormatted, systemIcon: "chart.line.uptrend.xyaxis.circle.fill", iconColor: .blue)
                        }

                        Divider()
                            .opacity(0.5)

                        HStack(spacing: 12) {
                            widgetMetric("Est. tax", display.estimatedTaxFormatted, systemIcon: "building.columns.circle.fill", iconColor: .purple)
                            widgetMetric("Quarter due", display.quarterlyDueFormatted, systemIcon: "calendar.circle.fill", iconColor: .teal)
                            widgetMetric("Rate", "\(display.effectiveRatePercent)%", systemIcon: "percent", iconColor: .indigo)
                        }
                    }
                }
                .padding(BuxLayout.section)
            }
            .buttonStyle(BuxDashboardCardButtonStyle())
            .buxMaterialCardChrome(.outlined)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func widgetMetric(_ title: String, _ value: String, systemIcon: String, iconColor: Color) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: systemIcon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)
                .background(iconColor.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 1) {
                BuxCatalogText.text(title)
                    .font(.system(size: 9, weight: .bold))
                    .buxLabelSecondary()
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
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
