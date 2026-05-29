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
        .navigationTitle("Tax Studio")
        .navigationBarTitleDisplayMode(.large)
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
            label: { $0.menuLabel }
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
                Text(TaxReferenceCopy.monthlyDataBanner)
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
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack {
            if !display.autopilot.isEmpty {
                VStack(alignment: .leading, spacing: BuxTokens.tight) {
                    Text("AUTOPILOT")
                        .font(.system(size: 11, weight: .bold))
                        .buxLabelSecondary()
                    ForEach(display.autopilot) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.icon)
                                .foregroundColor(themeManager.current.accentColor)
                            Text(item.message)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        }
                        .padding(12)
                        .studioThemedCardChrome(cornerRadius: 14)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BuxTokens.tight) {
                ForEach(display.metrics) { metric in
                    TaxStudioMetricCard(metric: metric)
                }
            }

            if !display.thresholdWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("THRESHOLDS")
                        .font(.system(size: 11, weight: .bold))
                        .buxLabelSecondary()
                    ForEach(display.thresholdWarnings, id: \.self) { w in
                        Text(w)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                .padding(14)
                .studioThemedCardChrome(cornerRadius: 16)
            }

            Text(display.bracketLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))

            Text(display.catalogUpdatedLabel)
                .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))

            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }
}

struct TaxStudioMetricCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let metric: TaxStudioMetricDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .buxLabelSecondary()
            Text(metric.value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.current.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(metric.subtitle)
                .font(.system(size: 10, weight: .medium))
                .buxLabelSecondary()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .studioThemedCardChrome(cornerRadius: 16)
    }
}

// MARK: - Calculator

struct TaxStudioCalculatorView: View {
    @EnvironmentObject private var studioBrain: StudioBrain
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack {
            StudioTaxOverviewView()
                .environmentObject(studioBrain)
                .environment(\.studioHubEmbedded, true)

            NavigationLink {
                StudioIncomeTaxCalculatorView()
                    .environmentObject(studioBrain)
            } label: {
                linkRow("Income Tax Calculator", icon: "function")
            }

            NavigationLink {
                StudioQuarterlyTaxView()
                    .environmentObject(studioBrain)
            } label: {
                linkRow("Quarterly Tax", icon: "calendar.badge.clock")
            }

            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }

    private func linkRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .opacity(0.5)
        }
        .padding(14)
        .studioThemedCardChrome(cornerRadius: 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Forecast

struct TaxStudioForecastView: View {
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.tight) {
            Text("12-MONTH PROJECTION")
                .font(.system(size: 11, weight: .bold))
                .buxLabelSecondary()
            ForEach(display.forecastRows) { row in
                TaxStudioMetricCard(metric: row)
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
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.tight) {
            ForEach(display.timeline) { event in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(event.accent)
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.dateLabel)
                            .font(.system(size: 10, weight: .bold))
                            .buxLabelSecondary()
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        Text(event.subtitle)
                            .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    }
                    Spacer()
                }
                .padding(14)
                .studioThemedCardChrome(cornerRadius: 16)
            }
            TaxReferenceDisclaimerNote()
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Health

struct TaxStudioHealthScoreView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let display: TaxStudioDisplay

    private var scoreColor: Color {
        switch display.health.band {
        case .green: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }

    var body: some View {
        taxStudioTabStack {
            VStack(spacing: 8) {
                Text("\(display.health.score)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
                Text("Tax Health · \(display.health.riskLevel) risk")
                    .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(BuxLayout.section)
            .studioThemedCardChrome(cornerRadius: 20)

            ForEach(display.health.recommendations) { rec in
                VStack(alignment: .leading, spacing: 6) {
                    Text(rec.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(rec.body)
                        .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                }
                .padding(14)
                .studioThemedCardChrome(cornerRadius: 16)
            }

            ForEach(display.sanity) { w in
                VStack(alignment: .leading, spacing: 4) {
                    Text(w.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    Text(w.detail)
                        .buxCaptionStyle(color: themeManager.labelSecondary(for: colorScheme))
                    Text(w.suggestion)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.current.accentColor)
                }
                .padding(14)
                .studioThemedCardChrome(cornerRadius: 14)
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
    let display: TaxStudioDisplay

    var body: some View {
        taxStudioTabStack(spacing: BuxTokens.tight) {
            ForEach(display.coachCards) { card in
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.category.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(themeManager.current.accentColor)
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
        StudioTaxReferenceView()
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .environmentObject(store)
            .environmentObject(appDataManager)
    }
}
