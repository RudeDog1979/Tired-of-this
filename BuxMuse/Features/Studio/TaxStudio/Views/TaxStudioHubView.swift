//
//  TaxStudioHubView.swift
//  BuxMuse
//
//  Tax Studio — premium self-employed tax subsystem inside Studio.
//

import SwiftUI
import Combine

@MainActor
final class TaxStudioProfileSaveBridge: ObservableObject {
    @Published var isDirty = false
    private var saveHandler: (() -> Void)?

    func bindSave(_ handler: @escaping () -> Void) { saveHandler = handler }
    func setDirty(_ dirty: Bool) { isDirty = dirty }
    func performSave() { saveHandler?() }
    func unbind() { isDirty = false; saveHandler = nil }
}

private struct TaxStudioProfileSaveBridgeKey: EnvironmentKey {
    static let defaultValue: TaxStudioProfileSaveBridge? = nil
}

extension EnvironmentValues {
    var taxStudioProfileSaveBridge: TaxStudioProfileSaveBridge? {
        get { self[TaxStudioProfileSaveBridgeKey.self] }
        set { self[TaxStudioProfileSaveBridgeKey.self] = newValue }
    }
}

struct TaxStudioHubView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appDataManager: AppDataManager
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var initialTab: TaxStudioTab = .overview
    @State private var selectedTab: TaxStudioTab = .overview
    @StateObject private var profileSaveBridge = TaxStudioProfileSaveBridge()

    private var display: TaxStudioDisplay { studioBrain.taxStudioDisplay }

    var body: some View {
        StudioThemedListBackdrop {
            List {
                if display.showMonthlyBanner {
                    Section {
                        TaxStudioDisclaimerBanner()
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    TaxStudioNavigationTitle(style: .large)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .studioHubEmbeddedHorizontalPadding()
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                Section {
                    taxSectionMenu
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                Section {
                    tabBody
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .contentMargins(.top, BuxLayout.invoicesNavChromeScrollInset, for: .scrollContent)
            .studioThemedListRows()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == .settings {
                    BuxToolbarSaveButton(isDirty: profileSaveBridge.isDirty) {
                        profileSaveBridge.performSave()
                    }
                }
            }
        }
        .environment(\.taxStudioProfileSaveBridge, profileSaveBridge)
        .onAppear {
            selectedTab = initialTab
            studioBrain.refreshTaxStudio()
            Task { await TaxManager.shared.ensureCatalogLoaded() }
        }
    }

    private var taxSectionMenu: some View {
        StudioGlassHorizontalSectionMenu(
            selection: $selectedTab,
            tabs: TaxStudioTab.allCases,
            label: { $0.catalogLabel(locale: appSettingsManager.interfaceLocale) }
        )
    }

    @ViewBuilder
    private var tabBody: some View {
        switch selectedTab {
        case .overview:
            TaxStudioOverviewView(display: display)
        case .calculator:
            TaxStudioCalculatorView(display: display)
                .environmentObject(studioBrain)
        case .forecast:
            TaxStudioForecastView(display: display)
        case .timeline:
            TaxStudioTimelineView(display: display)
        case .health:
            TaxStudioHealthScoreView(display: display)
        case .coach:
            TaxStudioCoachView(display: display)
        case .settings:
            TaxStudioSettingsView()
                .environmentObject(appDataManager)
                .environment(\.studioHubEmbedded, true)
        }
    }
}

// MARK: - Tab stack (hub List owns scroll + large-title collapse)

@ViewBuilder
private func taxStudioTabStack<Content: View>(
    spacing: CGFloat = BuxLayout.section,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: spacing) {
        content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .studioHubEmbeddedHorizontalPadding()
    .padding(.top, BuxLayout.tight)
}

// MARK: - Disclaimer

struct TaxStudioDisclaimerBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: BuxTokens.tight) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(themeManager.current.accentColor)
                BuxCatalogDynamicText(key: TaxReferenceCopy.monthlyDataBanner)
                    .buxCaptionStyle(color: themeManager.labelPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            TaxReferenceDisclaimerNote()
        }
        .studioHubEmbeddedHorizontalPadding()
        .onAppear {
            let c = Calendar.current
            let key = "\(c.component(.year, from: Date()))-\(c.component(.month, from: Date()))"
            UserDefaults.standard.set(key, forKey: "tax_studio_banner_month")
        }
    }
}

// MARK: - Overview

