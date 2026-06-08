//
//  StudioTierWordmark.swift
//  BuxMuse
//
//  Pro Studio branding — gradient S in “Studio” plus PRO badge.
//  Simple Studio uses SimpleStudioHeader instead.
//

import SwiftUI

/// Pro-only hero header — the page title for Pro Studio hubs.
struct StudioTierWordmark: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var style: Style = .hero

    enum Style {
        case hero
        case navigation
        /// Studio signature S + tudio — no PRO badge (Simple Studio tools).
        case navigationPlain
        case badge
        case largeTitle
        case largeSubtitle
    }

    var body: some View {
        switch style {
        case .hero:
            heroMark
        case .navigation:
            navigationMark
        case .navigationPlain:
            plainNavigationMark
        case .badge:
            tierBadge(compact: true)
        case .largeTitle:
            heroTitleLine
        case .largeSubtitle:
            heroTaglineLine
        }
    }

    private var heroMark: some View {
        VStack(alignment: .leading, spacing: 2) {
            heroTitleLine
            heroTaglineLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(BuxCatalogLabel.string("Pro Studio", locale: appSettingsManager.interfaceLocale))
    }

    private var heroTitleLine: some View {
        HStack(alignment: .center, spacing: 8) {
            studioTitle(size: 34, weight: .bold)
            tierBadge(compact: false)
        }
    }

    private var heroTaglineLine: some View {
        BuxCatalogDynamicText(key: "Full tax, PDF invoices, analytics")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var navigationMark: some View {
        HStack(alignment: .center, spacing: 8) {
            studioTitle(size: 17, weight: .bold)
            tierBadge(compact: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(BuxCatalogLabel.string("Pro Studio", locale: appSettingsManager.interfaceLocale))
    }

    private var plainNavigationMark: some View {
        studioTitle(size: 17, weight: .bold)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(BuxCatalogLabel.string("Studio", locale: appSettingsManager.interfaceLocale))
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

    private func tierBadge(compact: Bool) -> some View {
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
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 0.5)
            )
            .accessibilityLabel(BuxCatalogLabel.string("Pro tier", locale: appSettingsManager.interfaceLocale))
    }
}

/// Tier-2 Simple Studio tool screen — Studio signature S wordmark + feature title (no PRO).
struct StudioSimpleToolScreenHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let titleKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StudioTierWordmark(style: .navigationPlain)
            Text(BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let feature = BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale)
        return "\(BuxCatalogLabel.string("Studio", locale: appSettingsManager.interfaceLocale)), \(feature)"
    }
}

/// Tier-2 Pro tool screen — Studio PRO brand in scroll content + separate feature title (Tax Studio pattern).
struct StudioProToolScreenHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let titleKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StudioTierWordmark(style: .navigation)
            Text(BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let feature = BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale)
        return "\(BuxCatalogLabel.string("Pro Studio", locale: appSettingsManager.interfaceLocale)), \(feature)"
    }

    /// Scroll screens — header carries horizontal inset (Insights pattern).
    func studioProToolScrollPlacement() -> some View {
        studioHubEmbeddedHorizontalPadding()
            .padding(.bottom, StudioProToolHeaderLayout.bottomSpacing)
    }

    /// Form / scroll container already applies horizontal margins (`buxScreenContentMargins`).
    func studioProToolScrollPlacementEmbedded() -> some View {
        padding(.bottom, StudioProToolHeaderLayout.bottomSpacing)
    }
}

/// Tier-3 Pro product screen — prefix + Studio + PRO (Tax Studio, etc.).
struct StudioProProductScreenHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let prefixKey: String
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

        var badgeSpacing: CGFloat {
            switch self {
            case .large: return 8
            case .compact: return 6
            }
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: style.badgeSpacing) {
            productWordmark
            proBadge
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var productWordmark: Text {
        let primary = themeManager.labelPrimary(for: colorScheme)
        let prefix = BuxCatalogLabel.string(prefixKey, locale: appSettingsManager.interfaceLocale)
        return (
            Text("\(prefix)\u{2009}")
                .foregroundColor(primary) +
            Text("S")
                .foregroundStyle(studioSGradient) +
            Text("tudio")
                .foregroundColor(primary)
        )
        .font(.system(size: style.prefixSize, weight: .bold, design: .rounded))
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

    private var accessibilityText: String {
        let prefix = BuxCatalogLabel.string(prefixKey, locale: appSettingsManager.interfaceLocale)
        return "\(prefix) Studio Pro"
    }

    func studioProToolScrollPlacement() -> some View {
        studioHubEmbeddedHorizontalPadding()
            .padding(.bottom, StudioProToolHeaderLayout.bottomSpacing)
    }

    func studioProToolScrollPlacementEmbedded() -> some View {
        padding(.bottom, StudioProToolHeaderLayout.bottomSpacing)
    }
}

/// Simple Studio page header — "Simple" + Signature-S gradient "Studio" wordmark.
struct SimpleStudioHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var style: Style = .hero

    enum Style {
        case hero
        case largeTitle
        case largeSubtitle
    }

    var body: some View {
        switch style {
        case .hero:
            heroMark
        case .largeTitle:
            titleLine
        case .largeSubtitle:
            taglineLine
        }
    }

    private var heroMark: some View {
        VStack(alignment: .leading, spacing: 2) {
            titleLine
            taglineLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(BuxCatalogLabel.string("Simple Studio", locale: appSettingsManager.interfaceLocale))
    }

    private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("Simple ")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            Text("S")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(simpleStudioSGradient)
            BuxCatalogDynamicText(key: "tudio")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
    }

    private var taglineLine: some View {
        BuxCatalogDynamicText(key: "Track jobs, advances, and who owes you — free.")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private var simpleStudioSGradient: LinearGradient {
        LinearGradient(
            colors: [
                themeManager.current.accentColor,
                themeManager.current.accentColor.opacity(0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
