//
//  BuxSegmentedCapsuleSelector.swift
//  BuxMuse — Sliding capsule highlight for two-segment pickers.
//

import SwiftUI

/// Glass capsule background plus a sliding highlight for exactly two segments.
struct BuxSegmentedCapsuleSelector<Leading: View, Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let leadingSelected: Bool
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    private let segmentInset: CGFloat = 4

    var body: some View {
        HStack(spacing: 0) {
            leading()
            trailing()
        }
        .background {
            BuxGlassCapsuleBackground(castsShadow: false)
        }
        .overlay {
            GeometryReader { proxy in
                let segmentWidth = max(0, (proxy.size.width - segmentInset * 2) / 2)
                Capsule(style: .continuous)
                    .fill(
                        themeManager.contrastAccentColor(for: colorScheme)
                            .opacity(colorScheme == .dark ? 0.28 : 0.16)
                    )
                    .frame(width: segmentWidth, height: max(0, proxy.size.height - segmentInset * 2))
                    .offset(
                        x: leadingSelected ? segmentInset : segmentInset + segmentWidth,
                        y: segmentInset
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: leadingSelected)
            }
            .allowsHitTesting(false)
        }
    }
}

struct BuxSegmentedCapsuleSegment: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let isSelected: Bool
    var trailingAccessory: AnyView? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            if let trailingAccessory {
                trailingAccessory
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .foregroundColor(
            isSelected
                ? themeManager.labelPrimary(for: colorScheme)
                : themeManager.labelSecondary(for: colorScheme)
        )
        .contentShape(Rectangle())
    }
}
