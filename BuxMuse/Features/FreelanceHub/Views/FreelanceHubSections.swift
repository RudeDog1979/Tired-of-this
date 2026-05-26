//
//  FreelanceHubSections.swift
//  BuxMuse
//
//  Freelance Hub dashboard sections — display structs only.
//

import SwiftUI

// MARK: - Hero

struct FreelanceHeroCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: FreelanceStore

    let display: FreelanceHeroDisplay

    var body: some View {
        HStack(spacing: BuxLayout.section) {
            if let logoData = store.profile.logoData, let uiImg = UIImage(data: logoData) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(themeManager.current.accentColor.opacity(0.15))
                        .frame(width: 54, height: 54)
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(themeManager.current.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(display.businessTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                Text(display.businessSubtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
                if let days = display.timeToMoneyDays {
                    Text("Avg. time to payment: \(days) days")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.current.accentColor)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(BuxLayout.section)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 24)
    }
}

struct FreelanceMetricsGrid: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let display: FreelanceHeroDisplay

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            metricCard(title: "ESTIMATED TAX", value: display.estimatedTaxFormatted, subtitle: "\(display.effectiveTaxRatePercent)% effective", color: themeManager.current.accentColor)
            metricCard(title: "CASH RUNWAY", value: display.runwayMonthsFormatted, subtitle: "Burn \(display.monthlyBurnFormatted)/mo", color: .orange)
            metricCard(title: "TOTAL PAID IN", value: display.totalPaidFormatted, subtitle: "\(display.paidInvoiceCount) invoices", color: .green)
            metricCard(title: "OUTSTANDING", value: display.totalOutstandingFormatted, subtitle: "\(display.outstandingInvoiceCount) awaiting", color: .red)
        }
    }

    private func metricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 20)
    }
}

// MARK: - Empty state

struct FreelanceHubEmptyState: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase")
                .font(.system(size: 32))
                .foregroundColor(themeManager.current.accentColor)
            Text("Your freelance workspace is empty")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            Text("Add a client, invoice, or receipt to start tracking tax, cashflow, and deductions.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 20)
    }
}

// MARK: - Sections

struct FreelanceInvoicesSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let display: FreelanceInvoiceSummaryDisplay
    var onTap: () -> Void

    var body: some View {
        FreelanceSectionShell(title: "INVOICES") {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        statPill("Draft", display.draftCount)
                        statPill("Sent", display.sentCount)
                        statPill("Paid", display.paidCount, .green)
                        statPill("Overdue", display.overdueCount, .red)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Outstanding")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gray)
                            Text(display.totalOutstandingFormatted)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Paid total")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.gray)
                            Text(display.totalPaidFormatted)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                    }
                    if let name = display.nextDueClientName, let date = display.nextDueDate {
                        Text("Next due: \(name) · \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.current.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func statPill(_ label: String, _ count: Int, _ color: Color = .gray) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FreelanceClientsSection: View {
    @Environment(\.colorScheme) private var colorScheme
    let clients: [FreelanceClientDisplay]
    var onTap: () -> Void

    var body: some View {
        FreelanceSectionShell(title: "TOP CLIENTS") {
            if clients.isEmpty {
                Text("No clients yet. Add your first client to track health and lifetime value.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 10) {
                    ForEach(clients.prefix(3)) { client in
                        Button(action: onTap) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(client.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                        if client.isRedFlag {
                                            Image(systemName: "flag.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.red)
                                        }
                                    }
                                    Text("LTV \(client.lifetimeValueFormatted) · Health \(client.healthScore)%")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text("\(client.emotionalProfitabilityScore)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct FreelanceTaxSection: View {
    let display: FreelanceTaxDisplay
    var onTap: () -> Void

    var body: some View {
        FreelanceSectionShell(title: "TAX SUMMARY") {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    row("Gross", display.grossIncomeFormatted)
                    row("Estimated tax", display.estimatedTaxFormatted)
                    row("Net income", display.netIncomeFormatted)
                    Text(display.taxDeadlineLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(display.needsTaxProfileSetup ? .orange : .gray)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
    }
}

struct FreelanceCashflowSection: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let display: FreelanceCashflowDisplay
    var onTap: () -> Void

    var body: some View {
        FreelanceSectionShell(title: "CASHFLOW") {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    row("Runway", display.runwayMonthsFormatted)
                    row("Required income", display.survivalIncomeFormatted)
                    row("30-day inflow", display.projectedInflowFormatted)
                    if display.survivalModeActive {
                        Label(display.survivalMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
        }
    }
}

struct FreelanceProjectsSection: View {
    let display: FreelanceProjectsDisplay
    var onTap: () -> Void

    var body: some View {
        FreelanceSectionShell(title: "PROJECTS") {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(display.activeCount) active · \(display.overrunRiskCount) overrun risk")
                        .font(.system(size: 13, weight: .semibold))
                    if let name = display.topProjectName, let profit = display.topProjectProfitFormatted {
                        Text("Top: \(name) (\(profit) projected profit)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    } else {
                        Text("No projects yet.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct FreelanceReceiptsSection: View {
    let display: FreelanceReceiptsDisplay
    var onTap: () -> Void

    var body: some View {
        FreelanceSectionShell(title: "RECEIPTS") {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(display.totalCount) total · \(display.thisMonthCount) this month")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Deductible: \(display.deductibleTotalFormatted)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct FreelanceDeductionsSection: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let items: [FreelanceDeductionDisplay]
    var onTap: () -> Void

    var body: some View {
        FreelanceSectionShell(title: "DEDUCTION OPPORTUNITIES") {
            if items.isEmpty {
                Text("No deduction opportunities yet. Log receipts to unlock suggestions.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 8) {
                    ForEach(items.prefix(3)) { item in
                        Button(action: onTap) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(themeManager.current.accentColor)
                                Text(item.description)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct FreelanceAlertsSection: View {
    let alerts: [FreelanceAlertDisplay]

    var body: some View {
        FreelanceSectionShell(title: "ALERTS") {
            if alerts.isEmpty {
                Text("No alerts. You're all caught up.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 8) {
                    ForEach(alerts.prefix(5)) { alert in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: alert.severity == "high" ? "exclamationmark.octagon.fill" : "info.circle.fill")
                                .foregroundColor(alert.severity == "high" ? .red : .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.title)
                                    .font(.system(size: 12, weight: .bold))
                                Text(alert.message)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
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

// MARK: - Shell

private struct FreelanceSectionShell<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .buxCardOutline(themeManager: themeManager, colorScheme: colorScheme, cornerRadius: 16)
        }
    }
}
