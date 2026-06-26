//
//  StudioHubSections.swift
//  BuxMuse
//
//  Freelance Hub dashboard sections — display structs only.
//

import SwiftUI

// MARK: - Hero

struct StudioHeroCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    let display: StudioHeroDisplay

    var body: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            HStack(spacing: BuxTokens.section) {
                if let logoData = store.profile.logoData, let uiImg = UIImage(data: logoData) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(themeManager.accentWash(for: colorScheme))
                            .frame(width: 54, height: 54)
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(display.businessTitle)
                        .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                        .font(.system(size: 18, weight: .bold))
                    Text(display.businessSubtitle)
                        .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    if let days = display.timeToMoneyDays {
                        Text(
                            BuxLocalizedString.format(
                                "Avg. time to payment: %lld days",
                                locale: appSettingsManager.interfaceLocale,
                                days
                            )
                        )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct StudioMetricsGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let display: StudioHeroDisplay

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: BuxTokens.tight), GridItem(.flexible(), spacing: BuxTokens.tight)],
            spacing: BuxTokens.tight
        ) {
            metricCard(
                title: "Estimated Tax",
                value: display.estimatedTaxFormatted,
                subtitle: BuxLocalizedString.format(
                    "%lld%% effective",
                    locale: appSettingsManager.interfaceLocale,
                    display.effectiveTaxRatePercent
                ),
                color: themeManager.current.accentColor
            )
            metricCard(
                title: "Cash Runway",
                value: display.runwayMonthsFormatted,
                subtitle: BuxLocalizedString.format(
                    "Burn %@/mo",
                    locale: appSettingsManager.interfaceLocale,
                    display.monthlyBurnFormatted
                ),
                color: .orange
            )
            metricCard(
                title: "Total Paid In",
                value: display.totalPaidFormatted,
                subtitle: BuxLocalizedString.format(
                    "%lld invoices",
                    locale: appSettingsManager.interfaceLocale,
                    display.paidInvoiceCount
                ),
                color: .green
            )
            metricCard(
                title: "Outstanding",
                value: display.totalOutstandingFormatted,
                subtitle: BuxLocalizedString.format(
                    "%lld awaiting",
                    locale: appSettingsManager.interfaceLocale,
                    display.outstandingInvoiceCount
                ),
                color: .red
            )
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                BuxCatalogText.text(title)
                    .buxSectionLabelStyle(color: themeManager.labelSecondary(for: colorScheme))
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Empty state

struct StudioHubEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.block) {
            VStack(spacing: 12) {
                Image(systemName: "briefcase")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                BuxCatalogText.text("Your Studio workspace is empty")
                    .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                BuxCatalogText.text("Add a client, invoice, or receipt to start tracking tax, cashflow, and deductions.")
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Sections

struct StudioInvoicesSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: StudioInvoiceSummaryDisplay
    var onTap: () -> Void

    var body: some View {
        StudioSectionShell(title: "Invoices") {
            BuxCardButton(action: onTap) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        statPill("Draft", display.draftCount)
                        statPill("Sent", display.sentCount)
                        statPill("Paid", display.paidCount, .green)
                        statPill("Overdue", display.overdueCount, .red)
                    }

                    StudioInvoiceStatusBar(
                        draft: display.draftCount,
                        sent: display.sentCount,
                        paid: display.paidCount,
                        overdue: display.overdueCount
                    )
                    .environmentObject(themeManager)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            BuxCatalogText.text("Outstanding")
                                .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                            Text(display.totalOutstandingFormatted)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            BuxCatalogText.text("Paid total")
                                .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                            Text(display.totalPaidFormatted)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    if let name = display.nextDueClientName, let date = display.nextDueDate {
                        Text(
                            BuxLocalizedString.format(
                                "Next due: %@ · %@",
                                locale: appSettingsManager.interfaceLocale,
                                name,
                                BuxDisplayDate.monthDay(from: date, locale: appSettingsManager.interfaceLocale)
                            )
                        )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
                .contentShape(Rectangle())
            }
        }
    }

