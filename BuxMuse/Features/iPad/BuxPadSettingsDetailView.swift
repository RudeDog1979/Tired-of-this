//
//  BuxPadSettingsDetailView.swift
//  BuxMuse — Settings drill-in detail column (composes existing settings views).
//

import SwiftUI

struct BuxPadSettingsDetailView: View {
    let destination: SettingsDestinationType

    var body: some View {
        BuxPadSettingsDrillInBackdrop {
            Group {
                switch destination {
                case .profile:
                    ProfileSettingsView()
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
                case .paymentSources:
                    PaymentSourceSettingsView()
                }
            }
            .padding(.top, BuxTokens.tight)
            .buxPadDashboardCardRail()
        }
        .modifier(SettingsPadSplitScrollChromeModifier())
        .buxInterfaceLocale()
        .environment(\.settingsEnhancedTint, true)
    }
}

private struct BuxPadSettingsDrillInBackdrop<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxPadSettingsUsesSplitLayout) private var usesPadSplitLayout
    @EnvironmentObject private var themeManager: ThemeManager
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()

            content()
        }
        .modifier(BuxPadSettingsDrillInChromeModifier())
        .environment(\.isSettingsContext, true)
    }
}

private struct BuxPadSettingsDrillInChromeModifier: ViewModifier {
    @Environment(\.buxPadSettingsUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
        } else {
            content.buxPushedNavigationChrome()
        }
    }
}
