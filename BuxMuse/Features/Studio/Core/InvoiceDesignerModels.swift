//
//  InvoiceDesignerModels.swift
//  BuxMuse
//
//  Invoice Designer & Engine Hub — config types, render context, and snapshot.
//  All types are Codable and local-first. Zero network dependencies.
//

import SwiftUI
import Foundation

// MARK: - Template Style Enum

public enum InvoiceTemplateStyle: String, Codable, CaseIterable, Identifiable {
    case modern     = "Modern"
    case minimalist = "Minimalist"
    case executive  = "Executive"

    public var id: String { rawValue }

    public var tagline: String {
        switch self {
        case .modern:     return "Bold, branded, contemporary"
        case .minimalist: return "Clean, white-space, typographic"
        case .executive:  return "Corporate, dual-column, premium"
        }
    }

    public var systemIcon: String {
        switch self {
        case .modern:     return "rectangle.split.1x2.fill"
        case .minimalist: return "doc.plaintext.fill"
        case .executive:  return "building.2.fill"
        }
    }
}

// MARK: - Typography Style

public enum InvoiceTypographyStyle: String, Codable, CaseIterable, Identifiable {
    case systemRounded = "Rounded"
    case systemSans    = "Sans"
    case systemSerif   = "Serif"

    public var id: String { rawValue }

    public func headingFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        switch self {
        case .systemRounded: return .system(size: size, weight: weight, design: .rounded)
        case .systemSans:    return .system(size: size, weight: weight, design: .default)
        case .systemSerif:   return .system(size: size, weight: weight, design: .serif)
        }
    }

    public func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .systemRounded: return .system(size: size, weight: weight, design: .rounded)
        case .systemSans:    return .system(size: size, weight: weight, design: .default)
        case .systemSerif:   return .system(size: size, weight: weight, design: .serif)
        }
    }

    public func uiHeadingFont(size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
        switch self {
        case .systemRounded: return UIFont.systemFont(ofSize: size, weight: weight)
        case .systemSans:    return UIFont.systemFont(ofSize: size, weight: weight)
        case .systemSerif:
            return UIFont(descriptor: UIFont.systemFont(ofSize: size, weight: weight)
                .fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: size, weight: weight)
                .fontDescriptor, size: size)
        }
    }
}

// MARK: - Corner Style

public enum InvoiceCornerStyle: String, Codable, CaseIterable, Identifiable {
    case sharp = "Sharp"
    case soft  = "Soft"
    case pill  = "Pill"

    public var id: String { rawValue }

    public var radius: CGFloat {
        switch self {
        case .sharp: return 0
        case .soft:  return 8
        case .pill:  return 18
        }
    }
}

// MARK: - Density

public enum InvoiceDensity: String, Codable, CaseIterable, Identifiable {
    case compact     = "Compact"
    case comfortable = "Comfortable"
    case spacious    = "Spacious"

    public var id: String { rawValue }

    public var lineSpacing: CGFloat {
        switch self {
        case .compact:     return 2
        case .comfortable: return 6
        case .spacious:    return 12
        }
    }

    public var sectionPadding: CGFloat {
        switch self {
        case .compact:     return 10
        case .comfortable: return 16
        case .spacious:    return 24
        }
    }

    public var rowHeight: CGFloat {
        switch self {
        case .compact:     return 18
        case .comfortable: return 24
        case .spacious:    return 32
        }
    }
}

// MARK: - Tax Mode

public enum InvoiceTaxMode: String, Codable, CaseIterable, Identifiable {
    case exclusive = "Add on top"
    case inclusive = "Included in price"

    public var id: String { rawValue }
}

// MARK: - Brand tokens (synced from Pro Business Card)

public enum InvoiceBrandBackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case solid = "Solid"
    case gradient = "Gradient"
    case patternDots = "Dots"
    case patternLines = "Lines"
    case photo = "Photo"

    public var id: String { rawValue }
}

public enum InvoiceBrandMotif: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case sideAccentBar = "Side Accent"
    case twoToneSplit = "Two-Tone Split"
    case topGradientBand = "Gradient Band"
    case diagonalBands = "Diagonal Bands"
    case cornerBlocks = "Corner Blocks"
    case hexAccent = "Hex Accent"
    case circleBadge = "Circle Badge"
    case neonFrame = "Neon Frame"
    case minimalRule = "Minimal Rule"
    case geometricGrid = "Geometric Grid"
    case splitVertical = "Split Vertical"
    case arcSweep = "Arc Sweep"
    case monogramBand = "Monogram"
    case editorialLine = "Editorial Line"

    public var id: String { rawValue }
}

