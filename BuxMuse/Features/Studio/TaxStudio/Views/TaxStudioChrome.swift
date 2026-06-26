//
//  TaxStudioChrome.swift
//  BuxMuse
//
//  Tax Studio Phase A — hero, ribbons, insight chips, metric cards.
//

import Charts
import SwiftUI

// MARK: - Ribbon

struct TaxStudioRibbon: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let titleKey: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(TaxStudioL10n.line(titleKey, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.current.accentColor,
                            themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.55 : 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.28), lineWidth: 0.5)
                }
        }
        .shadow(
            color: themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14),
            radius: 10,
            y: 4
        )
    }
}

// MARK: - Hero

struct TaxStudioHeroCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let hero: TaxStudioHeroDisplay

    private var healthColor: Color {
        TaxStudioMetricPalette.healthColor(for: hero.healthBand)
    }

    var body: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        BuxCatalogDynamicText(key: "Estimated tax")
                            .font(.system(size: 10, weight: .bold))
                            .buxLabelSecondary()
                        Text(hero.estimatedTax)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(
                            BuxLocalizedString.format(
                                "%@ effective on gross",
                                locale: appSettingsManager.interfaceLocale,
                                hero.effectiveRate
                            )
                        )
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TaxStudioMiniHealthGauge(
                        score: hero.healthScore,
                        band: hero.healthBand,
                        riskLevel: hero.healthRiskLevel
                    )
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TaxStudioStatPill(
                            value: hero.quarterlyDue,
                            label: hero.quarterLabel,
                            tint: .orange
                        )
                        TaxStudioStatPill(
                            value: hero.runway,
                            label: TaxStudioL10n.line("Runway", locale: appSettingsManager.interfaceLocale),
                            tint: .blue
                        )
                        TaxStudioStatPill(
                            value: hero.vatSummary,
                            label: TaxStudioL10n.line("VAT/GST", locale: appSettingsManager.interfaceLocale),
                            tint: .indigo
                        )
                        TaxStudioStatPill(
                            value: hero.countryLabel,
                            label: TaxStudioL10n.line("Preset", locale: appSettingsManager.interfaceLocale),
                            tint: themeManager.current.accentColor
                        )
                    }
                }
            }
        }
    }
}

struct TaxStudioStatPill: View {
    @Environment(\.colorScheme) private var colorScheme

    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .opacity(0.85)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

enum TaxStudioScoreGaugeSize {
    case mini
    case hero

    var ringDimension: CGFloat {
        switch self {
        case .mini: return 64
        case .hero: return 148
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .mini: return 5
        case .hero: return 10
        }
    }

    var scoreFontSize: CGFloat {
        switch self {
        case .mini: return 20
        case .hero: return 44
        }
    }
}

struct TaxStudioScoreGauge: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let score: Int
    let band: TaxHealthBand
    var riskLevel: String? = nil
    var size: TaxStudioScoreGaugeSize = .mini

    private var scoreColor: Color { TaxStudioMetricPalette.healthColor(for: band) }

    var body: some View {
        VStack(spacing: size == .hero ? 10 : 6) {
            ZStack {
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(
                        Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15),
                        lineWidth: size.lineWidth
                    )
                    .rotationEffect(.degrees(90))

                Circle()
                    .trim(from: 0.125, to: 0.125 + 0.75 * CGFloat(min(max(score, 0), 100)) / 100)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))

                Text(score, format: .number)
                    .font(.system(size: size.scoreFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
            }
            .frame(width: size.ringDimension, height: size.ringDimension)

            if let riskLevel {
                Text(
                    size == .hero
                        ? BuxLocalizedString.format(
                            "Tax Health · %@ risk",
                            locale: appSettingsManager.interfaceLocale,
                            riskLevel
                        )
                        : BuxLocalizedString.format(
                            "%@ risk",
                            locale: appSettingsManager.interfaceLocale,
                            riskLevel
                        )
                )
                .font(.system(size: size == .hero ? 12 : 9, weight: .bold))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: size == .hero ? 220 : 72)
            }
        }
    }
}

struct TaxStudioMiniHealthGauge: View {
    let score: Int
    let band: TaxHealthBand
    let riskLevel: String

    var body: some View {
        TaxStudioScoreGauge(score: score, band: band, riskLevel: riskLevel, size: .mini)
    }
}

// MARK: - Insight chip

