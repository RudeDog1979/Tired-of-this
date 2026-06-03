//
//  BuxStringCatalog.swift
//  BuxMuse
//
//  Resolves Localizable.xcstrings via compiled `.lproj` bundles.
//  `String(localized:locale:)` does not reliably load `es-419` — use this for UI copy.
//

import Foundation

enum BuxStringCatalog {
    private static let lock = NSLock()
    private static var bundleByTag: [String: Bundle] = [:]

    /// BCP-47 tag matching compiled folders (`es-419`, `es-ES`, …).
    static func resourceTag(for locale: Locale) -> String {
        locale.identifier.replacingOccurrences(of: "_", with: "-")
    }

    private static func bundle(forResourceTag tag: String) -> Bundle? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = bundleByTag[tag] { return cached }
        guard let path = Bundle.main.path(forResource: tag, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        bundleByTag[tag] = bundle
        return bundle
    }

    private static func lookupInBundle(_ key: String, bundle: Bundle) -> String? {
        let value = bundle.localizedString(forKey: key, value: key, table: nil)
        return value != key ? value : nil
    }

    /// Localized UI string for `key` using Settings interface locale (not device language).
    static func localized(_ key: String, locale: Locale) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return key }

        let tag = resourceTag(for: locale)

        if let bundle = bundle(forResourceTag: tag),
           let value = lookupInBundle(trimmed, bundle: bundle) {
            return value
        }

        // English / development language — source keys are English.
        if tag == "en" || tag.hasPrefix("en-") {
            return trimmed
        }

        // Parent fallbacks (es-419 → es, es-ES → es).
        if tag.hasPrefix("es"), tag != "es", let esBundle = bundle(forResourceTag: "es"),
           let value = lookupInBundle(trimmed, bundle: esBundle) {
            return value
        }

        return trimmed
    }

    static func localizedFormat(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let format = localized(key, locale: locale)
        return String(format: format, locale: locale, arguments: arguments)
    }
}
