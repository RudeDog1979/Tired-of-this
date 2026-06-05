//
//  TaxStudioHeader.swift
//  BuxMuse
//
//  Tax studio — “Tax” + signature gradient S + “tudio” + PRO badge.
//

import SwiftUI

struct TaxStudioNavigationTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var style: Style = .large

    enum Style {
        case large
        case compact

        var prefixSize: CGFloat {
            switch self {
            case .large: return 34
            case .compact: return 17
            }
        }

        var weight: Font.Weight {
            switch self {
            case .large: return .bold
            case .compact: return .bold
            }
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: style == .large ? 8 : 6) {
            taxStudioWordmark
            proBadge
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("TaxStudio Pro")
    }

    private var taxStudioWordmark: some View {
        let primary = themeManager.labelPrimary(for: colorScheme)
        return (
            Text("Tax\u{2009}")
                .foregroundColor(primary) +
            Text("S")
                .foregroundStyle(studioSGradient) +
            Text("tudio")
                .foregroundColor(primary)
        )
        .font(.system(size: style.prefixSize, weight: style.weight, design: .rounded))
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
            .font(.system(size: style == .large ? 10 : 9, weight: .heavy, design: .rounded))
            .tracking(style == .large ? 1.4 : 1.0)
            .foregroundColor(.white)
            .padding(.horizontal, style == .large ? 8 : 6)
            .padding(.vertical, style == .large ? 4 : 3)
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
