//
//  SimpleStudio+Localization.swift
//  BuxMuse
//
//  Localizes Simple Studio UI copy via Settings → Country (es-419 catalog).
//

import Foundation

enum SimpleStudioCopy {
    static func line(_ sourceKey: String, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        let trimmed = sourceKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sourceKey }
        return BuxLocalizedString.string(trimmed, locale: locale)
    }

    static func format(_ sourceKey: String, locale: Locale, _ arguments: CVarArg...) -> String {
        BuxLocalizedString.format(sourceKey, locale: locale, arguments)
    }

    static func localizedSuggestions(locale: Locale) -> [String] {
        SimpleStudioSearchEngine.simpleSuggestionQueries.map { line($0, locale: locale) }
    }
}

extension StudioMode {
    func localizedDisplayName(locale: Locale) -> String {
        SimpleStudioCopy.line(displayName, locale: locale)
    }

    func localizedSubtitle(locale: Locale) -> String {
        SimpleStudioCopy.line(subtitle, locale: locale)
    }
}

extension StudioPersona {
    func localizedTitle(locale: Locale) -> String {
        SimpleStudioCopy.line(title, locale: locale)
    }

    func localizedSubtitle(locale: Locale) -> String {
        SimpleStudioCopy.line(subtitle, locale: locale)
    }
}

extension SimpleEntryKind {
    func localizedLogTitle(locale: Locale) -> String {
        SimpleStudioCopy.line(logTitle, locale: locale)
    }
}

extension SimpleScanField {
    func localizedChipTitle(locale: Locale) -> String {
        SimpleStudioCopy.line(chipTitle, locale: locale)
    }
}

extension SimplePaymentStatus {
    func localizedLabel(locale: Locale) -> String {
        switch self {
        case .paid: return SimpleStudioCopy.line("Paid", locale: locale)
        case .unpaid: return SimpleStudioCopy.line("Still waiting", locale: locale)
        case .partial: return SimpleStudioCopy.line("Partial", locale: locale)
        }
    }
}

extension SimpleStudioSearchEngine.Result {
    func localizedMatchReason(locale: Locale) -> String {
        SimpleStudioCopy.line(matchReason, locale: locale)
    }
}