struct TaxStudioInsightChip: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let icon: String
    let message: String
    let tone: TaxStudioInsightTone

    private var tint: Color {
        switch tone {
        case .positive: return .green
        case .warning: return .orange
        case .info: return themeManager.contrastAccentColor(for: colorScheme)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)
                .padding(.top, 1)
            Text(message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(colorScheme == .dark ? 0.18 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(colorScheme == .dark ? 0.28 : 0.18), lineWidth: 0.5)
        }
    }
}

// MARK: - Metric card v2

enum TaxStudioMetricPalette {
    static func healthColor(for band: TaxHealthBand) -> Color {
        switch band {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    static func color(
        for metricID: String,
        accent: Color,
        healthBand: TaxHealthBand?
    ) -> Color {
        switch metricID {
        case "tax", "ftax", "fq", "qdue":
            return .orange
        case "taxable", "finc":
            return accent
        case "deduct", "fvel":
            return .green
        case "fexp":
            return .mint
        case "etr", "fetr":
            return .purple
        case "vat":
            return .indigo
        case "runway":
            return .blue
        case "health":
            return healthColor(for: healthBand ?? .yellow)
        default:
            return accent
        }
    }

    static func icon(for metricID: String) -> String {
        switch metricID {
        case "taxable", "finc": return "chart.bar.fill"
        case "deduct", "fexp": return "leaf.fill"
        case "tax", "ftax": return "percent"
        case "etr", "fetr": return "gauge.with.dots.needle.33percent"
        case "qdue", "fq": return "calendar.badge.clock"
        case "vat": return "building.columns.fill"
        case "runway": return "hourglass"
        case "health": return "heart.text.square.fill"
        case "fvel": return "arrow.up.right"
        default: return "circle.fill"
        }
    }
}

struct TaxStudioMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let metric: TaxStudioMetricDisplay
    var healthBand: TaxHealthBand? = nil

    private var metricColor: Color {
        TaxStudioMetricPalette.color(
            for: metric.id,
            accent: themeManager.contrastAccentColor(for: colorScheme),
            healthBand: healthBand
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Text(
                    BuxCatalogLabel.string(metric.title, locale: appSettingsManager.interfaceLocale)
                )
                .font(.system(size: 10, weight: .semibold))
                .buxLabelSecondary()
                .lineLimit(2)
                .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                Image(systemName: TaxStudioMetricPalette.icon(for: metric.id))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(metricColor.opacity(0.85))
            }

            Text(metric.value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(metricColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(
                BuxCatalogLabel.string(metric.subtitle, locale: appSettingsManager.interfaceLocale)
            )
            .font(.system(size: 10, weight: .medium))
            .buxLabelSecondary()
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(12)
        .studioThemedCardChrome(cornerRadius: 16)
    }
}

// MARK: - Thresholds

struct TaxStudioThresholdCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    Text(warning)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.12 : 0.08))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.orange)
                .frame(width: 4)
                .padding(.vertical, 14)
                .padding(.leading, 6)
        }
        .studioThemedCardChrome(cornerRadius: 16)
    }
}

// MARK: - Phase B — Health

struct TaxStudioHealthHeroCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let health: TaxStudioHealthDisplay

    var body: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            VStack(spacing: 18) {
                TaxStudioScoreGauge(
                    score: health.score,
                    band: health.band,
                    riskLevel: health.riskLevel,
                    size: .hero
                )
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .frame(maxWidth: .infinity)

                if !health.factors.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(health.factors) { factor in
                            TaxStudioHealthFactorRow(factor: factor)
                                .environmentObject(themeManager)
                                .environmentObject(appSettingsManager)
                        }
                    }
                }
            }
        }
    }
}

struct TaxStudioHealthFactorRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let factor: TaxStudioHealthFactorDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(factor.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Spacer(minLength: 8)
                Text(factor.valueLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            ProgressView(value: min(max(factor.progress, 0), 1))
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .scaleEffect(x: 1, y: 1.35, anchor: .center)
        }
        .padding(12)
        .background(Color.secondary.opacity(colorScheme == .dark ? 0.14 : 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TaxStudioRecommendationCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let index: Int
    let recommendation: TaxStudioCoachCardDisplay

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(themeManager.current.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(recommendation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(recommendation.body)
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .studioThemedCardChrome(cornerRadius: 16)
    }
}

struct TaxStudioSanityAlertCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let warning: TaxStudioSanityDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                Text(warning.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(warning.detail)
                .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            Text(warning.suggestion)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.28), lineWidth: 0.5)
        }
    }
}

// MARK: - Phase B — Timeline

struct TaxStudioTimelineMonthGroup: Identifiable {
    let id: String
    let monthLabel: String
    let events: [TaxStudioTimelineEventDisplay]
}

