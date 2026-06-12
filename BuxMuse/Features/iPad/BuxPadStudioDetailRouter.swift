//
//  BuxPadStudioDetailRouter.swift
//  BuxMuse — Maps studio sidebar selection → existing Pro Studio views.
//

import SwiftUI

struct BuxPadStudioDetailRouter: View {
    let destination: BuxPadStudioDestination

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

    var body: some View {
        Group {
            switch destination {
            case .commandCenter:
                NavigationStack {
                    StudioHubView()
                        .environmentObject(navigationCoordinator)
                        .environmentObject(financialBridge)
                        .environmentObject(simpleStudioBrain)
                        .environment(\.buxPadStudioUsesSplitLayout, true)
                }

            case .invoices:
                studioTool {
                    StudioInvoicesListView()
                        .buxPadStudioDropDestination(destination: .invoices)
                }

            case .clients:
                studioTool { StudioClientsListView() }

            case .projects:
                studioTool {
                    StudioProjectsListView()
                        .environmentObject(simpleStudioStore)
                }

            case .receipts:
                studioTool {
                    StudioReceiptsListView()
                        .buxPadStudioDropDestination(destination: .receipts)
                }

            case .taxStudio:
                studioTool {
                    TaxStudioHubView(initialTab: .overview)
                        .environmentObject(appDataManager)
                        .environmentObject(studioBrain)
                        .environmentObject(taxEnvelopeBrain)
                }

            case .taxSavings:
                studioTool {
                    TaxEnvelopeRootView()
                        .environmentObject(studioBrain)
                        .environmentObject(taxEnvelopeBrain)
                        .environmentObject(appDataManager)
                }

            case .cashflow:
                studioTool { StudioCashflowView() }

            case .deductions:
                studioTool {
                    StudioDeductionsView()
                        .environmentObject(studioBrain)
                }

            case .mileage:
                studioTool {
                    StudioMileageLogView()
                        .environmentObject(studioBrain)
                }

            case .agreements:
                studioTool {
                    AgreementScratchpadListView()
                        .environmentObject(simpleStudioStore)
                }

            case .insights:
                studioTool {
                    StudioInsightsDashboardView()
                        .environmentObject(simpleStudioStore)
                }

            case .businessCard:
                studioTool {
                    BuxPadBusinessCardHost()
                        .environmentObject(studioStore)
                        .environmentObject(simpleStudioStore)
                }

            case .invoiceArchive:
                studioTool {
                    StudioInvoiceArchiveView()
                        .environmentObject(simpleStudioStore)
                }

            case .businessProfile:
                studioTool { StudioProfileView() }

            case .proSearch:
                studioTool {
                    ProStudioSearchView()
                        .environmentObject(simpleStudioStore)
                        .environmentObject(studioBrain)
                }
            }
        }
        .environment(\.studioEnhancedTint, true)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func studioTool<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .buxCatalogNavigationTitle(destination.title)
                .navigationBarTitleDisplayMode(.large)
                .buxPushedNavigationChrome()
        }
    }
}
