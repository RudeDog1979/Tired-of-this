//
//  EmotionalTagPickerView.swift
//  BuxMuse
//
//  Horizontal emotional tag chips for add/edit expense.
//

import SwiftUI

struct EmotionalTagPickerView: View {
    @Binding var selection: String

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(EmotionalTaggingEngine.selectableTags) { tag in
                    chip(for: tag)
                }
            }
            .padding(.vertical, 4)
        }
        .buxHorizontalScrollEdgeFade(background: themeManager.cardFill(for: colorScheme))
    }

    private func chip(for tag: EmotionalTag) -> some View {
        let isSelected = selection == tag.id
        let palette = EmotionalTagAppearance.palette(for: tag.id, colorScheme: colorScheme)
        let accent = palette?.accent ?? themeManager.current.accentColor

        return Button {
            withAnimation(isSelected ? BuxMotion.emotionFadeOut : BuxMotion.emotionFadeIn) {
                selection = isSelected ? "" : tag.id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tag.symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(tag.localizedLabel(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? chipForeground(accent: accent) : themeManager.pillInactiveLabelColor(for: colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(
                        isSelected
                            ? accent.opacity(colorScheme == .dark ? 0.28 : 0.16)
                            : themeManager.pillTrackFill(for: colorScheme)
                    )
            }
            .overlay {
                Capsule()
                    .stroke(
                        isSelected ? accent.opacity(colorScheme == .dark ? 0.55 : 0.4) : themeManager.subtleCardStroke(for: colorScheme),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(BuxMicroShrinkStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func chipForeground(accent: Color) -> Color {
        colorScheme == .dark ? .white : accent.opacity(0.92)
    }
}
