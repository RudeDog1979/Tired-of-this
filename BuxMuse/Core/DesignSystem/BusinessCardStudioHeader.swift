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
        VStack(alignment: .leading, spacing: compact ? 0 : 2) {
            HStack(alignment: .firstTextBaseline, spacing: compact ? 6 : 8) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Business Card ")
                        .font(.system(size: compact ? 17 : 28, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text("S")
                        .font(.system(size: compact ? 17 : 28, weight: .black, design: .rounded))
                        .foregroundStyle(studioSGradient)
                    Text("tudio")
                        .font(.system(size: compact ? 17 : 28, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }
                if !compact {
                    proBadge
                }
            }
            if !compact {
                Text("Print · A8 · Social — your brand, your rules")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Business Card Pro Studio")
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
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(1.4)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
