//
//  PresencePopupView.swift
//  BuxMuse
//
//  Once-daily presence celebration — TipPopup-quality motion.
//

import SwiftUI

struct PresencePopupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var presence = BuxPresenceStreakStore.shared
    @ObservedObject private var settings = SettingsStore.shared

    let onContinue: () -> Void
    let onViewTitles: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.9
    @State private var cardOpacity: Double = 0
    @State private var cardOffsetY: CGFloat = 28
    @State private var contentOpacity: Double = 0
    @State private var contentOffsetY: CGFloat = 10
    @State private var isDismissing = false

    private var accent: Color { themeManager.contrastAccentColor(for: colorScheme) }
    private var newTitle: BuxPresenceTitleID? { presence.newlyUnlockedTitleIDs.max() }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture { dismiss(continueFlow: true) }

            VStack {
                Spacer(minLength: 24)
                card
                    .padding(.horizontal, 22)
                Spacer(minLength: 24)
            }
        }
        .onAppear(perform: playEntrance)
    }

    private var card: some View {
        VStack(spacing: 18) {
            BuxCatalogDynamicText(key: "PRESENCE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                .kerning(1.4)

            PresenceWeekRing(filledCount: presence.weekDayIndex)
                .environmentObject(themeManager)
                .padding(.top, 4)

            VStack(spacing: 8) {
                Text(dayTitle)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                BuxCatalogDynamicText(key: "You showed up for your money today.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if presence.bestLength > 0 {
                    Text(bestTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme).opacity(0.9))
                }
            }
            .opacity(contentOpacity)
            .offset(y: contentOffsetY)

            if let newTitle {
                HStack(spacing: 8) {
                    Text(newTitle.emoji)
                        .font(.system(size: 16))
                    Text(newTitleLabel(newTitle))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background {
                    Capsule(style: .continuous)
                        .fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.1))
                }
                .opacity(contentOpacity)
            }

            VStack(spacing: 12) {
                Button(action: { dismiss(continueFlow: true) }) {
                    BuxCatalogDynamicText(key: "Continue")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Capsule(style: .continuous).fill(accent))
                }
                .buttonStyle(BuxPressFeedbackStyle())

                Button(action: { dismiss(continueFlow: false) }) {
                    BuxCatalogDynamicText(key: "View titles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
            .opacity(contentOpacity)
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .frame(maxWidth: 380)
        .background { cardBackground }
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .offset(y: cardOffsetY)
    }

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Group {
            if settings.useGlassmorphism {
                shape.fill(.ultraThinMaterial)
            } else {
                shape.fill(themeManager.cardFill(for: colorScheme))
            }
        }
        .overlay {
            shape.stroke(
                colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.07),
                lineWidth: 0.8
            )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 24, y: 12)
    }

    private var dayTitle: String {
        BuxLocalizedString.format(
            "Day %lld of 7",
            locale: appSettingsManager.interfaceLocale,
            Int64(presence.weekDayIndex)
        )
    }

    private var bestTitle: String {
        BuxLocalizedString.format(
            "Best streak · %lld days",
            locale: appSettingsManager.interfaceLocale,
            Int64(presence.bestLength)
        )
    }

    private func newTitleLabel(_ title: BuxPresenceTitleID) -> String {
        let name = BuxCatalogLabel.string(title.titleKey, locale: appSettingsManager.interfaceLocale)
        return BuxLocalizedString.format(
            "New title: %@",
            locale: appSettingsManager.interfaceLocale,
            name
        )
    }

    private func playEntrance() {
        withAnimation(BuxMotion.tipPopupPresent) {
            backdropOpacity = 1
            cardScale = 1
            cardOpacity = 1
            cardOffsetY = 0
        }
        withAnimation(BuxMotion.tipPopupPresent.delay(0.12)) {
            contentOpacity = 1
            contentOffsetY = 0
        }
    }

    private func dismiss(continueFlow: Bool) {
        guard !isDismissing else { return }
        isDismissing = true
        withAnimation(.easeIn(duration: 0.2)) {
            backdropOpacity = 0
            cardOpacity = 0
            cardScale = 0.94
            cardOffsetY = 16
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            presence.markDailyPopupShown()
            if continueFlow {
                onContinue()
            } else {
                onViewTitles()
            }
        }
    }
}
