//
//  EmotionalTaggingEngine.swift
//  BuxMuse
//
//  Provides insights based on emotional tags.
//

import Foundation

struct EmotionalTaggingEngine {
    static func analyze(emotion: String?) -> String? {
        guard let emotion = emotion?.lowercased() else { return nil }
        switch emotion {
        case "joy": return "This purchase brought you joy! Worth it."
        case "regret": return "Tagged as regret. Consider avoiding similar purchases."
        case "neutral": return "A practical, neutral expense."
        default: return "Emotional tag: \(emotion.capitalized)."
        }
    }
}
