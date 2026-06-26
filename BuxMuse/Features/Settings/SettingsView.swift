//
//  SettingsView.swift
//  BuxMuse
//
//  Features/Settings/
//
//  Unified premium Settings Cockpit managing identity, budgets, security, and data.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var tutorialCoordinator: AppTutorialCoordinator
    @EnvironmentObject private var brain: BuxMuseBrain
    @EnvironmentObject private var debtEngine: DebtEngine
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @ObservedObject private var store = SettingsStore.shared
    @State private var settingsPath = NavigationPath()
    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?
    @State private var showOnboardingReplay = false
    @State private var isAdvancedExpanded = false
    var body: some View {
        NavigationStack(path: $settingsPath) {
            ZStack {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: BuxTokens.block) {
                        // Generate layout dynamically from SettingsBrain display structs
                        let appearanceLabel = store.resolvedAppearanceSummary(
                            themeManager: themeManager,
                            locale: appSettingsManager.interfaceLocale
                        )
                        let display = SettingsBrain.generateOverview(
                            store: store,
                            currentThemeName: appearanceLabel,
                            activeCurrencyCode: appSettingsManager.selectedCurrency.id,
                            activeCurrencyFlag: appSettingsManager.selectedCurrency.flag,
                            interfaceLocale: appSettingsManager.interfaceLocale
                        )
                        
                        ForEach(Array(display.sections.enumerated()), id: \.element.id) { sectionIndex, section in
                            settingsSectionView(section: section, sectionIndex: sectionIndex)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            BuxSectionHeader(title: "Guides & Help")
                                .padding(.leading, 4)

                            VStack(spacing: 0) {
                                Button {
                                    showOnboardingReplay = true
                                } label: {
                                    SettingsRow(
                                        icon: "sparkles",
                                        label: "Replay Onboarding Guide",
                                        color: themeManager.contrastAccentColor(for: colorScheme),
                                        trailingText: nil,
                                        showsProBadge: false
                                    )
                                }
                                .buxSettingsRowInteraction()

                                Divider().opacity(0.08)

                                Button {
                                    tutorialCoordinator.restartTour()
                                } label: {
                                    SettingsRow(
                                        icon: "point.topleft.down.curvedto.point.bottomright.up",
                                        label: "Take app tour again",
                                        color: themeManager.contrastAccentColor(for: colorScheme),
                                        trailingText: nil,
                                        showsProBadge: false
                                    )
                                }
                                .buxSettingsRowInteraction()
                            }
                            .settingsThemedCardChrome(cornerRadius: 20)
                        }

                        Spacer(minLength: BuxTokens.tight)
                    }
                    .padding(.top, BuxTokens.tight)
                }
                .id(appSettingsManager.interfaceLanguage.rawValue)
                .buxRootTabScrollChrome()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollDisabled(tutorialCoordinator.isActive)
                .tutorialScrollToActiveAnchor(coordinator: tutorialCoordinator, proxy: scrollProxy)
                }
            }
            .buxCatalogNavigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .buxRootNavigationChrome()
            .environment(\.isSettingsContext, true)
            .onChange(of: navigationCoordinator.openStudioSettingsRequest) { _, requested in
                guard requested else { return }
                settingsPath.append(SettingsDestinationType.studio)
                _ = navigationCoordinator.consumeStudioSettingsRequest()
            }
            .onChange(of: navigationCoordinator.openPaymentSettingsRequest) { _, requested in
                guard requested else { return }
                settingsPath.append(SettingsDestinationType.paymentSources)
                _ = navigationCoordinator.consumePaymentSettingsRequest()
            }
            .onChange(of: navigationCoordinator.openDebtsSettingsRequest) { _, requested in
                guard requested else { return }
                settingsPath.append(SettingsDestinationType.debts)
                _ = navigationCoordinator.consumeDebtsSettingsRequest()
            }
            .onChange(of: navigationCoordinator.openProfileSettingsRequest) { _, requested in
                guard requested else { return }
                settingsPath.append(SettingsDestinationType.profile)
                _ = navigationCoordinator.consumeProfileSettingsRequest()
            }
            .onChange(of: navigationCoordinator.openAppearanceSettingsRequest) { _, requested in
                guard requested else { return }
                routeToAppearanceSettings()
            }
            .onAppear {
                if navigationCoordinator.openAppearanceSettingsRequest {
                    routeToAppearanceSettings()
                }
                routeTutorialSettingsNavigation()
            }
            .onChange(of: tutorialCoordinator.currentStepIndex) { _, _ in
                routeTutorialSettingsNavigation()
            }
            .onChange(of: tutorialCoordinator.pendingSettingsDestination) { _, destination in
                guard destination != nil else { return }
                routeTutorialSettingsNavigation()
            }
            .onChange(of: tutorialCoordinator.pendingSettingsPopToRoot) { _, shouldPop in
                guard shouldPop else { return }
                routeTutorialSettingsNavigation()
            }
            .navigationDestination(for: SettingsDestinationType.self) { destination in
                SettingsDrillInBackdrop {
                    settingsDrillInContent(for: destination)
                }
                .buxInterfaceLocale()
                .environment(\.settingsEnhancedTint, true)
            }
            .environment(\.settingsEnhancedTint, true)
            .sheet(item: $proUpsellFeature) { feature in
                StudioProUpsellSheet(feature: feature)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(simpleStudioStore)
            }
            .sheet(isPresented: $showOnboardingReplay) {
                OnboardingWizardView()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxThemedSheetContent()
            }
        }
    }

    private func routeToAppearanceSettings() {
        settingsPath = NavigationPath()
        settingsPath.append(SettingsDestinationType.appearance)
        _ = navigationCoordinator.consumeAppearanceSettingsRequest()
        _ = navigationCoordinator.takePendingSettingsDestination()
    }

    private func routeTutorialSettingsNavigation() {
        if tutorialCoordinator.consumeSettingsPopToRoot() {
            settingsPath = NavigationPath()
        }
        guard let destination = tutorialCoordinator.consumeSettingsDestinationRequest() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            settingsPath = NavigationPath()
            settingsPath.append(destination)
        }
    }

    @ViewBuilder
    private func settingsDrillInContent(for destination: SettingsDestinationType) -> some View {
        switch destination {
        case .profile:
            ProfileSettingsView()
        case .subscription:
            BuxMuseSubscriptionView(isBlocking: false)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
        case .appearance:
            AppearanceSettingsView()
        case .regionCurrency:
            RegionCurrencySettingsView()
        case .budgets:
            BudgetSettingsView()
        case .studio:
            StudioSettingsView()
        case .invoicePayment:
            InvoicePaymentSettingsView()
        case .mileage:
            MileageSettingsView()
        case .notifications:
            NotificationSettingsView()
        case .security:
            SecuritySettingsView()
        case .data:
            DataSettingsView()
        case .about:
            AboutSettingsView()
        case .hustles:
            HustleSettingsView()
        case .dualCashDrawer:
            DualCashDrawerSettingsView()
        case .barterLogger:
            BarterLoggerSettingsView()
        case .scopeCreepRadar:
            ScopeCreepRadarSettingsView()
        case .agreementScratchpad:
            AgreementScratchpadSettingsView()
        case .burnoutGuard:
            BurnoutGuardSettingsView()
        case .appleWallet:
            AppleWalletSettingsView()
                .environmentObject(brain)
        case .paymentSources:
            PaymentSourceSettingsView()
        case .categories:
            ExpenseCategoryListSheet()
                .environmentObject(brain)
        case .merchants:
            ExpenseMerchantListSheet()
                .environmentObject(brain)
        case .subscriptions:
            SubscriptionsSettingsEmbedView()
                .environmentObject(brain)
                .environmentObject(financialBridge)
        case .workTools:
            WorkToolsSettingsView()
        case .debts:
            DebtsSettingsView()
                .environmentObject(debtEngine)
        case .household:
            HouseholdSettingsView()
                .environmentObject(brain)
        case .personalCloudSync:
            PersonalCloudSyncSettingsView()
                .environmentObject(brain)
                .environmentObject(debtEngine)
        }
    }

    @ViewBuilder
    private func settingsSectionView(section: SettingsSectionDisplay, sectionIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if section.isAdvancedSection {
                Button {
                    withAnimation(.buxSnap) { isAdvancedExpanded.toggle() }
                } label: {
                    HStack {
                        BuxSectionHeader(title: section.title)
                        Spacer()
                        Image(systemName: isAdvancedExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    }
                    .padding(.leading, 4)
                }
                .buttonStyle(.plain)
            } else {
                BuxSectionHeader(title: section.title)
                    .padding(.leading, 4)
            }

            if !section.isAdvancedSection || isAdvancedExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                        settingsRowButton(for: row)

                        if index < section.rows.count - 1 {
                            Divider().opacity(0.08)
                        }
                    }
                }
                .settingsThemedCardChrome(cornerRadius: 20)
            }

            if let footerKey = section.footerKey {
                BuxCatalogDynamicText(key: footerKey)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .padding(.horizontal, 8)
            }
        }
        .modifier(
            SettingsOverviewTutorialAnchorModifier(
                isFirstSection: sectionIndex == 0,
                coordinator: tutorialCoordinator
            )
        )
    }

    @ViewBuilder
    private func settingsRowButton(for row: SettingsRowDisplay) -> some View {
        let showsUpsell = row.tier == .proOnly && !StudioFeatureGate.isPro

        if row.opensSubscriptionHub {
            Button {
                navigationCoordinator.openSubscriptionHub()
            } label: {
                SettingsRow(
                    icon: row.iconName,
                    label: row.title,
                    color: Color(hex: row.hexColor),
                    trailingText: row.trailingText,
                    showsProBadge: row.showsProBadge
                )
            }
            .buxSettingsRowInteraction()
        } else if showsUpsell, let feature = StudioFeatureGate.upsellFeature(for: row.destination) {
            Button {
                proUpsellFeature = feature
            } label: {
                SettingsRow(
                    icon: row.iconName,
                    label: row.title,
                    color: Color(hex: row.hexColor),
                    trailingText: row.trailingText,
                    showsProBadge: row.showsProBadge
                )
            }
            .buxSettingsRowInteraction()
        } else {
            Button {
                settingsPath.append(row.destination)
            } label: {
                SettingsRow(
                    icon: row.iconName,
                    label: row.title,
                    color: Color(hex: row.hexColor),
                    trailingText: row.trailingText,
                    showsProBadge: row.showsProBadge && (row.tier == .freemium || StudioFeatureGate.isPro)
                )
            }
            .buxSettingsRowInteraction()
            .modifier(SettingsTutorialAnchorModifier(destination: row.destination, coordinator: tutorialCoordinator))
        }
    }
}

