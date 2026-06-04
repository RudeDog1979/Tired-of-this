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
        let specifiers = formatSpecifiers(in: format)
        let prepared: [CVarArg]
        if specifiers.count == arguments.count {
            prepared = zip(specifiers, arguments).map { coerce($1, for: $0) }
        } else {
            #if DEBUG
            print(
                "BuxStringCatalog: specifier count \(specifiers.count) != argument count \(arguments.count) for key: \(key)"
            )
            #endif
            prepared = arguments.map { coerceLoose($0) }
        }
        return String(format: format, locale: locale, arguments: prepared)
    }

    /// Parses `%@`, `%lld`, `%d`, etc. Skips `%%` literals.
    private static func formatSpecifiers(in format: String) -> [String] {
        var specs: [String] = []
        var index = format.startIndex
        while index < format.endIndex {
            guard format[index] == "%" else {
                index = format.index(after: index)
                continue
            }
            let afterPercent = format.index(after: index)
            guard afterPercent < format.endIndex else { break }
            if format[afterPercent] == "%" {
                index = format.index(after: afterPercent)
                continue
            }

            var cursor = afterPercent
            while cursor < format.endIndex, format[cursor].isNumber || format[cursor] == "$" {
                cursor = format.index(after: cursor)
            }
            while cursor < format.endIndex {
                let ch = format[cursor]
                if ch == "@" {
                    specs.append("%@")
                    index = format.index(after: cursor)
                    break
                }
                if ch == "d" {
                    let prev = format.index(before: cursor)
                    let prev2 = format.index(before: prev)
                    if format[prev] == "l", format[prev2] == "l" {
                        specs.append("%lld")
                    } else if format[prev] == "l" {
                        specs.append("%ld")
                    } else {
                        specs.append("%d")
                    }
                    index = format.index(after: cursor)
                    break
                }
                if ch == "i" || ch == "u" || ch == "o" || ch == "x" || ch == "X" || ch == "f" || ch == "F" {
                    specs.append(String(format[index...cursor]))
                    index = format.index(after: cursor)
                    break
                }
                cursor = format.index(after: cursor)
            }
            if cursor >= format.endIndex { break }
        }
        return specs
    }

    private static func coerce(_ argument: CVarArg, for specifier: String) -> CVarArg {
        switch specifier {
        case "%@":
            return stringArgument(argument)
        case "%lld", "%ld", "%d", "%i", "%u", "%o", "%x", "%X":
            return integerArgument(argument)
        default:
            return argument
        }
    }

    private static func coerceLoose(_ argument: CVarArg) -> CVarArg {
        switch argument {
        case is Int, is Int32, is Int64, is UInt:
            return stringArgument(argument)
        default:
            return argument
        }
    }

    private static func stringArgument(_ argument: CVarArg) -> CVarArg {
        switch argument {
        case let value as String: return value
        case let value as Int: return String(value)
        case let value as Int32: return String(value)
        case let value as Int64: return String(value)
        case let value as UInt: return String(value)
        case let value as Double: return String(value)
        default: return String(describing: argument)
        }
    }

    private static func integerArgument(_ argument: CVarArg) -> CVarArg {
        switch argument {
        case let value as Int: return value
        case let value as Int32: return Int(value)
        case let value as Int64: return Int(value)
        case let value as UInt: return Int(value)
        case let value as String: return Int(value) ?? 0
        default: return 0
        }
    }
}
