//
//  BuxPadSimpleStudioDetailRouter.swift
//  BuxMuse — Maps Simple Studio sidebar selection → existing Simple Studio views.
//

import SwiftUI

struct BuxPadSimpleStudioDetailRouter: View {
    let destination: BuxPadSimpleStudioDestination

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var studioBrain: StudioBrain
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var simpleStudioBrain: SimpleStudioBrain
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain
    @EnvironmentObject private var appDataManager: AppDataManager

    var body: some View {
        Group {
            switch destination {
            case .home:
                NavigationStack {
                    SimpleStudioHubView()
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(studioStore)
                        .environmentObject(studioBrain)
                        .environmentObject(simpleStudioStore)
                        .environmentObject(simpleStudioBrain)
                        .environmentObject(taxEnvelopeBrain)
                        .environmentObject(appDataManager)
                        .environmentObject(navigationCoordinator)
                        .environment(\.buxPadStudioUsesSplitLayout, true)
                }
                .background(Color.clear)

            case .myMoney:
                simpleTool {
                    SimpleStudioMyMoneyView(
                        store: simpleStudioStore,
                        display: simpleStudioBrain.myMoneyDisplay
                    )
                    .environmentObject(studioStore)
                }

            case .people:
                simpleTool {
                    SimpleStudioPeopleView(store: simpleStudioStore)
                }

            case .search:
                simpleTool {
                    SimpleStudioSearchView(store: simpleStudioStore, isProSearch: false)
                        .environmentObject(studioStore)
                }

            case .workClock:
                simpleTool {
                    SimpleStudioLogTimeView()
                        .environmentObject(simpleStudioStore)
                        .environmentObject(studioStore)
                }

            case .mileage:
                simpleTool {
                    StudioMileageLogView()
                        .environmentObject(studioBrain)
                        .environment(\.studioEnhancedTint, true)
                }

            case .invoiceArchive:
                simpleTool {
                    StudioInvoiceArchiveView()
                        .environmentObject(simpleStudioStore)
                }

            case .taxSavings:
                simpleTool {
                    TaxEnvelopeRootView()
                        .environmentObject(studioBrain)
                        .environmentObject(taxEnvelopeBrain)
                        .environmentObject(appDataManager)
                }

            case .businessCard:
                simpleTool {
                    SimpleStudioBusinessCardSheet(store: simpleStudioStore)
                        .environmentObject(studioStore)
                }
            }
        }
        .environment(\.studioEnhancedTint, true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buxReportsContainerWidth()
    }

    @ViewBuilder
    private func simpleTool<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .padding(.top, BuxTokens.tight)
                .buxPadStudioToolShell(titleKey: destination.title)
        }
        .background(Color.clear)
    }
}