public enum InvoiceBrandBorderStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case thin = "Thin"
    case double = "Double"
    case accent = "Accent"

    public var id: String { rawValue }
}

// MARK: - Core Config Structs

public struct InvoiceTaxRate: Codable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var label: String       // e.g. "VAT", "GST", "ITBIS"
    public var percentage: Decimal // e.g. 20.0 for 20%
    public var isCompounding: Bool // if true, stacks on previous running total

    public init(
        id: UUID = UUID(),
        label: String,
        percentage: Decimal,
        isCompounding: Bool = false
    ) {
        self.id = id
        self.label = label
        self.percentage = percentage
        self.isCompounding = isCompounding
    }
}

public struct InvoiceTemplateConfig: Codable, Equatable {
    public var style: InvoiceTemplateStyle
    /// Brand accent — maps from card `palette.accentHex`.
    public var primaryColorHex: String
    /// Foreground / text accent — maps from card `palette.foregroundHex`.
    public var secondaryColorHex: String
    /// Page tint — maps from card `palette.backgroundHex`.
    public var backgroundColorHex: String
    public var typography: InvoiceTypographyStyle
    public var cornerStyle: InvoiceCornerStyle
    public var density: InvoiceDensity
    public var logoPosition: InvoiceLogoPosition
    public var backgroundStyle: InvoiceBrandBackgroundStyle
    /// Decorative header shape language from the source card template.
    public var headerMotif: InvoiceBrandMotif
    public var borderStyle: InvoiceBrandBorderStyle
    /// Raw `ProBusinessCardTemplate` id when synced from a card.
    public var sourceCardTemplate: String?
    /// Decorative shapes exported from the primary card canvas (overrides motif when non-empty).
    public var headerStamps: [BrandShapeStamp]?
    /// Optional card background photo path for invoice header band.
    public var headerPhotoPath: String?
    public var useCardHeaderPhoto: Bool

    public var showsHeaderDecoration: Bool {
        headerMotif != .none || !(headerStamps?.isEmpty ?? true) || useCardHeaderPhoto
    }

    public var primaryColor: Color   { Color(hex: primaryColorHex) }
    public var secondaryColor: Color { Color(hex: secondaryColorHex) }
    public var backgroundColor: Color { Color(hex: backgroundColorHex) }

    public static let `default` = InvoiceTemplateConfig(
        style: .modern,
        primaryColorHex: "#5A55F5",
        secondaryColorHex: "#111827",
        backgroundColorHex: "#FFFFFF",
        typography: .systemSans,
        cornerStyle: .soft,
        density: .comfortable,
        logoPosition: .topLeft,
        backgroundStyle: .solid,
        headerMotif: .none,
        borderStyle: .none,
        sourceCardTemplate: nil,
        headerStamps: nil,
        headerPhotoPath: nil,
        useCardHeaderPhoto: false
    )

    public init(
        style: InvoiceTemplateStyle,
        primaryColorHex: String,
        secondaryColorHex: String,
        backgroundColorHex: String = "#FFFFFF",
        typography: InvoiceTypographyStyle,
        cornerStyle: InvoiceCornerStyle,
        density: InvoiceDensity,
        logoPosition: InvoiceLogoPosition,
        backgroundStyle: InvoiceBrandBackgroundStyle = .solid,
        headerMotif: InvoiceBrandMotif = .none,
        borderStyle: InvoiceBrandBorderStyle = .none,
        sourceCardTemplate: String? = nil,
        headerStamps: [BrandShapeStamp]? = nil,
        headerPhotoPath: String? = nil,
        useCardHeaderPhoto: Bool = false
    ) {
        self.style = style
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.backgroundColorHex = backgroundColorHex
        self.typography = typography
        self.cornerStyle = cornerStyle
        self.density = density
        self.logoPosition = logoPosition
        self.backgroundStyle = backgroundStyle
        self.headerMotif = headerMotif
        self.borderStyle = borderStyle
        self.sourceCardTemplate = sourceCardTemplate
        self.headerStamps = headerStamps
        self.headerPhotoPath = headerPhotoPath
        self.useCardHeaderPhoto = useCardHeaderPhoto
    }

