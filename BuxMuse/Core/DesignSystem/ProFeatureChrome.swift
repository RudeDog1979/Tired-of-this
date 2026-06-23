//
//  ProFeatureChrome.swift
//  BuxMuse
//
//  Shared Pro Studio badge, headers, and feature-gate helpers.
//

import SwiftUI

// MARK: - Feature gate

enum StudioFeatureGate {
    static var isPro: Bool { StudioPurchaseManager.shared.hasProStudio }

    static var hasSimpleStudio: Bool { StudioPurchaseManager.shared.hasSimpleStudio }

    static func requiresPro(for destination: SettingsDestinationType) -> Bool {
        switch destination {
        case .scopeCreepRadar, .agreementScratchpad:
            return true
        default:
            return false
        }
    }

    static func upsellFeature(for destination: SettingsDestinationType) -> StudioProUpsellSheet.Feature? {
        switch destination {
        case .scopeCreepRadar: return .scopeCreepRadar
        case .agreementScratchpad: return .agreementScratchpad
        default: return nil
        }
    }
}

// MARK: - PRO badge

struct ProFeatureBadge: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var compact: Bool = true

    var body: some View {
        Text("PRO")
            .font(.system(size: compact ? 9 : 10, weight: .heavy, design: .rounded))
            .tracking(compact ? 1.0 : 1.4)
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                LinearGradient(
                    colors: [
                        themeManager.current.accentColor,
                        themeManager.current.accentColor.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .accessibilityLabel("Pro Studio feature")
    }
}

// MARK: - Settings / drill-in header

struct ProFeatureHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(tint ?? themeManager.contrastAccentColor(for: colorScheme))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    BuxCatalogText.text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    ProFeatureBadge(compact: true)
                }
                BuxCatalogText.text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(BuxLayout.section)
        .buxFormSectionCard()
    }
}
