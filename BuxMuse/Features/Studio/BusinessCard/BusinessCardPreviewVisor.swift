//
//  BusinessCardPreviewVisor.swift
//  BuxMuse
//
//  Cinema-style preview frame shared by Card Studio and Bux Canvas.
//

import SwiftUI

struct BusinessCardPreviewVisor<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                            themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.16),
                            lineWidth: 1
                        )
                }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(colorScheme == .dark ? 0.28 : 0.035))
                .padding(6)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05), lineWidth: 0.5)
                        .padding(6)
                }

            content()
                .padding(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(color: themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.07), radius: 8, y: 3)
    }
}

extension View {
    /// Style only — apply `.tint(accent)` on the parent HStack (Explore SwiftUI Button Tint pattern).
    func businessCardPreviewActionButtonStyle() -> some View {
        self
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    func businessCardThemedPill(
        themeManager: ThemeManager,
        colorScheme: ColorScheme
    ) -> some View {
        self
            .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.08),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(themeManager.current.accentColor.opacity(0.14), lineWidth: 0.5)
            }
    }

    func businessCardThemedChip(
        isSelected: Bool,
        themeManager: ThemeManager,
        colorScheme: ColorScheme,
        cornerRadius: CGFloat = 10
    ) -> some View {
        self
            .foregroundStyle(isSelected ? Color.white : themeManager.labelPrimary(for: colorScheme))
            .background(
                isSelected
                    ? themeManager.current.accentColor
                    : themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(themeManager.current.accentColor.opacity(0.14), lineWidth: 0.5)
                }
            }
    }
}