struct SettingsTutorialAnchorModifier: ViewModifier {
    let destination: SettingsDestinationType
    @ObservedObject var coordinator: AppTutorialCoordinator

    func body(content: Content) -> some View {
        if let anchor = destination.tutorialAnchorID {
            content.tutorialAnchor(anchor, coordinator: coordinator)
        } else {
            content
        }
    }
}

private struct SettingsOverviewTutorialAnchorModifier: ViewModifier {
    let isFirstSection: Bool
    @ObservedObject var coordinator: AppTutorialCoordinator

    func body(content: Content) -> some View {
        if isFirstSection {
            content.tutorialAnchor(.settingsOverview, coordinator: coordinator)
        } else {
            content
        }
    }
}

// MARK: - Settings drill-in backdrop (mesh + soft nav chrome)

private struct SettingsDrillInBackdrop<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var tutorialCoordinator: AppTutorialCoordinator
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()
            content()
        }
        .tutorialCoachMarkOverlay(
            layer: .settingsDetail,
            coordinator: tutorialCoordinator,
            reservesTabBarSpace: !BuxPadIdiom.isPad
        )
        .buxPushedNavigationChrome()
        .environment(\.isSettingsContext, true)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let label: String
    let color: Color
    var trailingText: String? = nil
    var showsProBadge: Bool = false
    var showsChevron: Bool = true
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 12 : 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color)
                    .frame(width: 34, height: 34)
                    .shadow(color: color.opacity(0.35), radius: 5, x: 0, y: 2)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                BuxCatalogText.text(label)
                    .font(.system(size: compact ? 14 : 15, weight: .medium))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(compact ? 0.8 : 0.85)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if showsProBadge {
                    ProFeatureBadge(compact: true)
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[.bottom] - 1
                        }
                }
            }
            .layoutPriority(0)

            Spacer(minLength: compact ? 4 : 8)

            if let trailing = trailingText {
                BuxCatalogText.text(trailing)
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(0)
                    .padding(.trailing, compact ? 2 : 4)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.chevronMuted(for: colorScheme))
            }
        }
        .padding(.horizontal, compact ? 10 : BuxLayout.section)
        .padding(.vertical, compact ? 10 : 14)
        .contentShape(Rectangle())
    }
}

