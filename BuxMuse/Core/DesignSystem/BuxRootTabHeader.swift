//
//  BuxRootTabHeader.swift
//  BuxMuse
//
//  Scrolls with content — Apple Health–style root tab titles (SF Pro, not rounded).
//

import SwiftUI

enum BuxCountrySubtitle {
    static func label(country: CountrySetting, locale: Locale) -> String {
        let name = TaxCountryDisplayName.localizedRegionName(isoCode: country.id, locale: locale)
            ?? country.name
        return "\(country.flag) \(name)"
    }
}

struct BuxRootTabHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    enum Style: Equatable {
        case plain(titleKey: String, showCountrySubtitle: Bool = false)
        case studioPro
        case studioSimple
    }

    let style: Style

    var body: some View {
        Group {
            switch style {
            case .plain(let titleKey, let showCountry):
                plainHeader(titleKey: titleKey, showCountrySubtitle: showCountry)
            case .studioPro:
                StudioTierWordmark(style: .hero)
            case .studioSimple:
                SimpleStudioHeader()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private func plainHeader(titleKey: String, showCountrySubtitle: Bool) -> some View {
        let locale = appSettingsManager.interfaceLocale

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                accentDot
                Text(BuxCatalogLabel.string(titleKey, locale: locale))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            if showCountrySubtitle {
                Text(BuxCountrySubtitle.label(
                    country: appSettingsManager.selectedCountry,
                    locale: locale
                ))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.leading, 16)

                accentUnderline
                    .padding(.leading, 16)
            }
        }
    }

    private var accentDot: some View {
        Circle()
            .fill(themeManager.current.accentColor)
            .frame(width: 6, height: 6)
    }

    private var accentUnderline: some View {
        Capsule()
            .fill(themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.85 : 0.72))
            .frame(width: 28, height: 2)
    }

    private var accessibilityText: String {
        let locale = appSettingsManager.interfaceLocale
        switch style {
        case .plain(let titleKey, _):
            return BuxCatalogLabel.string(titleKey, locale: locale)
        case .studioPro:
            return BuxCatalogLabel.string("Pro Studio", locale: locale)
        case .studioSimple:
            return BuxCatalogLabel.string("Simple Studio", locale: locale)
        }
    }
}

extension BuxRootTabHeader {
    /// First row inside a `buxRootTabScrollChrome()` scroll — no extra horizontal inset (scroll margins handle it).
    static func rootScrollRow(style: Style) -> some View {
        BuxRootTabHeader(style: style)
            .padding(.bottom, BuxTokens.tight)
    }
}
