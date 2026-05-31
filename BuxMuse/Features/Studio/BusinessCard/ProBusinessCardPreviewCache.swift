//
//  ProBusinessCardPreviewCache.swift
//  BuxMuse
//
//  Cached sample designs for template gallery — avoids rebuilding canvas on every frame.
//

import Foundation

enum ProBusinessCardPreviewCache {
    private static var store: [String: [ProBusinessCardTemplate: ProBusinessCardDesign]] = [:]

    static func design(template: ProBusinessCardTemplate, content: ProBusinessCardContent) -> ProBusinessCardDesign {
        let key = signature(content)
        if store[key] == nil {
            store[key] = [:]
        }
        if let cached = store[key]?[template] {
            return cached
        }
        var design = ProBusinessCardDesign(
            title: template.title,
            template: template,
            content: content
        )
        design.applyTemplateDefaults()
        store[key]?[template] = design
        return design
    }

    private static func signature(_ content: ProBusinessCardContent) -> String {
        [
            content.name,
            content.tagline,
            content.phone,
            content.email,
            content.website
        ].joined(separator: "|")
    }
}