struct TaxStudioOverviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.section) {
            TaxStudioHeroCard(hero: display.hero)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)

            TaxStudioSparklineCard(
                points: display.taxPressureSparkline,
                totalLabel: display.taxPressureSparklineLabel
            )
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)

            if !display.autopilot.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    TaxStudioRibbon(titleKey: "Autopilot", systemImage: "sparkles")
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)

                    VStack(spacing: 8) {
                        ForEach(display.autopilot) { item in
                            TaxStudioInsightChip(
                                icon: item.icon,
                                message: item.message,
                                tone: item.tone
                            )
                            .environmentObject(themeManager)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TaxStudioRibbon(titleKey: "Key metrics", systemImage: "square.grid.2x2.fill")
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: BuxTokens.tight),
                        GridItem(.flexible(), spacing: BuxTokens.tight)
                    ],
                    spacing: BuxTokens.tight
                ) {
                    ForEach(display.metrics) { metric in
                        TaxStudioMetricCard(
                            metric: metric,
                            healthBand: metric.id == "health" ? display.health.band : nil
                        )
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                    }
                }
            }

            if !display.thresholdWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    TaxStudioRibbon(titleKey: "Thresholds", systemImage: "exclamationmark.triangle.fill")
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)

                    TaxStudioThresholdCard(warnings: display.thresholdWarnings)
                        .environmentObject(themeManager)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(display.bracketLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))

                Text(display.catalogUpdatedLabel)
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
            }
            .padding(.horizontal, 2)

            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Calculator

struct TaxStudioCalculatorView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioBrain: StudioBrain
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.section) {
            TaxStudioRibbon(titleKey: "Calculator", systemImage: "function")
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)

            TaxStudioRibbon(
                titleKey: "Live tax sandbox",
                subtitle: TaxStudioL10n.line(
                    "Adjust sliders to stress-test your tax profile.",
                    locale: appSettingsManager.interfaceLocale
                ),
                systemImage: "slider.horizontal.3"
            )
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)

            StudioTaxOverviewView()
                .environmentObject(studioBrain)
                .environment(\.studioHubEmbedded, true)

            VStack(spacing: BuxTokens.tight) {
                NavigationLink {
                    StudioIncomeTaxCalculatorView()
                        .environmentObject(studioBrain)
                } label: {
                    TaxStudioFeatureCard(
                        titleKey: "Income tax calculator",
                        subtitleKey: "Annual estimate from gross income, deductions, and your effective rates.",
                        icon: "function",
                        tint: .orange
                    )
                    .environmentObject(themeManager)
                }

                NavigationLink {
                    StudioQuarterlyTaxView()
                        .environmentObject(studioBrain)
                } label: {
                    TaxStudioFeatureCard(
                        titleKey: "Quarterly tax",
                        subtitleKey: "Quarter totals, next payment date, and set-aside guidance.",
                        icon: "calendar.badge.clock",
                        tint: themeManager.current.accentColor
                    )
                    .environmentObject(themeManager)
                }
            }

            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Forecast

struct TaxStudioForecastView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.section) {
            TaxStudioRibbon(titleKey: "12-month projection", systemImage: "chart.line.uptrend.xyaxis")
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)

            TaxStudioForecastBarChart(bars: display.forecastMonthlyBars)
                .environmentObject(themeManager)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: BuxTokens.tight),
                    GridItem(.flexible(), spacing: BuxTokens.tight)
                ],
                spacing: BuxTokens.tight
            ) {
                ForEach(display.forecastRows) { row in
                    TaxStudioMetricCard(metric: row)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                }
            }
            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Timeline

struct TaxStudioTimelineView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.section) {
            TaxStudioRibbon(titleKey: "Timeline", systemImage: "calendar")
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)

            TaxStudioTimelineRail(events: display.timeline)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Health

struct TaxStudioHealthScoreView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.section) {
            TaxStudioRibbon(titleKey: "Health", systemImage: "heart.text.square.fill")
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)

            TaxStudioHealthHeroCard(health: display.health)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)

            if !display.health.recommendations.isEmpty {
                TaxStudioRibbon(titleKey: "Recommendations", systemImage: "list.number")
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)

                VStack(spacing: BuxTokens.tight) {
                    ForEach(Array(display.health.recommendations.enumerated()), id: \.element.id) { index, rec in
                        TaxStudioRecommendationCard(index: index + 1, recommendation: rec)
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                    }
                }
            }

            if !display.sanity.isEmpty {
                TaxStudioRibbon(titleKey: "Sanity checks", systemImage: "checkmark.shield.fill")
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)

                VStack(spacing: BuxTokens.tight) {
                    ForEach(display.sanity) { w in
                        TaxStudioSanityAlertCard(warning: w)
                            .environmentObject(themeManager)
                    }
                }
            }

            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Coach

struct TaxStudioCoachView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.section) {
            TaxStudioRibbon(titleKey: "Coach", systemImage: "lightbulb.fill")
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)

            ForEach(display.coachCards) { card in
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        BuxCatalogLabel.string(card.category, locale: appSettingsManager.interfaceLocale)
                    )
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(themeManager.current.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.12))
                        .clipShape(Capsule())
                    Text(card.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(card.body)
                        .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .studioThemedCardChrome(cornerRadius: 16)
            }
            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Settings

struct TaxStudioSettingsView: View {
    @EnvironmentObject private var appDataManager: AppDataManager
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.section) {
            TaxStudioRibbon(titleKey: "Settings", systemImage: "slider.horizontal.3")
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)

            StudioTaxReferenceView()
        }
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environmentObject(store)
            .environmentObject(appDataManager)
    }
}
