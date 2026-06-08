//
//  PaymentSourceSettingsView.swift
//  BuxMuse
//
//  Optional payment provider tagging for spending insights.
//

import SwiftUI

struct PaymentSourceSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        BuxThemedCardForm {
            BuxFormSection(title: "Payment source tracking") {
                Toggle(isOn: $store.paymentSourceTrackingEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        BuxCatalogDynamicText(key: "Enable on add expense")
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogDynamicText(key: "Optional searchable tags (Visa, PayPal, Klarna, etc.) power credit and BNPL insights. Off by default — simple logging stays clean.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(themeManager.current.accentColor)
                .buxFormFieldPadding()
            }

            if store.paymentSourceTrackingEnabled {
                BuxFormSection(title: "Supported providers") {
                    VStack(alignment: .leading, spacing: 10) {
                        BuxCatalogDynamicText(key: "Tag expenses with the provider you used. BuxMuse uses this locally to surface credit-heavy months and active buy-now-pay-later plans.")
                            .font(.system(size: 12, weight: .medium))
                            .buxLabelSecondary()
                            .fixedSize(horizontal: false, vertical: true)

                        FlowLayout(spacing: 8) {
                            ForEach(PaymentSourceCatalog.all.prefix(12)) { option in
                                Text(option.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(themeManager.current.accentColor.opacity(0.1))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .buxFormFieldPadding()
                }
                .transaction { $0.animation = nil }
            }
        }
        .buxCatalogNavigationTitle("Payment sources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Simple wrapping layout for provider chips (iOS 18+ compatible).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
