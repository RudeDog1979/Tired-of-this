//
//  ProBusinessCardFonts.swift
//  BuxMuse
//

import SwiftUI

enum ProBusinessCardFontID: String, CaseIterable, Identifiable, Codable, Sendable {
    case modernRounded, modernDefault, classicSerif, classicItalic
    case boldHeavy, boldCondensed, elegantSerif, geometric
    case friendly, professional, display, mono
    case luxury, tech, handstyle, editorial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modernRounded: return "Modern Rounded"
        case .modernDefault: return "Modern Clean"
        case .classicSerif: return "Classic Serif"
        case .classicItalic: return "Classic Italic"
        case .boldHeavy: return "Bold Heavy"
        case .boldCondensed: return "Bold Condensed"
        case .elegantSerif: return "Elegant Serif"
        case .geometric: return "Geometric"
        case .friendly: return "Friendly"
        case .professional: return "Professional"
        case .display: return "Display"
        case .mono: return "Mono Tech"
        case .luxury: return "Luxury"
        case .tech: return "Tech"
        case .handstyle: return "Hand Style"
        case .editorial: return "Editorial"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .modernRounded: return .system(size: size, weight: weight, design: .rounded)
        case .modernDefault: return .system(size: size, weight: weight, design: .default)
        case .classicSerif: return .system(size: size, weight: weight, design: .serif)
        case .classicItalic: return .system(size: size, weight: weight, design: .serif).italic()
        case .boldHeavy: return .system(size: size, weight: .heavy, design: .default)
        case .boldCondensed: return .system(size: size, weight: .bold, design: .default)
        case .elegantSerif: return .system(size: size, weight: .light, design: .serif)
        case .geometric: return .system(size: size, weight: weight, design: .monospaced)
        case .friendly: return .system(size: size, weight: .semibold, design: .rounded)
        case .professional: return .system(size: size, weight: .medium, design: .default)
        case .display: return .system(size: size, weight: .black, design: .rounded)
        case .mono: return .system(size: size, weight: weight, design: .monospaced)
        case .luxury: return .system(size: size, weight: .thin, design: .serif)
        case .tech: return .system(size: size, weight: .bold, design: .monospaced)
        case .handstyle: return .system(size: size, weight: .semibold, design: .rounded)
        case .editorial: return .system(size: size, weight: .semibold, design: .serif)
        }
    }

    static func from(stored: String) -> ProBusinessCardFontID {
        ProBusinessCardFontID(rawValue: stored) ?? .modernRounded
    }
}
