//
//  ContextTaggingEngine.swift
//  BuxMuse
//
//  Provides insights based on context tags.
//

import Foundation

struct ContextTaggingEngine {
    static func analyze(context: String?) -> String? {
        guard let context = context?.lowercased() else { return nil }
        return "Context: \(context.capitalized)"
    }
}
