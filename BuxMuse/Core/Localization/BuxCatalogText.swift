//
//  BuxCatalogText.swift
//  BuxMuse
//
//  Renders English source keys from `Localizable.xcstrings` using Settings → Country
//  (not device language). Use catalog keys for UI copy; never for user/merchant names.
//

import Foundation
import SwiftUI

/// Tab bar label backed by `Localizable.xcstrings` and Settings → Country locale.
struct BuxTabBarLabel: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let titleKey: String
    let systemImage: String

    var body: some View {
        Label {
            Text(BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale))
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

enum BuxCatalogText {
    /// Resolves a catalog key with the interface locale (off–main-actor safe).
    static func string(_ key: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    /// SwiftUI label for English source keys stored as `String` (nav, chips, sections).
    static func text(_ key: String) -> BuxCatalogDynamicText {
        BuxCatalogDynamicText(key: key)
    }
}

/// Renders catalog keys stored in `String` properties (brain rows, nav labels, chips).
struct BuxCatalogDynamicText: View {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let key: String

    var body: some View {
        Text(BuxCatalogLabel.string(key, locale: appSettingsManager.interfaceLocale))
    }
}

extension View {
    /// `navigationTitle` for English source keys held in a `String` (not user-entered names).
    func buxCatalogNavigationTitle(_ key: String) -> some View {
        modifier(BuxCatalogNavigationTitleModifier(titleKey: key))
    }

    /// Ensures sheets and pushed flows use Settings → Country interface locale.
    func buxInterfaceLocale() -> some View {
        modifier(BuxInterfaceLocaleModifier())
    }
}

private struct BuxCatalogNavigationTitleModifier: ViewModifier {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    let titleKey: String

    func body(content: Content) -> some View {
        content.navigationTitle(BuxCatalogLabel.string(titleKey, locale: appSettingsManager.interfaceLocale))
    }
}

private struct BuxInterfaceLocaleModifier: ViewModifier {
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    func body(content: Content) -> some View {
        content.environment(\.locale, appSettingsManager.interfaceLocale)
    }
}

enum BuxLocalizedString {
    static func string(_ key: String, locale: Locale) -> String {
        BuxStringCatalog.localized(key, locale: locale)
    }

    static func string(_ key: String.LocalizationValue, locale: Locale) -> String {
        string(String(localized: key), locale: locale)
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        BuxStringCatalog.localizedFormat(key, locale: locale, arguments)
    }

    static func format(_ key: String.LocalizationValue, locale: Locale, _ arguments: CVarArg...) -> String {
        format(String(localized: key), locale: locale, arguments)
    }
}
