//
//  TipPopupView.swift
//  BuxMuse
//

import SwiftUI

struct TipPopupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var settings = SettingsStore.shared

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

    private var isPad: Bool { BuxPadIdiom.isPad }

    var body: some View {
        ZStack {
            Group {
                if isPad {
                    Color.black.opacity(0.16)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            }
            .opacity(backdropOpacity)
            .ignoresSafeArea()
            .onTapGesture { dismissWithAnimation() }

            if isPad {
                padPopupCard
            } else {
                phonePopupCard
            }
        }
        .onAppear(perform: playEntrance)
    }

    // MARK: - iPad — compact liquid glass card

    private var padPopupCard: some View {
        VStack(spacing: 0) {
            padHero
                .padding(.top, 14)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                padHeader
                    .padding(.bottom, 12)

                Divider().opacity(0.1)

                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        tipSectionCard(tip.moneyTip, isPrimary: true, compact: true)

                        if !tip.watchOut.isEmpty {
                            watchOutHeader
                            ForEach(tip.watchOut) { section in
                                tipSectionCard(section, isPrimary: false, compact: true)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: 168)
                .scrollBounceBehavior(.always)
                .scrollIndicators(.visible)

                BuxButton(
                    title: "Got it",
                    systemImage: "checkmark",
                    role: .primary,
                    expands: true
                ) {
                    dismissWithAnimation()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .opacity(contentOpacity)
            .offset(y: contentOffsetY)
        }
        .frame(maxWidth: 380)
        .background { padGlassCardBackground }
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .offset(y: cardOffsetY)
    }

    private var padHero: some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.12))
                .frame(width: 48, height: 48)

            Circle()
                .stroke(Color.yellow.opacity(0.24), lineWidth: 1)
                .frame(width: 56, height: 56)
                .scaleEffect(glowPulse)

            Image(systemName: "lightbulb.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.yellow)
                .scaleEffect(heroScale)
                .rotationEffect(.degrees(heroRotation))
        }
    }

    private var padHeader: some View {
        VStack(spacing: 3) {
            BuxCatalogDynamicText(key: "Daily tips")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .kerning(1.1)
                .textCase(.uppercase)

            Text(
                BuxLocalizedString.format(
                    "%@ %@",
                    locale: appSettingsManager.interfaceLocale,
                    tip.regionFlag,
                    tip.regionCode
                )
            )
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            Text(tip.dateLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var padGlassCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Group {
            if settings.useGlassmorphism, BuxPlatform.supportsLiquidGlass, #available(iOS 26.0, *) {
                GlassEffectContainer {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                }
            } else if settings.useGlassmorphism {
                shape.fill(.ultraThinMaterial)
                    .buxMaterialColorSchemeAdaptive(shape: shape, colorScheme: colorScheme)
            } else {
                shape.fill(.regularMaterial)
                    .buxMaterialColorSchemeAdaptive(shape: shape, colorScheme: colorScheme)
            }
        }
        .overlay {
            shape.stroke(
                colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08),
                lineWidth: 0.75
            )
        }
        .buxGlassRimShimmer(
            shape: shape,
            colorScheme: colorScheme,
            enabled: settings.useGlassmorphism && !settings.solarContrastModeEnabled
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.1), radius: 18, y: 8)
    }

    // MARK: - iPhone — unchanged layout

    private var phonePopupCard: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            VStack(alignment: .center, spacing: 0) {
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

    private func playEntrance() {
        if isPad {
            cardOffsetY = 20
            heroScale = 0.7
        }

        withAnimation(isPad ? .spring(response: 0.44, dampingFraction: 0.82) : BuxMotion.tipPopupPresent) {
            backdropOpacity = 1
            cardScale = 1
            cardOpacity = 1
            cardOffsetY = 0
            heroScale = 1
            heroRotation = 0
        }

        withAnimation((isPad ? .spring(response: 0.4, dampingFraction: 0.86) : BuxMotion.tipPopupPresent).delay(0.1)) {
            contentOpacity = 1
            contentOffsetY = 0
        }

        withAnimation(.easeInOut(duration: 0.42).repeatCount(isPad ? 2 : 3, autoreverses: true).delay(0.32)) {
            glowPulse = isPad ? 1.08 : 1.14
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
    private func tipSectionCard(_ section: DailyTipSection, isPrimary: Bool, compact: Bool = false) -> some View {
        let accent = accentColor(for: section.kind)
        let fill = accent.opacity(colorScheme == .dark ? 0.12 : 0.08)
        let stroke = accent.opacity(isPrimary ? 0.45 : 0.28)
        let titleSize: CGFloat = compact ? (isPrimary ? 16 : 14) : (isPrimary ? 20 : 16)
        let bodySize: CGFloat = compact ? (isPrimary ? 14 : 13) : (isPrimary ? 16 : 14)
        let padding: CGFloat = compact ? 12 : 16

        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 8) {
                Image(systemName: section.kind.systemImage)
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .foregroundStyle(accent)

                Text(section.kind.badgeLabel.uppercased())
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
                    .foregroundStyle(accent)
                    .kerning(0.8)

                Spacer(minLength: 0)
            }

            BuxCatalogDynamicText(key: section.title)
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            BuxCatalogDynamicText(key: section.body)
                .font(.system(size: bodySize, weight: .regular))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.82) : Color(red: 55/255, green: 60/255, blue: 70/255))
                .lineSpacing(compact ? 3 : 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
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

        withAnimation(isPad ? .spring(response: 0.34, dampingFraction: 0.88) : BuxMotion.tipPopupDismiss) {
            backdropOpacity = 0
            cardScale = isPad ? 0.94 : 0.9
            cardOffsetY = isPad ? 12 : 18
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
