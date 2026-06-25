//
//  BuxThemePickerCarousel.swift
//  BuxMuse
//
//  Horizontal editorial theme carousel + live preview strip.
//  iOS 26 scroll alignment when available; iOS 18 horizontal ScrollView fallback.
//

import SwiftUI

// MARK: - Horizontal snap (iOS 17+; no-op on iOS 18 baseline path)

struct BuxHorizontalSnapScrollModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollTargetBehavior(.viewAligned)
        } else {
            content
        }
    }
}

/// Lets scaled theme cards and shadows paint outside the scroll viewport (iOS 17+).
struct BuxCarouselScrollClipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollClipDisabled()
        } else {
            content
        }
    }
}

// MARK: - Layout style (additive — grid path preserved on ThemeSwatchCard)

enum ThemeSwatchCardLayout {
    case grid
    case carousel
}

// MARK: - Swatch surface (carousel avoids clipShape so scale/shadow can breathe)

struct ThemeSwatchCardChromeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let layout: ThemeSwatchCardLayout
    let cornerRadius: CGFloat
    let isSelected: Bool
    let accentColor: Color

    func body(content: Content) -> some View {
        switch layout {
        case .carousel:
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .background {
                    shape.fill(themeManager.cardFill(for: colorScheme))
                }
                .overlay {
                    shape.strokeBorder(
                        isSelected ? accentColor : themeManager.themedCardStroke(for: colorScheme),
                        lineWidth: isSelected ? 2 : 0.5
                    )
                }
                .shadow(
                    color: isSelected ? accentColor.opacity(0.22) : Color.black.opacity(0.05),
                    radius: isSelected ? 14 : 6,
                    x: 0,
                    y: isSelected ? 6 : 3
                )
        case .grid:
            content
                .settingsThemedCardChrome(cornerRadius: cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
                )
                .shadow(
                    color: isSelected ? accentColor.opacity(0.2) : Color.black.opacity(0.04),
                    radius: isSelected ? 12 : 6,
                    x: 0,
                    y: 4
                )
        }
    }
}

// MARK: - Live preview strip

struct BuxThemePreviewStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "Active preset")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .buxLabelSecondary()
                .padding(.horizontal, BuxLayout.section)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark ? theme.heroDarkGradient : theme.heroLightGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(theme.accentColor.opacity(0.45), lineWidth: 1)
                    }
                    .shadow(color: theme.accentColor.opacity(0.25), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.localizedName(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(theme.accentColor)
                            .frame(width: 10, height: 10)
                        BuxCatalogDynamicText(key: "Accent & hero surfaces")
                            .font(.system(size: 11, weight: .medium))
                            .buxLabelSecondary()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, BuxLayout.section)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 8)
        .buxStableThemeLayout(themeId: themeManager.current.id)
    }
}

// MARK: - Brand theme carousel

struct BuxThemePickerCarousel: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BuxThemePreviewStrip(theme: themeManager.current)

            carouselScroll
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var carouselScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(AppTheme.all) { theme in
                    ThemeSwatchCard(
                        theme: theme,
                        isSelected: themeManager.current.id == theme.id,
                        layout: .carousel,
                        onTap: {
                            store.persistThemeSelection(theme, themeManager: themeManager)
                        }
                    )
                    .containerRelativeFrame(.horizontal, count: 5, span: 2, spacing: 14)
                    .frame(minWidth: 148, idealWidth: 168, maxWidth: 196)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 14)
        }
        .buxViewAlignedHorizontalCarousel()
    }
}

// MARK: - Neutral accent carousel

struct BuxAccentPickerCarousel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuxCatalogDynamicText(key: "Neutral Apple surfaces with your chosen accent on buttons and controls.")
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, BuxLayout.section)
                .padding(.top, 4)

            let scroll = ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(BuxSystemAccent.allCases) { accent in
                        AccentSwatchCard(
                            accent: accent,
                            isSelected: store.neutralAccentId == accent.rawValue,
                            layout: .carousel
                        ) {
                            store.neutralAccentId = accent.rawValue
                            store.save()
                        }
                        .frame(width: 88)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, BuxLayout.section)
                .padding(.vertical, 8)
            }

            scroll
                .modifier(BuxHorizontalSnapScrollModifier())
                .buxPadViewAlignedHorizontalCarousel()
        }
    }
}

// MARK: - Accent swatch (shared — grid + carousel)

struct AccentSwatchCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let accent: BuxSystemAccent
    let isSelected: Bool
    var layout: ThemeSwatchCardLayout = .grid
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: layout == .carousel ? 8 : 6) {
                ZStack {
                    Circle()
                        .fill(accent.color(for: colorScheme))
                        .frame(width: layout == .carousel ? 48 : 44, height: layout == .carousel ? 48 : 44)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2.5)
                            .frame(width: layout == .carousel ? 48 : 44, height: layout == .carousel ? 48 : 44)
                        Image(systemName: "checkmark")
                            .font(.system(size: layout == .carousel ? 15 : 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(accent.localizedDisplayName(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: layout == .carousel ? 11 : 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected
                        ? themeManager.labelPrimary(for: colorScheme)
                        : themeManager.labelSecondary(for: colorScheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, layout == .carousel ? 12 : 8)
            .settingsThemedCardChrome(cornerRadius: layout == .carousel ? 18 : 14)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: layout == .carousel ? 18 : 14, style: .continuous)
                        .stroke(accent.color(for: colorScheme), lineWidth: 2)
                }
            }
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }
}
