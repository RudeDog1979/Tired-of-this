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

    static func analyze(emotion: String?) -> String? {
        guard let emotion = emotion?.lowercased(), !emotion.isEmpty else { return nil }
        switch emotion {
        case "joy":
            return "This purchase brought you joy — worth celebrating."
        case "excited":
            return "You felt excited about this one. Enjoy it mindfully."
        case "calm":
            return "A calm, intentional spend. Nice balance."
        case "neutral":
            return "A practical, neutral expense."
        case "stress":
            return "Tagged under stress. Worth a pause before the next similar buy."
        case "regret":
            return "Tagged as regret. Consider avoiding similar purchases."
        case "guilty":
            return "Some guilt here — reflect on whether this matched your values."
        default:
            return "Emotional tag: \(emotion.capitalized)."
        }
    }
}