enum TaxStudioTimelineGrouping {
    static func monthGroups(
        from events: [TaxStudioTimelineEventDisplay],
        locale: Locale
    ) -> [TaxStudioTimelineMonthGroup] {
        var order: [String] = []
        var buckets: [String: [TaxStudioTimelineEventDisplay]] = [:]

        for event in events {
            let key = monthKey(for: event.date)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(event)
        }

        return order.compactMap { key in
            guard let monthEvents = buckets[key], let first = monthEvents.first else { return nil }
            return TaxStudioTimelineMonthGroup(
                id: key,
                monthLabel: BuxDisplayDate.monthYear(from: first.date, locale: locale),
                events: monthEvents
            )
        }
    }

    private static func monthKey(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return "\(year)-\(month)"
    }
}

struct TaxStudioTimelineRail: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let events: [TaxStudioTimelineEventDisplay]

    private var groups: [TaxStudioTimelineMonthGroup] {
        TaxStudioTimelineGrouping.monthGroups(
            from: events,
            locale: appSettingsManager.interfaceLocale
        )
    }

    var body: some View {
        if events.isEmpty {
            TaxStudioTimelineEmptyCard()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
        } else {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.monthLabel)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                            .padding(.leading, 2)

                        VStack(spacing: 0) {
                            ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                                TaxStudioTimelineRailRow(
                                    event: event,
                                    showsConnector: index < group.events.count - 1
                                )
                                .environmentObject(themeManager)
                                .environmentObject(appSettingsManager)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct TaxStudioTimelineRailRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let event: TaxStudioTimelineEventDisplay
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(event.accent.opacity(colorScheme == .dark ? 0.22 : 0.14))
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(event.accent)
                        .frame(width: 10, height: 10)
                }

                if showsConnector {
                    Rectangle()
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.28 : 0.18))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.dateLabel)
                    .font(.system(size: 10, weight: .bold))
                    .buxLabelSecondary()
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                Text(event.subtitle)
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                if event.isNextHighlight {
                    BuxCatalogDynamicText(key: "Next up")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        event.isNextHighlight
                            ? themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08)
                            : Color.clear
                    )
            }
            .studioThemedCardChrome(cornerRadius: 16)
            .padding(.bottom, showsConnector ? 10 : 0)
        }
    }
}

struct TaxStudioTimelineEmptyCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme).opacity(0.85))
                BuxCatalogDynamicText(key: "No tax deadlines yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                BuxCatalogDynamicText(key: "Set up your tax profile to see quarterly payments and compliance checkpoints.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Phase B — Calculator

// MARK: - Phase C — Charts

struct TaxStudioSparklineCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let points: [Double]
    let totalLabel: String

    private var hasData: Bool {
        !points.isEmpty && points.contains(where: { $0 > 0 })
    }

    var body: some View {
        if hasData {
            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        BuxCatalogDynamicText(key: "Tax pressure · 6 mo")
                            .font(.system(size: 11, weight: .semibold))
                            .buxLabelSecondary()
                        Spacer(minLength: 8)
                        Text(totalLabel)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }

                    SparklineChart(
                        points: points,
                        color: .orange,
                        showAreaFill: true
                    )
                    .frame(height: 56)
                }
            }
        }
    }
}

struct TaxStudioForecastBarChart: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let bars: [TaxStudioForecastBar]

    private var yDomain: ClosedRange<Double> {
        BuxChartMotion.paddedYDomain(for: bars.map(\.value))
    }

    var body: some View {
        if !bars.isEmpty {
            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                VStack(alignment: .leading, spacing: 12) {
                    BuxCatalogDynamicText(key: "Projected monthly tax")
                        .font(.system(size: 11, weight: .semibold))
                        .buxLabelSecondary()

                    Chart {
                        ForEach(bars) { bar in
                            BarMark(
                                x: .value("Month", bar.monthLabel),
                                y: .value("Tax", bar.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        themeManager.current.accentColor,
                                        themeManager.current.accentColor.opacity(0.55)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(4)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisValueLabel()
                                .font(.system(size: 9, weight: .medium))
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartYScale(domain: yDomain)
                    .frame(height: 140)
                }
            }
        }
    }
}

struct TaxStudioFeatureCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let titleKey: String
    let subtitleKey: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogDynamicText(key: titleKey)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .multilineTextAlignment(.leading)
                BuxCatalogDynamicText(key: subtitleKey)
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                .opacity(0.55)
        }
        .padding(14)
        .studioThemedCardChrome(cornerRadius: 16)
        .contentShape(Rectangle())
    }
}