    private enum CodingKeys: String, CodingKey {
        case style, primaryColorHex, secondaryColorHex, backgroundColorHex
        case typography, cornerStyle, density, logoPosition
        case backgroundStyle, headerMotif, borderStyle, sourceCardTemplate
        case headerStamps, headerPhotoPath, useCardHeaderPhoto
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        style = try c.decode(InvoiceTemplateStyle.self, forKey: .style)
        primaryColorHex = try c.decode(String.self, forKey: .primaryColorHex)
        secondaryColorHex = try c.decode(String.self, forKey: .secondaryColorHex)
        backgroundColorHex = try c.decodeIfPresent(String.self, forKey: .backgroundColorHex) ?? "#FFFFFF"
        typography = try c.decode(InvoiceTypographyStyle.self, forKey: .typography)
        cornerStyle = try c.decode(InvoiceCornerStyle.self, forKey: .cornerStyle)
        density = try c.decode(InvoiceDensity.self, forKey: .density)
        logoPosition = try c.decode(InvoiceLogoPosition.self, forKey: .logoPosition)
        backgroundStyle = try c.decodeIfPresent(InvoiceBrandBackgroundStyle.self, forKey: .backgroundStyle) ?? .solid
        headerMotif = try c.decodeIfPresent(InvoiceBrandMotif.self, forKey: .headerMotif) ?? .none
        borderStyle = try c.decodeIfPresent(InvoiceBrandBorderStyle.self, forKey: .borderStyle) ?? .none
        sourceCardTemplate = try c.decodeIfPresent(String.self, forKey: .sourceCardTemplate)
        headerStamps = try c.decodeIfPresent([BrandShapeStamp].self, forKey: .headerStamps)
        headerPhotoPath = try c.decodeIfPresent(String.self, forKey: .headerPhotoPath)
        useCardHeaderPhoto = try c.decodeIfPresent(Bool.self, forKey: .useCardHeaderPhoto) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(style, forKey: .style)
        try c.encode(primaryColorHex, forKey: .primaryColorHex)
        try c.encode(secondaryColorHex, forKey: .secondaryColorHex)
        try c.encode(backgroundColorHex, forKey: .backgroundColorHex)
        try c.encode(typography, forKey: .typography)
        try c.encode(cornerStyle, forKey: .cornerStyle)
        try c.encode(density, forKey: .density)
        try c.encode(logoPosition, forKey: .logoPosition)
        try c.encode(backgroundStyle, forKey: .backgroundStyle)
        try c.encode(headerMotif, forKey: .headerMotif)
        try c.encode(borderStyle, forKey: .borderStyle)
        try c.encodeIfPresent(sourceCardTemplate, forKey: .sourceCardTemplate)
        try c.encodeIfPresent(headerStamps, forKey: .headerStamps)
        try c.encodeIfPresent(headerPhotoPath, forKey: .headerPhotoPath)
        try c.encode(useCardHeaderPhoto, forKey: .useCardHeaderPhoto)
    }
}

public struct InvoiceTaxEngineConfig: Codable, Equatable {
    public var mode: InvoiceTaxMode
    public var rates: [InvoiceTaxRate]
    public var localizedLabel: String // e.g. "VAT", "GST"

    public static let `default` = InvoiceTaxEngineConfig(
        mode: .exclusive,
        rates: [],
        localizedLabel: "Tax"
    )

    public init(mode: InvoiceTaxMode, rates: [InvoiceTaxRate], localizedLabel: String) {
        self.mode = mode
        self.rates = rates
        self.localizedLabel = localizedLabel
    }
}

public struct InvoicePaymentConfig: Codable, Equatable {
    public var showBankBlock: Bool
    public var bankName: String
    public var iban: String
    public var bic: String
    public var showQRBlock: Bool
    public var qrPayload: String       // raw string encoded as QR image
    public var showPaymentLink: Bool
    public var paymentLinkURL: String  // e.g. "https://pay.stripe.com/xxx"
    public var accountType: BankAccountType?
    public var sortCode: String
    public var accountNumber: String
    public var routingNumber: String
    public var transitNumber: String
    public var institutionNumber: String
    public var bsb: String