// MARK: - Appearance Theme Picker View (Bottom Sheet Grid Panel) - PRESERVED UNCHANGED

struct AppearanceThemePickerView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogDynamicText(key: "Appearance")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    BuxCatalogDynamicText(key: "Select a creative brand preset")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                }
                
                Spacer()
                
                BuxToolbarCloseButton { dismiss() }
            }
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            if store.brandThemesEnabled {
                BuxThemePickerCarousel()
                    .padding(.bottom, 8)
            } else {
                BuxCatalogDynamicText(key: "Turn on Brand Themes in Appearance to choose a preset.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.vertical, 24)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
        }
        .buxThemedPresentation()
        .environment(\.settingsEnhancedTint, true)
    }
}

// MARK: - Theme Swatch Card (Grid card layout) - PRESERVED UNCHANGED

struct ThemeSwatchCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    let theme: AppTheme
    let isSelected: Bool
    var layout: ThemeSwatchCardLayout = .grid
    let onTap: () -> Void

    private var heroGradient: [Color] {
        colorScheme == .dark ? theme.heroDarkGradient : theme.heroLightGradient
    }

    private var cardCornerRadius: CGFloat {
        layout == .carousel ? 20 : 22
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: layout == .carousel ? 10 : 12) {
                if layout == .carousel {
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: heroGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 72)
                            .overlay {
                                Image(systemName: theme.icon)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.9))
                            }

                        Circle()
                            .fill(theme.accentColor)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                            }
                            .padding(8)
                    }
                    .padding(.horizontal, 4)
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: theme.heroDarkGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: theme.accentColor.opacity(0.3), radius: 8, x: 0, y: 3)

                        if isSelected {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 56, height: 56)

                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: theme.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                        }
                    }
                }

                Text(theme.localizedName(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: layout == .carousel ? 12 : 13, weight: .bold))
                    .foregroundColor(isSelected
                        ? themeManager.labelPrimary(for: colorScheme)
                        : themeManager.labelSecondary(for: colorScheme))
                    .buxAnimateThemeColors(themeId: themeManager.current.id)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)

                if layout == .carousel {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.accentColor)
                        .opacity(isSelected ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, layout == .carousel ? 12 : 20)
            .padding(.horizontal, layout == .carousel ? 12 : 0)
            .modifier(
                ThemeSwatchCardChromeModifier(
                    layout: layout,
                    cornerRadius: cardCornerRadius,
                    isSelected: isSelected,
                    accentColor: theme.accentColor
                )
            )
        }
        .buttonStyle(BuxMicroShrinkStyle())
        .padding(.vertical, layout == .carousel ? 4 : 0)
        .scaleEffect(isSelected ? (layout == .carousel ? 1.03 : 1.02) : 1.0)
        .animation(.buxBounce, value: isSelected)
        .buxStableThemeLayout(themeId: themeManager.current.id)
    }
}

