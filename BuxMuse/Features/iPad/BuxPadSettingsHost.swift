//
//  BuxPadSettingsHost.swift
//  BuxMuse — iPad Settings: split sidebar + detail on regular width.
//

import SwiftUI

struct BuxPadSettingsHost: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @ObservedObject private var store = SettingsStore.shared

    @State private var selectedDestination: SettingsDestinationType?
    @State private var proUpsellFeature: StudioProUpsellSheet.Feature?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        padSplitSettings
            .sheet(item: $proUpsellFeature) { feature in
                StudioProUpsellSheet(feature: feature)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(simpleStudioStore)
                    .buxThemedSheetContent()
            }
            .onAppear {
                restoreSettingsSelectionIfNeeded()
                routeToPendingSettingsDestination()
            }
            .onChange(of: navigationCoordinator.selectedTab) { _, tab in
                guard tab == .settings else { return }
                routeToPendingSettingsDestination()
            }
            .onChange(of: navigationCoordinator.openStudioSettingsRequest) { _, requested in
                guard requested else { return }
                selectedDestination = .studio
                padNavigationBrain.selectedSettingsPath = SettingsDestinationType.studio.rawValue
                _ = navigationCoordinator.consumeStudioSettingsRequest()
            }
            .onChange(of: navigationCoordinator.openPaymentSettingsRequest) { _, requested in
                guard requested else { return }
                selectedDestination = .paymentSources
                padNavigationBrain.selectedSettingsPath = SettingsDestinationType.paymentSources.rawValue
                _ = navigationCoordinator.consumePaymentSettingsRequest()
            }
            .onChange(of: navigationCoordinator.openProfileSettingsRequest) { _, requested in
                guard requested else { return }
                selectedDestination = .profile
                padNavigationBrain.selectedSettingsPath = SettingsDestinationType.profile.rawValue
                _ = navigationCoordinator.consumeProfileSettingsRequest()
            }
            .onChange(of: navigationCoordinator.openAppearanceSettingsRequest) { _, requested in
                guard requested else { return }
                routeToPendingSettingsDestination()
            }
            .buxPadDebouncedBrainResize(columnVisibility: columnVisibility)
    }

    private var padSplitSettings: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                settingsSidebar
                    .buxPadSplitSidebarColumnWidth(layoutMode: layoutMode)
            } detail: {
                settingsDetailColumn
                    .environment(\.buxPadSettingsUsesSplitLayout, true)
                    .buxPadStudioSplitDetailChrome()
            }
            .navigationSplitViewStyle(.balanced)
            .toolbarBackground(.hidden, for: .navigationBar)
            .ignoresSafeArea(edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.settingsEnhancedTint, true)
    }

    @ViewBuilder
    private var settingsDetailColumn: some View {
        if let selectedDestination {
            BuxPadSettingsDetailView(destination: selectedDestination)
        } else {
            ZStack {
                BuxLandingTintBackground()
                    .ignoresSafeArea()

                BuxPadDetailEmptyState(
                    title: "Settings",
                    systemImage: "gearshape.fill",
                    message: "Choose a setting from the sidebar."
                )
            }
        }
    }

    private var settingsSidebar: some View {
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

        return List {
            Section {
                settingsSidebarHeader
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
            }

            ForEach(display.sections) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in
                        padSettingsSidebarRow(row, isSelected: selectedDestination == row.destination)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .buxPadSidebarToggleTint(themeManager.contrastAccentColor(for: colorScheme))
        .onChange(of: selectedDestination) { _, newValue in
            padNavigationBrain.selectedSettingsPath = newValue?.rawValue
        }
    }

    private var settingsSidebarHeader: some View {
        BuxRootTabHeader.rootScrollRow(
            style: .plain(titleKey: "Settings", showCountrySubtitle: false)
        )
        .padding(.horizontal, BuxPadLayout.detailInsetCompact)
    }

    @ViewBuilder
    private func padSettingsSidebarRow(_ row: SettingsRowDisplay, isSelected: Bool) -> some View {
        let showsUpsell = row.tier == .proOnly && !StudioFeatureGate.isPro
        let rowLabel = SettingsRow(
            icon: row.iconName,
            label: row.title,
            color: Color(hex: row.hexColor),
            trailingText: row.trailingText,
            showsProBadge: row.showsProBadge && (row.tier == .freemium || StudioFeatureGate.isPro),
            showsChevron: false,
            compact: true
        )

        if showsUpsell, let feature = StudioFeatureGate.upsellFeature(for: row.destination) {
            Button {
                proUpsellFeature = feature
            } label: {
                rowLabel
            }
            .buxSettingsRowInteraction()
            .listRowBackground(padSidebarRowBackground(isSelected: isSelected))
            .listRowInsets(padSidebarRowInsets)
            .listRowSeparator(.hidden)
        } else {
            Button {
                BuxPadSidebarSelection.select(row.destination, into: $selectedDestination)
            } label: {
                rowLabel
            }
            .buxSettingsRowInteraction()
            .listRowBackground(padSidebarRowBackground(isSelected: isSelected))
            .listRowInsets(padSidebarRowInsets)
            .listRowSeparator(.hidden)
            .buxPadSettingsSidebarContextMenu(
                destination: row.destination,
                isSelected: isSelected
            ) {
                BuxPadSidebarSelection.select(row.destination, into: $selectedDestination)
            }
        }
    }

    private var padSidebarRowInsets: EdgeInsets {
        BuxPadSidebarSelection.rowInsets
    }

    private func padSidebarRowBackground(isSelected: Bool) -> some View {
        BuxPadSidebarSelection.rowBackground(
            isSelected: isSelected,
            themeManager: themeManager,
            colorScheme: colorScheme
        )
    }

    private func restoreSettingsSelectionIfNeeded() {
        if let raw = padNavigationBrain.selectedSettingsPath,
           let restored = SettingsDestinationType(rawValue: raw) {
            selectedDestination = restored
        }
    }

    private func routeToPendingSettingsDestination() {
        if let destination = navigationCoordinator.takePendingSettingsDestination() {
            selectedDestination = destination
            padNavigationBrain.selectedSettingsPath = destination.rawValue
        }

        if navigationCoordinator.openAppearanceSettingsRequest {
            selectedDestination = .appearance
            padNavigationBrain.selectedSettingsPath = SettingsDestinationType.appearance.rawValue
            _ = navigationCoordinator.consumeAppearanceSettingsRequest()
        }
    }
}
