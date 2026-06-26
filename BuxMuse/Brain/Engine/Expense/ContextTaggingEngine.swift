//
//  ContextTaggingEngine.swift
//  BuxMuse
//
//  Provides insights based on context tags.
//

import Foundation

struct ContextTaggingEngine {
    static func analyze(context: String?, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String? {
        guard let context = context?.trimmingCharacters(in: .whitespacesAndNewlines), !context.isEmpty else {
            return nil
        }
        return BuxLocalizedString.format("Context: %@", locale: locale, context)
    }
}
