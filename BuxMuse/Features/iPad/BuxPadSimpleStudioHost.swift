//
//  BuxPadSimpleStudioHost.swift
//  BuxMuse — iPad Simple Studio: split sidebar + detail (regular + compact width).
//

import SwiftUI

struct BuxPadSimpleStudioHost: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var financialBridge: FinancialEngineBridge
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var simpleStudioBrain: SimpleStudioBrain
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain
    @EnvironmentObject private var appDataManager: AppDataManager
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain

    @State private var selection: BuxPadSimpleStudioDestination? = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        padSplitSimpleStudio
            .onAppear {
                restoreSelectionIfNeeded()
            }
            .onChange(of: selection) { _, newValue in
                padNavigationBrain.selectedStudioDestination = newValue?.rawValue
            }
            .buxPadDebouncedBrainResize(columnVisibility: columnVisibility)
    }

    private var padSplitSimpleStudio: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()
                .animation(nil, value: selection)

            NavigationSplitView(columnVisibility: $columnVisibility) {
                BuxPadSimpleStudioSidebar(selection: $selection)
                    .buxPadSplitColumnEnvironment(container, padBrain: padNavigationBrain)
                    .buxPadSplitSidebarColumnWidth(layoutMode: layoutMode)
            } detail: {
                BuxPadSplitDetailCanvas(selection: selection) {
                    simpleDetailColumn
                        .buxPadSplitDetailTransition()
                }
                .buxPadSplitColumnEnvironment(container, padBrain: padNavigationBrain)
                .environment(\.buxPadStudioUsesSplitLayout, true)
                .buxPadStudioSplitDetailChrome()
            }
            .buxPadSplitDetailNavigationAnimation(value: selection)
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BuxPadExternalDisplayMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    BuxPadOpenStudioWindowButton(simpleDestination: selection)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .ignoresSafeArea(edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.studioEnhancedTint, true)
    }

    @ViewBuilder
    private var simpleDetailColumn: some View {
        if let selection {
            BuxPadSimpleStudioDetailRouter(destination: selection)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(navigationCoordinator)
                .environmentObject(financialBridge)
                .environmentObject(studioStore)
                .environmentObject(studioBrain)
                .environmentObject(simpleStudioStore)
                .environmentObject(simpleStudioBrain)
                .environmentObject(taxEnvelopeBrain)
                .environmentObject(appDataManager)
        } else {
            BuxPadDetailEmptyState(
                title: "Simple Studio",
                systemImage: "briefcase.fill",
                message: "Choose a tool from the sidebar."
            )
        }
    }

    private func restoreSelectionIfNeeded() {
        if let raw = padNavigationBrain.selectedStudioDestination,
           let restored = BuxPadSimpleStudioDestination(rawValue: raw) {
            selection = restored
        } else if selection == nil {
            selection = .home
        }
        padNavigationBrain.selectedStudioDestination = selection?.rawValue
    }
}