    public static let `default` = InvoicePaymentConfig(
        showBankBlock: false,
        bankName: "",
        iban: "",
        bic: "",
        showQRBlock: false,
        qrPayload: "",
        showPaymentLink: false,
        paymentLinkURL: ""
    )

    public init(
        showBankBlock: Bool = false,
        bankName: String = "",
        iban: String = "",
        bic: String = "",
        showQRBlock: Bool = false,
        qrPayload: String = "",
        showPaymentLink: Bool = false,
        paymentLinkURL: String = "",
        accountType: BankAccountType? = nil,
        sortCode: String = "",
        accountNumber: String = "",
        routingNumber: String = "",
        transitNumber: String = "",
        institutionNumber: String = "",
        bsb: String = ""
    ) {
        self.showBankBlock   = showBankBlock
        self.bankName        = bankName
        self.iban            = iban
        self.bic             = bic
        self.showQRBlock     = showQRBlock
        self.qrPayload       = qrPayload
        self.showPaymentLink = showPaymentLink
        self.paymentLinkURL  = paymentLinkURL
        self.accountType     = accountType
        self.sortCode        = sortCode
        self.accountNumber   = accountNumber
        self.routingNumber   = routingNumber
        self.transitNumber   = transitNumber
        self.institutionNumber = institutionNumber
        self.bsb             = bsb
    }

    private enum CodingKeys: String, CodingKey {
        case showBankBlock, bankName, iban, bic, showQRBlock, qrPayload, showPaymentLink, paymentLinkURL
        case accountType, sortCode, accountNumber, routingNumber, transitNumber, institutionNumber, bsb
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showBankBlock = try c.decodeIfPresent(Bool.self, forKey: .showBankBlock) ?? false
        bankName = try c.decodeIfPresent(String.self, forKey: .bankName) ?? ""
        iban = try c.decodeIfPresent(String.self, forKey: .iban) ?? ""
        bic = try c.decodeIfPresent(String.self, forKey: .bic) ?? ""
        showQRBlock = try c.decodeIfPresent(Bool.self, forKey: .showQRBlock) ?? false
        qrPayload = try c.decodeIfPresent(String.self, forKey: .qrPayload) ?? ""
        showPaymentLink = try c.decodeIfPresent(Bool.self, forKey: .showPaymentLink) ?? false
        paymentLinkURL = try c.decodeIfPresent(String.self, forKey: .paymentLinkURL) ?? ""
        accountType = try c.decodeIfPresent(BankAccountType.self, forKey: .accountType)
        sortCode = try c.decodeIfPresent(String.self, forKey: .sortCode) ?? ""
        accountNumber = try c.decodeIfPresent(String.self, forKey: .accountNumber) ?? ""
        routingNumber = try c.decodeIfPresent(String.self, forKey: .routingNumber) ?? ""
        transitNumber = try c.decodeIfPresent(String.self, forKey: .transitNumber) ?? ""
        institutionNumber = try c.decodeIfPresent(String.self, forKey: .institutionNumber) ?? ""
        bsb = try c.decodeIfPresent(String.self, forKey: .bsb) ?? ""
    }
}

// MARK: - Historical Snapshot (locked on send)

public struct InvoiceDesignerSnapshot: Codable, Equatable {
    public var templateConfig: InvoiceTemplateConfig
    public var taxConfig: InvoiceTaxEngineConfig
    public var paymentConfig: InvoicePaymentConfig
    public var lockedAt: Date
    /// Frozen issuer/recipient for PDF parity when profile or client changes later.
    public var issuerPartySnapshot: InvoicePartyDetails?
    public var recipientPartySnapshot: InvoicePartyDetails?

    public init(
        templateConfig: InvoiceTemplateConfig,
        taxConfig: InvoiceTaxEngineConfig,
        paymentConfig: InvoicePaymentConfig,
        lockedAt: Date = Date(),
        issuerPartySnapshot: InvoicePartyDetails? = nil,
        recipientPartySnapshot: InvoicePartyDetails? = nil
    ) {
        self.templateConfig = templateConfig
        self.taxConfig      = taxConfig
        self.paymentConfig  = paymentConfig
        self.lockedAt       = lockedAt
        self.issuerPartySnapshot = issuerPartySnapshot
        self.recipientPartySnapshot = recipientPartySnapshot
    }
}

