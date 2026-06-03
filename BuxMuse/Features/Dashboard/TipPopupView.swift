//
//  TipPopupView.swift
//  BuxMuse
//

import SwiftUI

struct TipPopupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let tip: DailyTipDisplay
    let onDismiss: () -> Void

    @State private var backdropOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.84
    @State private var cardOpacity: Double = 0
    @State private var cardOffsetY: CGFloat = 36
    @State private var heroScale: CGFloat = 0.55
    @State private var heroRotation: Double = -14
    @State private var glowPulse: CGFloat = 1.0
    @State private var contentOpacity: Double = 0
    @State private var contentOffsetY: CGFloat = 12
    @State private var isDismissing = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }

            VStack(spacing: 0) {
                Spacer(minLength: 32)

                VStack(alignment: .center, spacing: 0) {

                    // 1. Centered Pulsating Lightbulb Hero
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.14))
                            .frame(width: 72, height: 72)

                        Circle()
                            .stroke(Color.yellow.opacity(0.28), lineWidth: 1.5)
                            .frame(width: 86, height: 86)
                            .scaleEffect(glowPulse)

                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .scaleEffect(heroScale)
                            .rotationEffect(.degrees(heroRotation))
                            .shadow(color: .yellow.opacity(0.4), radius: 10)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                    // 2. Centered Typography + scroll + CTA — staggered after card lands
                    VStack(spacing: 0) {
                        VStack(spacing: 4) {
                            BuxCatalogDynamicText(key: "Daily tips")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .kerning(1.2)
                                .textCase(.uppercase)

                            Text(
                                BuxLocalizedString.format(
                                    "%@ %@",
                                    locale: appSettingsManager.interfaceLocale,
                                    tip.regionFlag,
                                    tip.regionCode
                                )
                            )
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? .white : .primary)

                            Text(tip.dateLabel)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 18)

                        Divider().opacity(0.12)

                        ScrollView(showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 16) {
                                tipSectionCard(tip.moneyTip, isPrimary: true)

                                if !tip.watchOut.isEmpty {
                                    watchOutHeader

                                    ForEach(tip.watchOut) { section in
                                        tipSectionCard(section, isPrimary: false)
                                    }
                                }
                            }
                            .padding(.horizontal, BuxTokens.marginRegular)
                            .padding(.vertical, 18)
                        }
                        .frame(maxHeight: 320)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black, location: 0.08),
                                    .init(color: .black, location: 0.92),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        BuxButton(
                            title: "Got it",
                            systemImage: "checkmark",
                            role: .primary,
                            expands: true
                        ) {
                            dismissWithAnimation()
                        }
                        .padding(.horizontal, BuxTokens.marginRegular)
                        .padding(.top, BuxTokens.tight)
                        .padding(.bottom, BuxTokens.section)
                    }
                    .opacity(contentOpacity)
                    .offset(y: contentOffsetY)
                }
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(
                                    colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 24, x: 0, y: 12)
                }
                .padding(.horizontal, BuxTokens.marginRegular)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)
                .offset(y: cardOffsetY)

                Spacer(minLength: 48)
            }
        }
        .onAppear(perform: playEntrance)
    }

    private func playEntrance() {
        withAnimation(BuxMotion.tipPopupPresent) {
            backdropOpacity = 1
            cardScale = 1
            cardOpacity = 1
            cardOffsetY = 0
            heroScale = 1
            heroRotation = 0
        }

        withAnimation(BuxMotion.tipPopupPresent.delay(0.12)) {
            contentOpacity = 1
            contentOffsetY = 0
        }

        withAnimation(.easeInOut(duration: 0.42).repeatCount(3, autoreverses: true).delay(0.38)) {
            glowPulse = 1.14
        }
    }

    private var watchOutHeader: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.orange.opacity(0.35))
                .frame(height: 1)
            Text(tip.watchOutHeader)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.orange)
                .kerning(1.0)
                .multilineTextAlignment(.center)
                .layoutPriority(1)
            Rectangle()
                .fill(Color.orange.opacity(0.35))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func tipSectionCard(_ section: DailyTipSection, isPrimary: Bool) -> some View {
        let accent = accentColor(for: section.kind)
        let fill = accent.opacity(colorScheme == .dark ? 0.12 : 0.08)
        let stroke = accent.opacity(isPrimary ? 0.45 : 0.28)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: section.kind.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)

                Text(section.kind.badgeLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                    .kerning(0.8)

                Spacer(minLength: 0)
            }

            BuxCatalogDynamicText(key: section.title)
                .font(.system(size: isPrimary ? 20 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            BuxCatalogDynamicText(key: section.body)
                .font(.system(size: isPrimary ? 16 : 14, weight: .regular))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.82) : Color(red: 55/255, green: 60/255, blue: 70/255))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(stroke, lineWidth: isPrimary ? 1.5 : 1)
        )
    }

    private func accentColor(for kind: DailyTipKind) -> Color {
        switch kind {
        case .moneyTip: return .yellow
        case .scam: return .orange
        case .security: return Color(red: 0.25, green: 0.55, blue: 0.95)
        }
    }

    private func dismissWithAnimation() {
        guard !isDismissing else { return }
        isDismissing = true

        withAnimation(BuxMotion.tipPopupDismiss) {
            backdropOpacity = 0
            cardScale = 0.9
            cardOffsetY = 18
            cardOpacity = 0
            heroScale = 0.85
            contentOpacity = 0
            contentOffsetY = 8
            glowPulse = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            onDismiss()
        }
    }
}
