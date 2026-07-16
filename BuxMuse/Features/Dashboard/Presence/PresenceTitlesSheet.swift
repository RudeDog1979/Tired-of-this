//
//  PresenceTitlesSheet.swift
//  BuxMuse
//
//  Lifetime Vault Titles gallery.
//

import SwiftUI

struct PresenceTitlesSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var presence = BuxPresenceStreakStore.shared

    var body: some View {
        NavigationStack {
            PresenceTitlesGallery()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .background(BuxLandingTintBackground().ignoresSafeArea())
                .buxCatalogNavigationTitle("Vault Titles")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            presence.dismissTitlesSheet()
                            dismiss()
                        } label: {
                            BuxCatalogDynamicText(key: "Done")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
        }
    }
}

struct PresenceTitlesGallery: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var presence = BuxPresenceStreakStore.shared

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }
    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogDynamicText(key: "Titles for days you opened BuxMuse")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(streakSummary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accent)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(BuxPresenceTitleID.allCases.sorted().reversed()) { title in
                        titleTile(title)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private var streakSummary: String {
        BuxLocalizedString.format(
            "Streak %lld · Best %lld",
            locale: locale,
            Int64(presence.currentLength),
            Int64(presence.bestLength)
        )
    }

    private func titleTile(_ title: BuxPresenceTitleID) -> some View {
        let unlocked = presence.isUnlocked(title)

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(unlocked ? accent.opacity(0.16) : Color.primary.opacity(0.05))
                    .frame(width: 52, height: 52)
                Text(title.emoji)
                    .font(.system(size: 26))
                    .opacity(unlocked ? 1 : 0.35)
            }

            VStack(spacing: 4) {
                Text(BuxCatalogLabel.string(title.titleKey, locale: locale))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(
                        unlocked
                            ? themeManager.labelPrimary(for: colorScheme)
                            : themeManager.labelSecondary(for: colorScheme)
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(subtitle(for: title, unlocked: unlocked))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(
                        unlocked ? accent : themeManager.labelSecondary(for: colorScheme).opacity(0.75)
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(themeManager.cardFill(for: colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    unlocked ? accent.opacity(0.28) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        }
    }

    private func subtitle(for title: BuxPresenceTitleID, unlocked: Bool) -> String {
        if unlocked {
            if let date = presence.unlockDate(for: title) {
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.setLocalizedDateFormatFromTemplate("MMM d")
                let day = formatter.string(from: date)
                return BuxLocalizedString.format("Earned %@", locale: locale, day)
            }
            return BuxCatalogLabel.string("Earned", locale: locale)
        }
        if let hint = presence.progressHint(for: title) {
            return hint
        }
        return BuxCatalogLabel.string(title.criterionSummaryKey, locale: locale)
    }
}