// MARK: - Currency Region Picker View (Frosted glass sheet selector) - PRESERVED UNCHANGED

struct CurrencyRegionPickerView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    
    var filteredCurrencies: [CurrencySetting] {
        if searchText.isEmpty {
            return AppSettingsManager.availableCurrencies
        } else {
            let lowerQuery = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return AppSettingsManager.availableCurrencies.filter {
                $0.name.lowercased().contains(lowerQuery) ||
                $0.id.lowercased().contains(lowerQuery) ||
                $0.symbol.contains(lowerQuery)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogDynamicText(key: "Currency & region")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    BuxCatalogDynamicText(key: "Choose your preferred regional formatting")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                }
                
                Spacer()
                
                BuxToolbarCloseButton { dismiss() }
            }
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.labelTertiary(for: colorScheme))
                    .font(.system(size: 16, weight: .bold))
                
                TextField(BuxCatalogLabel.string("Search region, code or symbol...", locale: appSettingsManager.interfaceLocale), text: $searchText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .buxLabelSecondary()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .settingsThemedCardChrome(cornerRadius: 14)
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.bottom, 16)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if filteredCurrencies.isEmpty {
                        VStack(spacing: 16) {
                            Spacer(minLength: 40)
                            Image(systemName: "globe")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.6))
                            BuxCatalogDynamicText(key: "No currencies found")
                                .font(.system(size: 16, weight: .semibold))
                                .buxLabelSecondary()
                        }
                    } else {
                        ForEach(filteredCurrencies) { currency in
                            CurrencyRowCard(
                                currency: currency,
                                isSelected: appSettingsManager.selectedCurrency.id == currency.id
                            ) {
                                appSettingsManager.updateCurrency(currency)
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
        }
        .buxThemedPresentation()
        .environment(\.settingsEnhancedTint, true)
    }
}

// MARK: - Currency Row Card - PRESERVED UNCHANGED

struct CurrencyRowCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    let currency: CurrencySetting
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(currency.flag)
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(
                        BuxLocalizedString.format(
                            "%@ (%@)",
                            locale: appSettingsManager.interfaceLocale,
                            currency.id,
                            currency.symbol
                        )
                    )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                } else {
                    Circle()
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .settingsThemedCardChrome(cornerRadius: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? themeManager.current.accentColor : Color.clear, lineWidth: 1.5)
            )
            .shadow(
                color: isSelected ? themeManager.current.accentColor.opacity(0.1) : Color.black.opacity(0.02),
                radius: 6,
                x: 0, y: 3
            )
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }
}