    private func statPill(_ label: String, _ count: Int, _ color: Color = .gray) -> some View {
        VStack(spacing: 2) {
            Text(count, format: .number)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            BuxCatalogText.text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StudioClientsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let clients: [StudioClientDisplay]
    var onTap: () -> Void

    var body: some View {
        StudioSectionShell(title: "Top Clients") {
            if clients.isEmpty {
                BuxCatalogText.text("No clients yet. Add your first client to track health and lifetime value.")
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
            } else {
                VStack(spacing: 10) {
                    ForEach(clients.prefix(3)) { client in
                        BuxCardButton(action: onTap) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(client.name)
                                            .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                                        if client.isRedFlag {
                                            Image(systemName: "flag.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.red)
                                        }
                                    }
                                    Text(
                                        BuxLocalizedString.format(
                                            "LTV %@ · Health %lld%%",
                                            locale: appSettingsManager.interfaceLocale,
                                            client.lifetimeValueFormatted,
                                            client.healthScore
                                        )
                                    )
                                        .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                                }
                                Spacer()
                                Text(
                                    BuxLocalizedString.format(
                                        "%lld/100",
                                        locale: appSettingsManager.interfaceLocale,
                                        Int64(client.emotionalProfitabilityScore)
                                    )
                                )
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
    }
}

struct StudioTaxSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: StudioTaxDisplay
    var onTap: () -> Void

    var body: some View {
        StudioSectionShell(title: "Tax studio") {
            BuxCardButton(action: onTap) {
                VStack(alignment: .leading, spacing: BuxTokens.tight) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        BuxCatalogDynamicText(key: "Estimated tax")
                            .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                        Spacer(minLength: 8)
                        Text(display.estimatedTaxFormatted)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    row("Gross", display.grossIncomeFormatted)
                    row("After deductions", display.netIncomeFormatted)
                    if !display.primaryRulesPreview.isEmpty {
                        Text(display.incomeTypeLabel)
                            .buxSectionLabelStyle(color: themeManager.labelSecondary(for: colorScheme))
                            .padding(.top, 4)
                        Text(display.primaryRulesPreview)
                            .buxCaptionStyle(color: themeManager.labelPrimary(for: colorScheme))
                            .opacity(0.85)
                            .lineLimit(3)
                    }
                    Text(display.taxDeadlineLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(display.needsTaxProfileSetup ? .orange : themeManager.labelSecondary(for: colorScheme))
                    TaxReferenceDisclaimerNote()
                        .padding(.top, 4)
                }
                .contentShape(Rectangle())
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            BuxCatalogText.text(label)
                .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct StudioCashflowSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: StudioCashflowDisplay
    var onTap: () -> Void

    var body: some View {
        StudioSectionShell(title: "Cashflow") {
            BuxCardButton(action: onTap) {
                VStack(alignment: .leading, spacing: BuxTokens.tight) {
                    row("Runway", display.runwayMonthsFormatted)
                    row("Required income", display.survivalIncomeFormatted)
                    row("30-day inflow", display.projectedInflowFormatted)
                    if display.survivalModeActive {
                        Label {
                            Text(
                                BuxCatalogLabel.string(
                                    display.survivalMessage,
                                    locale: appSettingsManager.interfaceLocale
                                )
                            )
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                .contentShape(Rectangle())
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            BuxCatalogText.text(label)
                .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct StudioProjectsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: StudioProjectsDisplay
    var onTap: () -> Void

    var body: some View {
        StudioSectionShell(title: "Projects") {
            BuxCardButton(action: onTap) {
                VStack(alignment: .leading, spacing: BuxTokens.tight) {
                    Text(
                        BuxLocalizedString.format(
                            "%lld active · %lld overrun risk",
                            locale: appSettingsManager.interfaceLocale,
                            display.activeCount,
                            display.overrunRiskCount
                        )
                    )
                        .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                    if let name = display.topProjectName, let profit = display.topProjectProfitFormatted {
                        Text(
                            BuxLocalizedString.format(
                                "Top: %@ (%@ projected profit)",
                                locale: appSettingsManager.interfaceLocale,
                                name,
                                profit
                            )
                        )
                            .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    } else {
                        BuxCatalogText.text("No projects yet.")
                            .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    }
                }
                .contentShape(Rectangle())
            }
        }
    }
}

struct StudioReceiptsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: StudioReceiptsDisplay
    var onTap: () -> Void

    var body: some View {
        StudioSectionShell(title: "Receipts") {
            BuxCardButton(action: onTap) {
                VStack(alignment: .leading, spacing: BuxTokens.tight) {
                    Text(
                        BuxLocalizedString.format(
                            "%lld total · %lld this month",
                            locale: appSettingsManager.interfaceLocale,
                            display.totalCount,
                            display.thisMonthCount
                        )
                    )
                        .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                    Text(
                        BuxLocalizedString.format(
                            "Deductible: %@",
                            locale: appSettingsManager.interfaceLocale,
                            display.deductibleTotalFormatted
                        )
                    )
                        .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                }
                .contentShape(Rectangle())
            }
        }
    }
}

struct StudioDeductionsSection: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    let items: [StudioDeductionDisplay]
    var onTap: () -> Void

    var body: some View {
        StudioSectionShell(title: "Deduction Opportunities") {
            if items.isEmpty {
                BuxCatalogText.text("No deduction opportunities yet. Log receipts to unlock suggestions.")
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
            } else {
                VStack(spacing: BuxTokens.tight) {
                    ForEach(items.prefix(3)) { item in
                        BuxCardButton(action: onTap) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .buxHeadlineStyle(color: themeManager.contrastAccentColor(for: colorScheme))
                                Text(item.description)
                                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
        }
    }
}

struct StudioAlertsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let alerts: [StudioAlertDisplay]

    var body: some View {
        StudioSectionShell(title: "Alerts") {
            if alerts.isEmpty {
                BuxCatalogText.text("No alerts. You're all caught up.")
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
            } else {
                VStack(spacing: BuxTokens.tight) {
                    ForEach(alerts.prefix(5)) { alert in
                        HStack(alignment: .top, spacing: BuxTokens.tight) {
                            Image(systemName: alert.severity == "high" ? "exclamationmark.octagon.fill" : "info.circle.fill")
                                .foregroundColor(alert.severity == "high" ? .red : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.title)
                                    .buxHeadlineStyle(color: themeManager.labelPrimary(for: colorScheme))
                                    .font(.system(size: 12, weight: .bold))
                                Text(alert.message)
                                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Hub visuals

struct StudioHubPulseCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let cashflow: StudioCashflowDisplay

    private var hasSparkline: Bool {
        !cashflow.inflowSparklinePoints.isEmpty && cashflow.inflowSparklinePoints.contains(where: { $0 > 0 })
    }

    var body: some View {
        if hasSparkline {
            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        BuxCatalogText.text("PAID INFLOW · 6 MO")
                            .buxSectionLabelStyle(color: themeManager.labelSecondary(for: colorScheme))
                            .font(.system(size: 10, weight: .bold))
                        Spacer()
                        Text(cashflow.projectedInflowFormatted)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }

                    SparklineChart(
                        points: cashflow.inflowSparklinePoints,
                        color: BuxChartColors.inflowTrend(for: colorScheme),
                        showAreaFill: true
                    )
                    .frame(height: 56)
                }
            }
        }
    }
}

struct StudioInvoiceStatusBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let draft: Int
    let sent: Int
    let paid: Int
    let overdue: Int

    private var total: CGFloat {
        CGFloat(max(draft + sent + paid + overdue, 1))
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                segment(count: draft, color: .gray, width: geo.size.width * CGFloat(draft) / total)
                segment(count: sent, color: themeManager.contrastAccentColor(for: colorScheme), width: geo.size.width * CGFloat(sent) / total)
                segment(count: paid, color: .green, width: geo.size.width * CGFloat(paid) / total)
                segment(count: overdue, color: .red, width: geo.size.width * CGFloat(overdue) / total)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func segment(count: Int, color: Color, width: CGFloat) -> some View {
        if count > 0 {
            Capsule()
                .fill(color.opacity(colorScheme == .dark ? 0.85 : 0.75))
                .frame(width: max(width, 8))
        }
    }
}

// MARK: - Tax disclaimer

struct TaxReferenceDisclaimerNote: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: BuxTokens.tight) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            BuxCatalogDynamicText(key: TaxReferenceCopy.disclaimer)
                .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .studioThemedCardChrome(cornerRadius: BuxTokens.Radius.field)
    }
}

// MARK: - Shell

private struct StudioSectionShell<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: title)
            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
