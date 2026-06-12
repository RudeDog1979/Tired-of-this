//
//  EmotionalTaggingEngine.swift
//  BuxMuse
//
//  Provides insights based on emotional tags.
//

import Foundation

struct EmotionalTag: Identifiable, Equatable, Hashable {
    let id: String
    let label: String
    let symbol: String

    var isEmpty: Bool { id.isEmpty }

    func localizedLabel(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        BuxCatalogLabel.string(label, locale: locale)
    }
}

struct EmotionalTaggingEngine {
    static let noneTag = EmotionalTag(id: "", label: "None", symbol: "circle.slash")

    static let selectableTags: [EmotionalTag] = [
        noneTag,
        EmotionalTag(id: "joy", label: "Joy", symbol: "face.smiling.fill"),
        EmotionalTag(id: "excited", label: "Excited", symbol: "sparkles"),
        EmotionalTag(id: "calm", label: "Calm", symbol: "leaf.fill"),
        EmotionalTag(id: "neutral", label: "Neutral", symbol: "minus.circle.fill"),
        EmotionalTag(id: "stress", label: "Stress", symbol: "bolt.heart.fill"),
        EmotionalTag(id: "regret", label: "Regret", symbol: "cloud.rain.fill"),
        EmotionalTag(id: "guilty", label: "Guilty", symbol: "eye.trianglebadge.exclamationmark.fill")
    ]

    static func tag(for id: String) -> EmotionalTag? {
        selectableTags.first { $0.id == id }
    }

    static func analyze(emotion: String?, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String? {
        guard let emotion = emotion?.lowercased(), !emotion.isEmpty else { return nil }
        switch emotion {
        case "joy":
            return BuxLocalizedString.string(
                "This purchase brought you joy — worth celebrating.",
                locale: locale
            )
        case "excited":
            return BuxLocalizedString.string(
                "You felt excited about this one. Enjoy it mindfully.",
                locale: locale
            )
        case "calm":
            return BuxLocalizedString.string(
                "A calm, intentional spend. Nice balance.",
                locale: locale
            )
        case "neutral":
            return BuxLocalizedString.string("A practical, neutral expense.", locale: locale)
        case "stress":
            return BuxLocalizedString.string(
                "Tagged under stress. Worth a pause before the next similar buy.",
                locale: locale
            )
        case "regret":
            return BuxLocalizedString.string(
                "Tagged as regret. Consider avoiding similar purchases.",
                locale: locale
            )
        case "guilty":
            return BuxLocalizedString.string(
                "Some guilt here — reflect on whether this matched your values.",
                locale: locale
            )
        default:
            return BuxLocalizedString.format(
                "Emotional tag: %@.",
                locale: locale,
                emotion.capitalized
            )
        }
    }
}
