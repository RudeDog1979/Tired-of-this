//
//  ExpensesTopCarousel.swift
//  BuxMuse
//
//  Swipable hero cards: equal-height Total Spend + Monthly Summary.
//

import SwiftUI

struct ExpensesTopCarousel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let header: ExpensesHeaderDisplay
    let summary: ExpensesSummaryDisplay
    let formatAmount: (Decimal) -> String

    @State private var pageIndex: Int? = 0
    @State private var cardReveal = false
    @State private var activeDetailSheet: HeroSheetType?

    private enum HeroSheetType: String, Identifiable {
        case totalSpend
        case monthlySummary
        var id: String { rawValue }
    }

    private var pages: [CarouselPage] {
        var items: [CarouselPage] = []
        if header.totalSpent != 0 || !header.sparklinePoints.isEmpty {
            items.append(.totalSpend)
        }
        if !summary.categoryBreakdown.isEmpty || !summary.merchantBreakdown.isEmpty {
            items.append(.monthlySummary)
        }
        return items
    }

    private var activePageIndex: Int {
        min(pageIndex ?? 0, max(pages.count - 1, 0))
    }

    private var slotHeight: CGFloat {
        pages.isEmpty ? 0 : BuxLayout.expenseHeroSummaryHeight
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            Group {
                                switch page {
                                case .totalSpend:
                                    totalSpendCard
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            let impact = UIImpactFeedbackGenerator(style: .medium)
                                            impact.impactOccurred()
                                            activeDetailSheet = .totalSpend
                                        }
                                case .monthlySummary:
                                    ExpensesSummaryCard(display: summary)
                                        .environmentObject(themeManager)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            let impact = UIImpactFeedbackGenerator(style: .medium)
                                            impact.impactOccurred()
                                            activeDetailSheet = .monthlySummary
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: slotHeight, alignment: .top)
                            .containerRelativeFrame(.horizontal) { width, _ in
                                width - 40
                            }
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $pageIndex)
                .safeAreaPadding(.horizontal, 20)
                .safeAreaPadding(.vertical, 8)
            }
            .frame(minHeight: slotHeight + 16, alignment: .top)
            .padding(.bottom, BuxLayout.expenseHeroShadowBleed)

            if pages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(
                                index == activePageIndex
                                    ? themeManager.current.accentColor
                                    : themeManager.pillInactiveLabelColor(for: colorScheme).opacity(0.35)
                            )
                            .frame(width: index == activePageIndex ? 18 : 6, height: 6)
                            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: activePageIndex)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                cardReveal = true
            }
        }
        .sheet(item: $activeDetailSheet) { sheetType in
            Group {
                switch sheetType {
                case .totalSpend:
                    TotalSpendDetailSheet(header: header, formatAmount: formatAmount)
                        .environmentObject(themeManager)
                        .environmentObject(brain)
                        .environmentObject(appSettingsManager)
                        .environment(\.expensesEnhancedTint, true)
                        .presentationDetents([.fraction(0.88), .large])
                        .presentationDragIndicator(.visible)
                case .monthlySummary:
                    MonthlySummaryDetailSheet(summary: summary, formatAmount: formatAmount)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environment(\.expensesEnhancedTint, true)
                        .presentationDetents([.fraction(0.88), .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .buxThemedSheetContent()
        }
    }

    private var totalSpendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Spend")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Text(formatAmount(Decimal(header.totalSpent)))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 8)

                if !summary.categoryBreakdown.isEmpty {
                    MiniCategoryDonutChart(
                        breakdown: summary.categoryBreakdown,
                        accentColor: themeManager.current.accentColor
                    )
                    .frame(width: 72, height: 72)
                }
            }
            .heroCardReveal(isVisible: cardReveal, delay: 0)

            if !summary.categoryBreakdown.isEmpty || !summary.merchantBreakdown.isEmpty {
                HStack(spacing: 16) {
                    if !summary.categoryBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Top Categories")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            CategoryBreakdownChart(breakdown: summary.categoryBreakdown)
                                .frame(height: 72)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !summary.merchantBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Top Merchants")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            MerchantBreakdownChart(breakdown: summary.merchantBreakdown)
                                .frame(height: 72)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .heroCardReveal(isVisible: cardReveal, delay: 0.06)
            }

            if !header.sparklinePoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("7-day trend")
                        .font(.caption.bold())
                        .foregroundColor(.gray)

                    HStack(alignment: .center, spacing: 12) {
                        SparklineChart(
                            points: header.sparklinePoints,
                            color: themeManager.current.accentColor,
                            showAreaFill: true
                        )
                        .frame(height: 44)

                        monthChangeBadge
                    }
                }
                .heroCardReveal(isVisible: cardReveal, delay: 0.12)
            }

            if let insight = header.microInsight {
                InlineInsightView(text: insight)
                    .heroCardReveal(isVisible: cardReveal, delay: 0.18)
            }
        }
        .expenseHeroCardChrome(themeManager: themeManager, colorScheme: colorScheme)
        .frame(maxWidth: .infinity, minHeight: slotHeight, alignment: .topLeading)
    }

    private var monthChangeBadge: some View {
        let isUp = header.changeVsLastMonth > 0
        let isDown = header.changeVsLastMonth < 0
        let tint: Color = isUp ? .orange : (isDown ? Color(red: 46/255, green: 204/255, blue: 113/255) : .gray)

        return VStack(alignment: .trailing, spacing: 2) {
            Text("vs last mo")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : Color(red: 140/255, green: 145/255, blue: 160/255))
                .kerning(0.4)

            HStack(spacing: 3) {
                if isUp || isDown {
                    Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(formatAmount(Decimal(abs(header.changeVsLastMonth))))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundColor(tint)
        }
        .frame(minWidth: 72, alignment: .trailing)
    }

    private enum CarouselPage: Hashable {
        case totalSpend
        case monthlySummary
    }
}

// MARK: - Shared hero card chrome

struct ExpenseHeroCardChrome: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.expensesEnhancedTint) private var expensesEnhancedTint
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    init() {}

    func body(content: Content) -> some View {
        let cornerRadius = BuxLayout.expenseHeroCardCornerRadius
        let shadow = themeManager.heroCardShadow(for: colorScheme)
        let padded = content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)

        Group {
            if expensesEnhancedTint && settings.brandThemesEnabled {
                padded
                    .background {
                        BuxThemedCardPlateBackground(cornerRadius: cornerRadius)
                    }
                    .compositingGroup()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                DashboardThemeTint.themedCardStroke(
                                    themeManager: themeManager,
                                    colorScheme: colorScheme
                                ),
                                lineWidth: 1
                            )
                    )
            } else {
                padded
                    .background(
                        themeManager.cardFill(for: colorScheme),
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
                    )
            }
        }
        .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}

private struct HeroCardRevealModifier: ViewModifier {
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .animation(.spring(response: 0.5, dampingFraction: 0.84).delay(delay), value: isVisible)
    }
}

private extension View {
    func heroCardReveal(isVisible: Bool, delay: Double) -> some View {
        modifier(HeroCardRevealModifier(isVisible: isVisible, delay: delay))
    }
}

extension View {
    func expenseHeroCardChrome(themeManager: ThemeManager, colorScheme: ColorScheme) -> some View {
        _ = (themeManager, colorScheme)
        return modifier(ExpenseHeroCardChrome())
    }
}
