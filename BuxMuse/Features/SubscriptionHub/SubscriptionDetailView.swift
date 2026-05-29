//
//  SubscriptionDetailView.swift
//  BuxMuse
//  Features/SubscriptionHub/
//
//  Premium detailed subscription info view matching standard BuxMuse modal sheet styling.
//

import SwiftUI

struct SubscriptionDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager

    let detail: SubscriptionDetail
    let onCancelTriggered: (String) -> Void
    @Binding var isPresented: Bool

    private var secondary: Color { themeManager.labelSecondary(for: colorScheme) }

    var body: some View {
        BuxDetailOverlayScaffold(title: detail.info.merchantName) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                isPresented = false
            }
        } content: {
            overviewCard
            priceHistorySection
            risksSection
            budgetImpactsSection
            cancellationSection
            insightsSection
            cancelButton
        }
        .buxThemedPresentation()
    }

    private var overviewCard: some View {
        VStack(spacing: 16) {
            AsyncMerchantLogoView(merchantName: detail.info.merchantName, size: 56)

            VStack(spacing: 4) {
                Text(appSettingsManager.format(detail.info.cost.value))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                Text(detail.info.billingCycle.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.current.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.current.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Label("Next Renewal: \(formatDate(detail.info.nextRenewalDate))", systemImage: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(secondary)
        }
        .frame(maxWidth: .infinity)
        .buxDetailSectionCard()
    }

    @ViewBuilder
    private var priceHistorySection: some View {
        if detail.priceHistoryGraph.count >= 2 {
            VStack(alignment: .leading, spacing: 12) {
                BuxDetailSectionHeader(title: "Price history")

                VStack(spacing: 16) {
                    GeometryReader { geometry in
                        Path { path in
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let count = detail.priceHistoryGraph.count

                            let doubleValues = detail.priceHistoryGraph.map { NSDecimalNumber(decimal: $0).doubleValue }
                            let maxVal = doubleValues.max() ?? 100.0
                            let minVal = doubleValues.min() ?? 0.0
                            let valRange = maxVal - minVal > 0 ? maxVal - minVal : 100.0

                            for idx in 0..<count {
                                let x = width * CGFloat(idx) / CGFloat(count - 1)
                                let y = height - (height * CGFloat((doubleValues[idx] - minVal) / valRange) * 0.8 + height * 0.1)
                                if idx == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(themeManager.current.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                    .frame(height: 100)
                    .padding(.top, 8)

                    HStack {
                        Text("First recorded")
                        Spacer()
                        if detail.costChangePercentage != 0 {
                            Text(detail.costChangePercentage > 0 ? "↑ \(String(format: "%.1f", detail.costChangePercentage))% Increase" : "↓ \(String(format: "%.1f", abs(detail.costChangePercentage)))% Decrease")
                                .foregroundColor(detail.costChangePercentage > 0 ? .red : .green)
                                .font(.system(size: 11, weight: .bold))
                        }
                        Spacer()
                        Text("Current")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(secondary)
                }
                .buxDetailSectionCard(cornerRadius: BuxDetailStyle.rowCardRadius)
            }
        }
    }

    @ViewBuilder
    private var risksSection: some View {
        if !detail.info.risks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected pattern warnings")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
                    .kerning(0.6)

                ForEach(detail.info.risks) { risk in
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(risk.description)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(BuxDetailStyle.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: BuxDetailStyle.rowCardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BuxDetailStyle.rowCardRadius, style: .continuous)
                            .stroke(Color.red.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var budgetImpactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxDetailSectionHeader(title: "Budget impacts if cancelled")

            HStack(spacing: 16) {
                BudgetImpactItem(label: "Monthly Savings", amount: appSettingsManager.format(abs(detail.budgetImpactMonthly.value)), color: .green)
                BudgetImpactItem(label: "Yearly Savings", amount: appSettingsManager.format(abs(detail.budgetImpactYearly.value)), color: themeManager.current.accentColor)
            }
        }
    }

    private var cancellationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxDetailSectionHeader(title: "How to cancel")

            Text(detail.cancellationSteps)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .buxDetailSectionCard(cornerRadius: BuxDetailStyle.rowCardRadius)
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxDetailSectionHeader(title: "Intelligence insights")

            VStack(alignment: .leading, spacing: 14) {
                Text(detail.usageInsights)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.current.accentColor)

                if !detail.alternatives.isEmpty {
                    Divider().opacity(0.08)
                    Text("Suggested Alternatives:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    ForEach(detail.alternatives, id: \.self) { alt in
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.current.accentColor)
                            Text(alt)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(secondary)
                        }
                    }
                }
            }
            .buxDetailSectionCard(cornerRadius: BuxDetailStyle.rowCardRadius)
        }
    }

    private var cancelButton: some View {
        Button(action: {
            onCancelTriggered(detail.info.merchantName)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                isPresented = false
            }
        }) {
            Text("Log Subscription as Cancelled")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .clipShape(Capsule())
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM dd, yyyy"
        return fmt.string(from: date)
    }
}

struct BudgetImpactItem: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let label: String
    let amount: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))

            Text("+\(amount)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .buxDetailRowCard(minHeight: BuxDetailStyle.pairedCardMinHeight)
    }
}
