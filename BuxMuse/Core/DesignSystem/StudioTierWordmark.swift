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
