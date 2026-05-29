//
//  TipPopupView.swift
//  BuxMuse
//

import SwiftUI

struct TipPopupView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let tip: DailyTipDisplay
    let onDismiss: () -> Void

    @State private var cardScale: CGFloat = 0.92
    @State private var cardOpacity: Double = 0

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }

            VStack(spacing: 0) {
                Spacer(minLength: 32)

                VStack(alignment: .leading, spacing: 0) {
                    headerRow

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
                    .frame(maxHeight: 360)

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

                Spacer(minLength: 48)
            }
        }
        .onAppear {
            withAnimation(BuxMotion.bounce) {
                cardScale = 1
                cardOpacity = 1
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Daily tips")
                    .buxSectionLabelStyle(color: .secondary)
                Text("\(tip.regionFlag) \(tip.regionCode)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
            }

            Spacer()

            Text(tip.dateLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var watchOutHeader: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.orange.opacity(0.35))
                .frame(height: 1)
            Text(tip.watchOutHeader)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.orange)
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

                Text(section.kind.badgeLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(accent)

                Spacer(minLength: 0)
            }

            Text(section.title)
                .font(.system(size: isPrimary ? 20 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text(section.body)
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
        withAnimation(.easeOut(duration: 0.22)) {
            cardScale = 0.94
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }
}
