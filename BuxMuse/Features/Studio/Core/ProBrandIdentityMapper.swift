//
//  ProBrandIdentityMapper.swift
//  BuxMuse
//
//  Maps a Pro business card design to invoice template branding tokens.
//

import Foundation

enum ProBrandIdentityMapper {

    static func templateConfig(
        from design: ProBusinessCardDesign,
        logoPosition: InvoiceLogoPosition
    ) -> InvoiceTemplateConfig {
        InvoiceTemplateConfig(
            style: invoiceStyle(for: design.template),
            primaryColorHex: design.palette.accentHex,
            secondaryColorHex: design.palette.foregroundHex,
            backgroundColorHex: design.palette.backgroundHex,
            typography: typography(from: design),
            cornerStyle: cornerStyle(for: design),
            density: density(for: design.template),
            logoPosition: resolvedLogoPosition(from: design, fallback: logoPosition),
            backgroundStyle: backgroundStyle(from: design.style.backgroundStyle),
            headerMotif: headerMotif(for: design.template),
            borderStyle: borderStyle(from: design.style.borderStyle),
            sourceCardTemplate: design.template.rawValue
        )
    }

    // MARK: - Typography

    private static func typography(from design: ProBusinessCardDesign) -> InvoiceTypographyStyle {
        let fontID = ProBusinessCardFontID.from(stored: design.style.typography.fontID)
        switch fontID {
        case .modernRounded, .friendly, .display, .handstyle:
            return .systemRounded
        case .classicSerif, .classicItalic, .elegantSerif, .luxury, .editorial:
            return .systemSerif
        default:
            switch design.style.fontPairing {
            case .classic: return .systemSerif
            case .bold, .modern: return .systemSans
            }
        }
    }

    // MARK: - Layout tokens

    private static func invoiceStyle(for template: ProBusinessCardTemplate) -> InvoiceTemplateStyle {
        switch template {
        case .boldTrade, .neonEdge, .gradientPro, .twoToneSplit, .glassFrost, .stampBadge, .photoForward:
            return .modern
        case .minimalMono, .lineMinimal, .swissGrid, .geometricGrid, .diagonalBands,
             .cornerBlocks, .splitVertical, .arcSweep, .hexAccent, .circleFrame:
            return .minimalist
        case .classic, .editorial, .letterpress, .monogram, .logoMark, .watermark, .qrFirst:
            return .executive
        }
    }

    private static func cornerStyle(for design: ProBusinessCardDesign) -> InvoiceCornerStyle {
        switch design.style.borderStyle {
        case .none, .thin:
            return invoiceStyle(for: design.template) == .minimalist ? .sharp : .soft
        case .double:
            return .soft
        case .accent:
            return .pill
        }
    }

    private static func density(for template: ProBusinessCardTemplate) -> InvoiceDensity {
        invoiceStyle(for: template) == .minimalist ? .compact : .comfortable
    }

    private static func resolvedLogoPosition(
        from design: ProBusinessCardDesign,
        fallback: InvoiceLogoPosition
    ) -> InvoiceLogoPosition {
        guard design.options.showsLogo else { return .none }
        if design.options.textAlignment == .center { return .topRight }
        return fallback
    }

    private static func backgroundStyle(
        from style: ProBusinessCardBackgroundStyle
    ) -> InvoiceBrandBackgroundStyle {
        switch style {
        case .solid: return .solid
        case .gradient: return .gradient
        case .patternDots: return .patternDots
        case .patternLines: return .patternLines
        case .photo: return .gradient
        }
    }

    private static func borderStyle(from style: ProBusinessCardBorderStyle) -> InvoiceBrandBorderStyle {
        switch style {
        case .none: return .none
        case .thin: return .thin
        case .double: return .double
        case .accent: return .accent
        }
    }

    // MARK: - Header motifs (card template → invoice header shape language)

    static func headerMotif(for template: ProBusinessCardTemplate) -> InvoiceBrandMotif {
        switch template {
        case .classic: return .sideAccentBar
        case .twoToneSplit: return .twoToneSplit
        case .gradientPro, .boldTrade: return .topGradientBand
        case .diagonalBands: return .diagonalBands
        case .cornerBlocks: return .cornerBlocks
        case .hexAccent: return .hexAccent
        case .stampBadge, .circleFrame: return .circleBadge
        case .neonEdge: return .neonFrame
        case .lineMinimal, .letterpress, .minimalMono: return .minimalRule
        case .geometricGrid, .swissGrid: return .geometricGrid
        case .splitVertical: return .splitVertical
        case .arcSweep: return .arcSweep
        case .monogram: return .monogramBand
        case .editorial, .logoMark, .watermark: return .editorialLine
        case .glassFrost, .photoForward, .qrFirst: return .topGradientBand
        }
    }
}
