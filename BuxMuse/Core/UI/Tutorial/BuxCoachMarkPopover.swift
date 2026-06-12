//
//  BuxCoachMarkPopover.swift
//  BuxMuse
//

import SwiftUI

struct BuxCoachMarkPopover: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Environment(\.colorScheme) private var colorScheme

    let progressLabel: String
    let titleKey: String
    let bodyKey: String
    let primaryButtonKey: String
    let showsSkip: Bool
    let onPrimary: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(progressLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                .textCase(.uppercase)

            BuxCatalogText.text(titleKey)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))

            BuxCatalogText.text(bodyKey)
                .font(.system(size: 13))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onPrimary) {
                BuxCatalogText.text(primaryButtonKey)
                    .frame(maxWidth: .infinity)
            }
            .buxPrimaryPillStyle(accent: themeManager.contrastAccentColor(for: colorScheme))

            if showsSkip {
                Button(action: onSkip) {
                    BuxCatalogText.text("Skip tour")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
