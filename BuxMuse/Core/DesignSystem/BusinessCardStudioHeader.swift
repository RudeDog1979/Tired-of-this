//
//  BusinessCardStudioHeader.swift
//  BuxMuse
//
//  Business Card Studio — borrows the Pro Studio gradient S.
//

import SwiftUI

struct BusinessCardStudioHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            HStack(alignment: .center, spacing: compact ? 6 : 8) {
                studioTitle(size: compact ? 17 : 28, weight: .bold)
                proBadge
            }

            if !compact {
                BuxCatalogDynamicText(key: "Business Card")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                BuxCatalogDynamicText(key: "Print · A8 · Social — your brand, your rules")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Business Card Pro Studio")
    }

    private func studioTitle(size: CGFloat, weight: Font.Weight) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("S")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(studioSGradient)
            BuxCatalogDynamicText(key: "tudio")
                .font(.system(size: size, weight: weight, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
    }

    private var studioSGradient: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.current.accentColor,
                themeManager.current.accentColor.opacity(0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.system(size: compact ? 9 : 10, weight: .heavy, design: .rounded))
            .tracking(compact ? 1.0 : 1.4)
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                LinearGradient(
                    colors: [
                        themeManager.current.accentColor,
                        themeManager.current.accentColor.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
    }
}
