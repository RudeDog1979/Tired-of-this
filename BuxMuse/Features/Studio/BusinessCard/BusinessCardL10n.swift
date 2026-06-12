//
//  BusinessCardL10n.swift
//  BuxMuse
//

import Foundation

enum BusinessCardL10n {
    static func line(_ key: String, locale: Locale) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        BuxLocalizedString.format(key, locale: locale, arguments)
    }
}

extension ProBusinessCardTemplate {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }

    func catalogSubtitle(locale: Locale) -> String {
        BusinessCardL10n.line(subtitle, locale: locale)
    }
}

extension ProBusinessCardCollection {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }
}

extension ProBusinessCardAspect {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }
}

extension CardShapeType {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }
}

extension BuxPhotoStudioTarget {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }
}

extension CardImageMask {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }
}

extension BuxBrandStyleEngine.LayoutPack {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }

    func catalogSubtitle(locale: Locale) -> String {
        BusinessCardL10n.line(subtitle, locale: locale)
    }
}

extension BuxDesignerColorPresets.Group {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }
}

extension ProBusinessCardIdentityMode {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }

    func catalogSubtitle(locale: Locale) -> String {
        BusinessCardL10n.line(subtitle, locale: locale)
    }
}

extension ProBusinessCardBackgroundStyle {
    func catalogTitle(locale: Locale) -> String {
        BusinessCardL10n.line(title, locale: locale)
    }
}

extension BusinessCardCIFilterPipeline {
    static func catalogName(for presetName: String, locale: Locale) -> String {
        BusinessCardL10n.line(presetName, locale: locale)
    }
}

extension BuxCardBackgroundPhotoMode {
    func catalogLabel(locale: Locale) -> String {
        BusinessCardL10n.line(rawValue, locale: locale)
    }

    func catalogDetail(locale: Locale) -> String {
        BusinessCardL10n.line(detail, locale: locale)
    }
}
