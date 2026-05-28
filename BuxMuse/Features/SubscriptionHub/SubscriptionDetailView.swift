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
    
    @State private var animateIn = false
    
    var cardColor: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }
    
    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Row with Close
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : .white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            }
                        }
                        
                        Spacer()
                        
                        Text(detail.info.merchantName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        
                        Spacer()
                        
                        Image(systemName: "xmark.circle.fill").opacity(0)
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, 60)
                    
                    // Main overview card
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(cardColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                            )
                        
                        VStack(spacing: 16) {
                            AsyncMerchantLogoView(merchantName: detail.info.merchantName, size: 56)
                                .shadow(radius: 4)
                            
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
                            
                            HStack {
                                Label("Next Renewal: \(formatDate(detail.info.nextRenewalDate))", systemImage: "calendar")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(28)
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    
                    // Performance price history chart
                    if detail.priceHistoryGraph.count >= 2 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PRICE HISTORY")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                                .kerning(1.2)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(cardColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                                    )
                                
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
                                    .foregroundColor(.gray)
                                }
                                .padding(20)
                            }
                        }
                        .padding(.horizontal, BuxLayout.marginHorizontal)
                    }
                    
                    // Risks alert card if active
                    if !detail.info.risks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DETECTED PATTERN WARNINGS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                                .kerning(1.2)
                            
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
                                .padding(16)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, BuxLayout.marginHorizontal)
                    }
                    
                    // Budget impacts card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("BUDGET IMPACTS IF CANCELLED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                            .kerning(1.2)
                        
                        HStack(spacing: 16) {
                            BudgetImpactItem(label: "Monthly Savings", amount: appSettingsManager.format(abs(detail.budgetImpactMonthly.value)), color: .green)
                            BudgetImpactItem(label: "Yearly Savings", amount: appSettingsManager.format(abs(detail.budgetImpactYearly.value)), color: themeManager.current.accentColor)
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    
                    // Cancellation steps card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HOW TO CANCEL")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                            .kerning(1.2)
                        
                        Text(detail.cancellationSteps)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : Color(red: 80/255, green: 85/255, blue: 95/255))
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardColor)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    
                    // Usage insights & alternatives card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INTELLIGENCE INSIGHTS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.sectionHeaderColor(for: colorScheme))
                            .kerning(1.2)
                        
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
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    
                    // Red cancellation trigger button
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
                            .shadow(color: Color.red.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(BuxMicroShrinkStyle())
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.bottom, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM dd, yyyy"
        return fmt.string(from: date)
    }
}

struct BudgetImpactItem: View {
    @Environment(\.colorScheme) var colorScheme
    let label: String
    let amount: String
    let color: Color
    
    var cardColor: Color {
        colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            Text("+\(amount)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
        )
    }
}
