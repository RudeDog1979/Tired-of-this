//
//  TaxSavingsHubHeroSection.swift
//  BuxMuse
//

import SwiftUI

struct TaxSavingsHubHeroSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var taxEnvelopeBrain: TaxEnvelopeBrain

    var onOpenTaxSavings: () -> Void

    private var hero: TaxSavingsHubHeroDisplay { taxEnvelopeBrain.display.hubHero }

    var body: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxSectionHeader(title: "Tax savings")

            BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.card, padding: BuxTokens.section) {
                VStack(alignment: .leading, spacing: BuxTokens.section) {
                    Text(hero.weekSetAsideLine)
                        .font(.system(size: 17, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(hero.yearProgressLine)
                        .font(.system(size: 14, weight: .semibold))
                        .buxLabelSecondary()

                    Text(hero.disclaimer)
                        .font(.system(size: 11, weight: .medium))
                        .buxLabelSecondary()
                        .fixedSize(horizontal: false, vertical: true)

                    BuxButton(
                        title: hero.needsSetup ? "Set up tax savings" : "Tax savings",
                        systemImage: "banknote",
                        role: .primary,
                        expands: true,
                        action: onOpenTaxSavings
                    )
                }
            }
        }
    }
}
