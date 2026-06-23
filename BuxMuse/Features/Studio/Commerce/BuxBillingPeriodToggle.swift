//
//  BuxBillingPeriodToggle.swift
//  BuxMuse — Monthly / Yearly billing picker for subscriptions.
//

import SwiftUI

struct BuxBillingPeriodToggle: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var billingPeriod: BuxMuseBillingPeriod
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let caption {
                Text(BuxCatalogLabel.string(caption, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 11, weight: .medium))
                    .buxLabelSecondary()
            }

            BuxSegmentedCapsuleSelector(leadingSelected: billingPeriod == .monthly) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        billingPeriod = .monthly
                    }
                } label: {
                    BuxSegmentedCapsuleSegment(
                        title: BuxCatalogLabel.string("Monthly", locale: appSettingsManager.interfaceLocale),
                        isSelected: billingPeriod == .monthly
                    )
                }
                .buttonStyle(.plain)
            } trailing: {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        billingPeriod = .yearly
                    }
                } label: {
                    BuxSegmentedCapsuleSegment(
                        title: BuxCatalogLabel.string("Yearly", locale: appSettingsManager.interfaceLocale),
                        isSelected: billingPeriod == .yearly
                    )
                }
                .buttonStyle(.plain)
            }
            .environmentObject(themeManager)
        }
    }
}
