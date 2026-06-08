//
//  MoneyMapNodeDetailSheet.swift
//  BuxMuse
//
//  Territory preview + full detail — always shows live data, never empty labels.
//

import SwiftUI
import Charts

struct MoneyMapNodeDetailSheet: View {
    let node: MoneyMapNode
    let graph: MoneyMapGraph
    var onDeepLink: ((MoneyMapDeepLink) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var insightsViewModel: InsightsViewModel

    @State private var showFullDetail = false

    private var detail: MoneyMapTerritoryDetail { node.detail }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BuxTokens.block) {
                        headerBlock
                        explanationBlock
                        metricLinesBlock
                        previewChartBlock
                        breakdownPreviewBlock
                        deepLinkBlock
                        fullDetailCTA
                    }
                    .padding(BuxTokens.marginRegular)
                    .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                }
                .buxDetailScrollChrome()
            }
            .navigationTitle(node.localizedTitle(locale: appSettingsManager.interfaceLocale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxThemedPresentation()
            .buxDetailNavigationChrome()
            .fullScreenCover(isPresented: $showFullDetail) {
                MoneyMapNodeFullDetailView(
                    node: node,
                    graph: graph,
                    onDeepLink: onDeepLink
                )
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(insightsViewModel)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private var headerBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(node.value)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            Text(node.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
    }

    private var explanationBlock: some View {
        Text(detail.explanation)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var metricLinesBlock: some View {
        if !detail.metricLines.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(detail.metricLines.enumerated()), id: \.offset) { index, line in
                    HStack {
                        Text(line.0)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                        Spacer()
                        Text(line.1)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 10)
                    if index < detail.metricLines.count - 1 {
                        Divider().opacity(0.08)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(themeManager.materialScheme(for: colorScheme).surfaceContainer.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private var previewChartBlock: some View {
        if !detail.sparkline.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                BuxCatalogText.text("Trend")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.sectionHeaderColor(for: colorScheme))
                SparklineChart(points: detail.sparkline, color: node.accentColor, showAreaFill: true)
                    .frame(height: 88)
            }
        } else if node.kind == .categories, !graph.categoryBreakdown.isEmpty {
            HStack(spacing: 14) {
                MiniCategoryDonutChart(breakdown: graph.categoryBreakdown)
                    .frame(width: 96, height: 96)
                categorySnippet
            }
        } else if node.kind == .energy {
            energyRingPreview
        }
    }

    private var categorySnippet: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(graph.categoryBreakdown.prefix(3).enumerated()), id: \.offset) { index, item in
                HStack {
                    Circle()
                        .fill(BuxChartColors.color(forCategoryName: item.0, fallbackIndex: index))
                        .frame(width: 7, height: 7)
                    Text(item.0)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(appSettingsManager.format(Decimal(item.1)))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }
        }
    }

    private var energyRingPreview: some View {
        let pct = BurnoutEngine.shared.currentStatus.creativeEnergyPercent
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(node.accentColor.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: pct / 100)
                    .stroke(node.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(
                    BuxLocalizedString.format(
                        "%lld%%",
                        locale: appSettingsManager.interfaceLocale,
                        Int(pct)
                    )
                )
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .frame(width: 72, height: 72)
            BuxCatalogText.text("Creative fuel left after workload, sleep, and stress spend.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
    }

    @ViewBuilder
    private var breakdownPreviewBlock: some View {
        let rows = detail.breakdown.isEmpty ? fallbackBreakdown : detail.breakdown
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                BuxCatalogText.text("Breakdown")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.sectionHeaderColor(for: colorScheme))
                ForEach(Array(rows.prefix(4).enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item.0)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Text(appSettingsManager.format(Decimal(item.1)))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    if index < min(rows.count, 4) - 1 {
                        Divider().opacity(0.06)
                    }
                }
            }
        }
    }

    private var fallbackBreakdown: [(String, Double)] {
        switch node.kind {
        case .categories: return graph.categoryBreakdown
        case .workspace, .studio: return graph.workspaceBreakdown
        case .merchants: return graph.merchantBreakdown
        default: return []
        }
    }

    @ViewBuilder
    private var deepLinkBlock: some View {
        if let link = detail.deepLink, let label = detail.deepLinkLabel {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onDeepLink?(link)
                }
            } label: {
                HStack {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                }
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .padding(14)
                .background(themeManager.current.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var fullDetailCTA: some View {
        Button { showFullDetail = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 16, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    BuxCatalogText.text("Open full territory detail")
                        .font(.system(size: 14, weight: .black))
                    BuxCatalogText.text("Charts, lines, insights & actions")
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .foregroundColor(.white)
            .padding(BuxTokens.section)
            .background(
                LinearGradient(
                    colors: [node.accentColor, node.accentColor.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full detail (presented on top of preview sheet)

struct MoneyMapNodeFullDetailView: View {
    let node: MoneyMapNode
    let graph: MoneyMapGraph
    var onDeepLink: ((MoneyMapDeepLink) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var insightsViewModel: InsightsViewModel
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BuxTokens.block) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(node.value)
                                .font(.system(size: 36, weight: .black, design: .rounded))
                            Text(node.subtitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                        }

                        Text(node.detail.explanation)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

                        fullCharts
                        fullBreakdown
                        insightActions
                        deepLinkFooter
                    }
                    .padding(BuxTokens.marginRegular)
                    .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                }
                .buxDetailScrollChrome()
            }
            .navigationTitle(node.localizedTitle(locale: appSettingsManager.interfaceLocale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxThemedPresentation()
            .buxDetailNavigationChrome()
        }
    }

    @ViewBuilder
    private var fullCharts: some View {
        switch node.kind {
        case .categories:
            if !graph.categoryBreakdown.isEmpty {
                HStack(spacing: 16) {
                    MiniCategoryDonutChart(breakdown: graph.categoryBreakdown)
                        .frame(width: 120, height: 120)
                    categoryList
                }
            }
        case .flow, .hub:
            if !graph.trendPoints.isEmpty {
                SparklineChart(points: graph.trendPoints, color: node.accentColor, showAreaFill: true)
                    .frame(height: 140)
            }
        case .workspace, .studio:
            workspaceChart
        case .cash:
            HStack(spacing: 16) {
                cashTile(title: settings.primaryLocalCurrency, value: settings.cashLocalBalanceValue, color: .green)
                cashTile(title: settings.secondaryTradingCurrency, value: settings.cashSecondaryBalanceValue, color: .blue)
            }
        case .energy:
            energyPanel
        case .insight:
            insightPanel
        default:
            if !node.detail.sparkline.isEmpty {
                SparklineChart(points: node.detail.sparkline, color: node.accentColor, showAreaFill: true)
                    .frame(height: 120)
            }
        }
    }

    @ViewBuilder
    private var fullBreakdown: some View {
        let rows = node.detail.breakdown.isEmpty ? fallbackBreakdown : node.detail.breakdown
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                BuxCatalogText.text("All lines")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.sectionHeaderColor(for: colorScheme))
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item.0).lineLimit(1)
                        Spacer()
                        Text(appSettingsManager.format(Decimal(item.1)))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    if index < rows.count - 1 {
                        Divider().opacity(0.06)
                    }
                }
            }
            .padding(14)
            .background(themeManager.materialScheme(for: colorScheme).surfaceContainer.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var fallbackBreakdown: [(String, Double)] {
        switch node.kind {
        case .categories: return graph.categoryBreakdown
        case .merchants: return graph.merchantBreakdown
        case .workspace, .studio: return graph.workspaceBreakdown
        default: return []
        }
    }

    @ViewBuilder
    private var insightActions: some View {
        if node.kind == .insight, let top = graph.topInsight ?? insightsViewModel.rankedInsights.first {
            VStack(alignment: .leading, spacing: 10) {
                Text(top.localizedTitle(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 16, weight: .bold))
                Text(top.localizedFullExplanation(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                if !top.suggestedActions.isEmpty {
                    ForEach(top.suggestedActions, id: \.self) { action in
                        Label(
                            top.localizedSuggestedAction(action, locale: appSettingsManager.interfaceLocale),
                            systemImage: "checkmark.circle"
                        )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        insightsViewModel.selectInsight(top)
                    }
                } label: {
                    BuxCatalogText.text("Open insight detail")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var deepLinkFooter: some View {
        if let link = node.detail.deepLink, let label = node.detail.deepLinkLabel {
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onDeepLink?(link)
                }
            } label: {
                Text(label)
                    .font(.system(size: 14, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(node.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(graph.categoryBreakdown.prefix(8).enumerated()), id: \.offset) { index, item in
                HStack {
                    Circle()
                        .fill(BuxChartColors.color(forCategoryName: item.0, fallbackIndex: index))
                        .frame(width: 8, height: 8)
                    Text(item.0)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(appSettingsManager.format(Decimal(item.1)))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }
        }
    }

    @ViewBuilder
    private var workspaceChart: some View {
        if !graph.workspaceBreakdown.isEmpty {
            Chart {
                ForEach(Array(graph.workspaceBreakdown.prefix(8).enumerated()), id: \.offset) { index, item in
                    BarMark(x: .value("Amount", item.1), y: .value("Workspace", item.0))
                        .foregroundStyle(BuxChartColors.color(forCategoryName: item.0, fallbackIndex: index))
                }
            }
            .chartLegend(.hidden)
            .chartXAxis(.hidden)
            .frame(height: min(220, CGFloat(graph.workspaceBreakdown.count) * 32 + 24))
        }
    }

    private var energyPanel: some View {
        let pct = BurnoutEngine.shared.currentStatus.creativeEnergyPercent
        return HStack(spacing: 20) {
            ZStack {
                Circle().stroke(node.accentColor.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: pct / 100)
                    .stroke(node.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(
                    BuxLocalizedString.format(
                        "%lld%%",
                        locale: appSettingsManager.interfaceLocale,
                        Int(pct)
                    )
                )
                    .font(.system(size: 18, weight: .black, design: .rounded))
            }
            .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    BuxLocalizedString.format(
                        "Work %@h",
                        locale: appSettingsManager.interfaceLocale,
                        String(format: "%.1f", BurnoutEngine.shared.currentStatus.workHours)
                    )
                )
                Text(
                    BuxLocalizedString.format(
                        "Sleep: %@ hrs",
                        locale: appSettingsManager.interfaceLocale,
                        String(format: "%.1f", BurnoutEngine.shared.currentStatus.sleepHours)
                    )
                )
                Text(
                    BuxLocalizedString.format(
                        "Stress expenses: %lld",
                        locale: appSettingsManager.interfaceLocale,
                        BurnoutEngine.shared.currentStatus.stressExpenseCount
                    )
                )
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
        }
    }

    private var insightPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let insight = graph.topInsight {
                Text(insight.localizedTitle(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 15, weight: .bold))
                Text(insight.localizedDescription(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            } else if let title = graph.topInsightTitle {
                Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 15, weight: .bold))
                if let detail = graph.topInsightDetail {
                    Text(BuxCatalogLabel.string(detail, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
            }
        }
    }

    private func cashTile(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            Text(String(format: "%.0f", value))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