// MARK: - Render Context (passed to all template views at render time)

/// Pre-computed totals display passed to template views.
public struct InvoiceTotalsDisplay: Equatable {
    public var subtotal: Decimal
    public var taxLines: [TaxLineItem]
    public var grandTotal: Decimal
    public var currencyCode: String

    public struct TaxLineItem: Equatable, Identifiable {
        public var id: UUID
        public var label: String
        public var amount: Decimal
    }

    public static let zero = InvoiceTotalsDisplay(
        subtotal: 0,
        taxLines: [],
        grandTotal: 0,
        currencyCode: "USD"
    )
}

/// All data a template view needs to render — no environment objects required.
/// This guarantees ImageRenderer parity with on-screen preview.
public struct InvoiceRenderContext {
    public var invoice: StudioInvoice
    public var client: StudioClient?
    public var profile: StudioProfile
    public var settings: StudioInvoiceSettings
    public var templateConfig: InvoiceTemplateConfig
    public var taxConfig: InvoiceTaxEngineConfig
    public var paymentConfig: InvoicePaymentConfig
    public var totals: InvoiceTotalsDisplay
    /// Currency formatter captured at context-build time. Avoids @EnvironmentObject dependency.
    public var formatAmount: (Decimal) -> String
    public var issuerBlock: InvoicePartyBlockDisplay
    public var recipientBlock: InvoicePartyBlockDisplay
    public var legalFooter: InvoiceLegalFooterDisplay
    public var paymentDetailLines: [InvoicePaymentLineDisplay]
    /// Settings → Country interface locale for PDF-safe catalog strings.
    public var interfaceLocale: Locale

    public init(
        invoice: StudioInvoice,
        client: StudioClient?,
        profile: StudioProfile,
        settings: StudioInvoiceSettings,
        templateConfig: InvoiceTemplateConfig,
        taxConfig: InvoiceTaxEngineConfig,
        paymentConfig: InvoicePaymentConfig,
        totals: InvoiceTotalsDisplay,
        formatAmount: @escaping (Decimal) -> String,
        issuerBlock: InvoicePartyBlockDisplay = .empty,
        recipientBlock: InvoicePartyBlockDisplay = .empty,
        legalFooter: InvoiceLegalFooterDisplay = .hidden,
        paymentDetailLines: [InvoicePaymentLineDisplay] = [],
        interfaceLocale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) {
        self.invoice        = invoice
        self.client         = client
        self.profile        = profile
        self.settings       = settings
        self.templateConfig = templateConfig
        self.taxConfig      = taxConfig
        self.paymentConfig  = paymentConfig
        self.totals         = totals
        self.formatAmount   = formatAmount
        self.issuerBlock    = issuerBlock
        self.recipientBlock = recipientBlock
        self.legalFooter    = legalFooter
        self.paymentDetailLines = paymentDetailLines
        self.interfaceLocale = interfaceLocale
    }
}

// MARK: - Color Helpers

extension UIColor {
    /// Returns a CSS-style hex string e.g. "#5A55F5".
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(r * 255)),
            lroundf(Float(g * 255)),
            lroundf(Float(b * 255))
        )
    }
}

// MARK: - Preset Brand Palettes

public enum InvoiceColorPresets {
    public static let primary: [(name: String, hex: String)] = [
        ("Indigo",   "#5A55F5"),
        ("Ocean",    "#0B9FDA"),
        ("Emerald",  "#00C882"),
        ("Crimson",  "#FF3366"),
        ("Gold",     "#D4AF37"),
        ("Violet",   "#8B5CF6"),
        ("Slate",    "#334155"),
        ("Obsidian", "#1E293B"),
    ]

    public static let secondary: [(name: String, hex: String)] = [
        ("Deep Indigo", "#3C37B4"),
        ("Navy",        "#034078"),
        ("Forest",      "#00815C"),
        ("Berry",       "#9B1B4F"),
        ("Bronze",      "#8C6B00"),
        ("Plum",        "#5B21B6"),
        ("Graphite",    "#1E2A38"),
        ("Midnight",    "#0F172A"),
    ]
}
