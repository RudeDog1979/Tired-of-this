//
//  InvoiceTemplateViews.swift
//  BuxMuse
//
//  Three premium invoice template renderers: Modern, Minimalist, Executive.
//  All render at A4/US-Letter dimensions (612×792 pt) and are consumed by both
//  the live preview canvas and the ImageRenderer PDF pipeline.
//  No @EnvironmentObject dependencies — data flows purely through InvoiceRenderContext.
//

import SwiftUI

// MARK: - Shared A4 Constants

private enum A4 {
    static let width: CGFloat   = 612
    static let height: CGFloat  = 792
    static let margin: CGFloat  = 44
    static let contentWidth: CGFloat = width - 2 * margin
}

// MARK: - Brand sync rendering (from Pro Business Card)

private enum InvoiceBrandRendering {
    static func isDark(hex: String) -> Bool {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let val = Int(cleaned, radix: 16) else { return false }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        return (0.299 * r + 0.587 * g + 0.114 * b) < 0.45
    }

    static func headerForeground(config: InvoiceTemplateConfig) -> Color {
        switch config.style {
        case .modern, .executive:
            return .white
        case .minimalist:
            return config.secondaryColor
        }
    }

    static func usesFilledHeader(config: InvoiceTemplateConfig) -> Bool {
        config.style == .modern || config.style == .executive
    }
}

private struct InvoicePageBackground: View {
    let config: InvoiceTemplateConfig

    var body: some View {
        ZStack {
            config.backgroundColor
            switch config.backgroundStyle {
            case .solid:
                Color.clear
            case .gradient:
                LinearGradient(
                    colors: [
                        config.backgroundColor,
                        config.primaryColor.opacity(0.10),
                        config.backgroundColor
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .patternDots:
                Canvas { ctx, size in
                    let step: CGFloat = 14
                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = 0
                        while x < size.width {
                            let rect = CGRect(x: x, y: y, width: 1.6, height: 1.6)
                            ctx.fill(Path(ellipseIn: rect), with: .color(config.primaryColor.opacity(0.08)))
                            x += step
                        }
                        y += step
                    }
                }
            case .patternLines:
                Canvas { ctx, size in
                    var x: CGFloat = -size.height
                    while x < size.width + size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        ctx.stroke(path, with: .color(config.primaryColor.opacity(0.06)), lineWidth: 1)
                        x += 18
                    }
                }
            case .photo:
                LinearGradient(
                    colors: [config.backgroundColor, config.secondaryColor.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

private struct InvoiceBrandMotifOverlay: View {
    let config: InvoiceTemplateConfig

    var body: some View {
        ZStack {
            if config.useCardHeaderPhoto,
               let path = config.headerPhotoPath,
               let image = SimpleStudioScanImageStore.load(path: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.42)
                    .clipped()
            }
            if let stamps = config.headerStamps, !stamps.isEmpty {
                InvoiceBrandHeaderStampsOverlay(stamps: stamps)
            } else {
                templateMotifLayer
            }
        }
    }

    @ViewBuilder
    private var templateMotifLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let primary = config.primaryColor
            let secondary = config.secondaryColor

            switch config.headerMotif {
            case .none:
                Color.clear
            case .sideAccentBar:
                HStack(spacing: 0) {
                    primary.frame(width: max(8, w * 0.018))
                    Spacer(minLength: 0)
                }
            case .twoToneSplit:
                Path { path in
                    path.move(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w * 0.36, y: h))
                    path.closeSubpath()
                }
                .fill(primary.opacity(0.18))
            case .topGradientBand:
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [primary.opacity(0.35), primary.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: h * 0.22)
                    Spacer(minLength: 0)
                }
            case .diagonalBands:
                Canvas { ctx, size in
                    var x: CGFloat = -size.height
                    while x < size.width + size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + size.height * 0.45, y: size.height))
                        ctx.stroke(path, with: .color(primary.opacity(0.14)), lineWidth: 10)
                        x += 34
                    }
                }
            case .cornerBlocks:
                VStack {
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(primary.opacity(0.22))
                            .frame(width: w * 0.14, height: h * 0.28)
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(secondary.opacity(0.12))
                            .frame(width: w * 0.10, height: h * 0.18)
                    }
                    Spacer()
                }
                .padding(10)
            case .hexAccent:
                Path { path in
                    let cx = w * 0.84
                    let cy = h * 0.42
                    let r: CGFloat = min(w, h) * 0.12
                    for i in 0..<6 {
                        let angle = Double(i) * .pi / 3 - .pi / 2
                        let pt = CGPoint(x: cx + r * CGFloat(cos(angle)), y: cy + r * CGFloat(sin(angle)))
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                }
                .stroke(primary.opacity(0.35), lineWidth: 2.5)
            case .circleBadge:
                Circle()
                    .stroke(primary.opacity(0.28), lineWidth: 3)
                    .frame(width: h * 0.55)
                    .position(x: w * 0.82, y: h * 0.48)
            case .neonFrame:
                RoundedRectangle(cornerRadius: config.cornerStyle.radius)
                    .stroke(
                        LinearGradient(
                            colors: [primary, primary.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .padding(6)
            case .minimalRule:
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(secondary.opacity(0.18))
                        .frame(height: 1)
                        .padding(.horizontal, A4.margin * 0.5)
                        .padding(.bottom, 12)
                }
            case .geometricGrid:
                Canvas { ctx, size in
                    let step: CGFloat = 28
                    var x: CGFloat = 0
                    while x < size.width {
                        var v = Path()
                        v.move(to: CGPoint(x: x, y: 0))
                        v.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(v, with: .color(primary.opacity(0.07)), lineWidth: 0.5)
                        x += step
                    }
                    var y: CGFloat = 0
                    while y < size.height {
                        var hPath = Path()
                        hPath.move(to: CGPoint(x: 0, y: y))
                        hPath.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(hPath, with: .color(primary.opacity(0.07)), lineWidth: 0.5)
                        y += step
                    }
                }
            case .splitVertical:
                HStack(spacing: 0) {
                    primary.opacity(0.12).frame(width: w * 0.34)
                    Spacer(minLength: 0)
                }
            case .arcSweep:
                Path { path in
                    path.addArc(
                        center: CGPoint(x: w * 0.12, y: h * 1.05),
                        radius: h * 0.75,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(10),
                        clockwise: false
                    )
                }
                .fill(primary.opacity(0.12))
            case .monogramBand:
                HStack {
                    ZStack {
                        Circle().fill(primary.opacity(0.18)).frame(width: 36, height: 36)
                        Text("◆")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(primary)
                    }
                    .padding(.leading, A4.margin)
                    Spacer()
                }
            case .editorialLine:
                HStack {
                    Rectangle().fill(primary).frame(width: 28, height: 2)
                        .padding(.leading, A4.margin)
                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct InvoiceBrandHeaderBackground: View {
    let config: InvoiceTemplateConfig

    var body: some View {
        Group {
            if InvoiceBrandRendering.usesFilledHeader(config: config) {
                if config.backgroundStyle == .gradient || config.headerMotif == .topGradientBand {
                    LinearGradient(
                        colors: [config.primaryColor, config.secondaryColor.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    config.primaryColor
                }
            } else {
                config.backgroundColor
            }
        }
    }
}

private struct InvoiceBrandBorderOverlay: View {
    let config: InvoiceTemplateConfig

    var body: some View {
        Group {
            switch config.borderStyle {
            case .none:
                Color.clear
            case .thin:
                RoundedRectangle(cornerRadius: config.cornerStyle.radius)
                    .stroke(config.primaryColor.opacity(0.25), lineWidth: 1)
            case .double:
                RoundedRectangle(cornerRadius: config.cornerStyle.radius)
                    .stroke(config.primaryColor.opacity(0.35), lineWidth: 1)
                    .padding(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: config.cornerStyle.radius)
                            .stroke(config.secondaryColor.opacity(0.25), lineWidth: 0.5)
                    )
            case .accent:
                RoundedRectangle(cornerRadius: config.cornerStyle.radius)
                    .stroke(
                        LinearGradient(
                            colors: [config.primaryColor, config.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shared Sub-Views

/// Line-items table shared across templates.
private struct InvoiceLineItemsTable: View {
    let context: InvoiceRenderContext
    let headerBackground: Color
    let headerForeground: Color
    let altRowBackground: Color
    let showRowNumbers: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                if showRowNumbers {
                    Text("#")
                        .frame(width: 20, alignment: .leading)
                }
                Text("Description")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Qty")
                    .frame(width: 36, alignment: .trailing)
                Text("Rate")
                    .frame(width: 72, alignment: .trailing)
                Text("Amount")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(context.templateConfig.typography.bodyFont(size: 8, weight: .semibold))
            .foregroundColor(headerForeground)
            .padding(.horizontal, 6)
            .padding(.vertical, context.templateConfig.density.rowHeight * 0.4)
            .background(headerBackground)

            // Item rows
            ForEach(Array(context.invoice.lineItems.enumerated()), id: \.element.id) { idx, item in
                HStack(spacing: 0) {
                    if showRowNumbers {
                        Text("\(idx + 1)")
                            .frame(width: 20, alignment: .leading)
                            .buxLabelSecondary()
                    }
                    Text(item.description)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                    Text(String(format: "%.1f", item.quantity))
                        .frame(width: 36, alignment: .trailing)
                    Text(context.formatAmount(item.unitPrice))
                        .frame(width: 72, alignment: .trailing)
                    Text(context.formatAmount(item.total))
                        .frame(width: 80, alignment: .trailing)
                }
                .font(context.templateConfig.typography.bodyFont(size: 8.5))
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal, 6)
                .padding(.vertical, context.templateConfig.density.rowHeight * 0.38)
                .background(idx.isMultiple(of: 2) ? altRowBackground : Color.clear)
            }
        }
    }
}

/// Totals block (subtotal + tax lines + grand total) shared across templates.
private struct InvoiceTotalsBlock: View {
    let context: InvoiceRenderContext
    let grandTotalAccent: Color
    let style: TotalsStyle

    enum TotalsStyle { case rightAligned, fullWidth }

    var body: some View {
        VStack(spacing: 3) {
            // Subtotal
            totalsRow(
                label: "Subtotal",
                value: context.formatAmount(context.totals.subtotal),
                isBold: false,
                accent: .clear
            )
            // Tax lines
            ForEach(context.totals.taxLines) { line in
                totalsRow(
                    label: line.label,
                    value: context.formatAmount(line.amount),
                    isBold: false,
                    accent: .clear
                )
            }
            // Separator
            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(height: 0.5)
                .padding(.vertical, 3)
            // Grand total
            totalsRow(
                label: "TOTAL",
                value: context.formatAmount(context.totals.grandTotal),
                isBold: true,
                accent: grandTotalAccent
            )
        }
    }

    @ViewBuilder
    private func totalsRow(label: String, value: String, isBold: Bool, accent: Color) -> some View {
        let typography = context.templateConfig.typography
        HStack {
            if style == .fullWidth { Spacer() }
            Text(label)
                .font(typography.bodyFont(size: isBold ? 9.5 : 8.5, weight: isBold ? .bold : .regular))
                .foregroundColor(isBold ? accent : Color(UIColor.secondaryLabel))
            Spacer()
            Text(value)
                .font(typography.bodyFont(size: isBold ? 10 : 8.5, weight: isBold ? .bold : .regular))
                .foregroundColor(isBold ? accent : Color(UIColor.label))
        }
        .padding(.horizontal, isBold ? 8 : 0)
        .padding(.vertical, isBold ? 5 : 1)
        .background(isBold && accent != .clear ? accent.opacity(0.12) : Color.clear)
        .cornerRadius(4)
    }
}

/// FROM / BILL TO structured party block.
private struct InvoicePartyBlockView: View {
    let block: InvoicePartyBlockDisplay
    let accentColor: Color
    let typography: InvoiceTypographyStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !block.heading.isEmpty {
                Text(block.heading)
                    .font(typography.bodyFont(size: 7, weight: .semibold))
                    .foregroundColor(accentColor)
                    .tracking(0.8)
            }
            Text(block.title)
                .font(typography.bodyFont(size: 10, weight: .semibold))
                .foregroundColor(Color(UIColor.label))
            if let subtitle = block.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(typography.bodyFont(size: 8.5))
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
            ForEach(Array(block.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(typography.bodyFont(size: 8))
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Legal registration footer (bottom watermark text).
private struct InvoiceLegalFooterView: View {
    let footer: InvoiceLegalFooterDisplay
    let typography: InvoiceTypographyStyle

    var body: some View {
        if footer.isVisible {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(footer.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(typography.bodyFont(size: 6.5))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}

/// Payment footer block (bank, QR, link) shared across templates.
private struct InvoicePaymentFooter: View {
    let context: InvoiceRenderContext
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if context.settings.showBankDetails || context.paymentConfig.showBankBlock {
                bankBlock
            }
            HStack(alignment: .top, spacing: 16) {
                if context.paymentConfig.showQRBlock && !context.paymentConfig.qrPayload.isEmpty {
                    qrBlock
                }
                if context.paymentConfig.showPaymentLink && !context.paymentConfig.paymentLinkURL.isEmpty {
                    linkBlock
                }
            }
            if !context.invoice.notes.isEmpty {
                notesBlock
            }
        }
    }

    private var bankBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PAYMENT DETAILS")
                .font(context.templateConfig.typography.bodyFont(size: 7, weight: .semibold))
                .foregroundColor(accentColor)
                .tracking(0.8)

            if !context.paymentDetailLines.isEmpty {
                ForEach(Array(context.paymentDetailLines.enumerated()), id: \.offset) { _, line in
                    detailRow(line.label, line.value)
                }
            } else if context.paymentConfig.showBankBlock {
                if !context.paymentConfig.bankName.isEmpty {
                    detailRow("Bank", context.paymentConfig.bankName)
                }
                if !context.paymentConfig.iban.isEmpty {
                    detailRow("IBAN", context.paymentConfig.iban)
                }
                if !context.paymentConfig.bic.isEmpty {
                    detailRow("BIC / SWIFT", context.paymentConfig.bic)
                }
            } else if context.settings.showBankDetails && !context.settings.bankDetails.isEmpty {
                // Fallback: legacy freeform bank details string
                Text(context.settings.bankDetails)
                    .font(context.templateConfig.typography.bodyFont(size: 8))
                    .foregroundColor(Color(UIColor.label))
            }
        }
    }

    private var qrBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("SCAN TO PAY")
                .font(context.templateConfig.typography.bodyFont(size: 7, weight: .semibold))
                .foregroundColor(accentColor)
                .tracking(0.8)
            if let qr = InvoiceDesignerEngine.generateQRImage(from: context.paymentConfig.qrPayload, size: 56) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 56, height: 56)
            }
        }
    }

    private var linkBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PAY ONLINE")
                .font(context.templateConfig.typography.bodyFont(size: 7, weight: .semibold))
                .foregroundColor(accentColor)
                .tracking(0.8)
            Text(context.paymentConfig.paymentLinkURL)
                .font(context.templateConfig.typography.bodyFont(size: 7.5))
                .foregroundColor(accentColor)
                .underline()
                .lineLimit(2)
        }
    }

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NOTES & TERMS")
                .font(context.templateConfig.typography.bodyFont(size: 7, weight: .semibold))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .tracking(0.8)
            Text(context.invoice.notes)
                .font(context.templateConfig.typography.bodyFont(size: 8))
                .foregroundColor(Color(UIColor.label))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(context.templateConfig.typography.bodyFont(size: 7.5, weight: .semibold))
                .foregroundColor(Color(UIColor.secondaryLabel))
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(context.templateConfig.typography.bodyFont(size: 7.5))
                .foregroundColor(Color(UIColor.label))
        }
    }
}

// MARK: - 1. Modern Template

/// Bold, branded, contemporary.
/// Accent-color header band → clean line items table → highlighted grand total.
public struct ModernInvoiceTemplateView: View {
    public let context: InvoiceRenderContext

    private var primary: Color   { context.templateConfig.primaryColor }
    private var secondary: Color { context.templateConfig.secondaryColor }
    private var typo:   InvoiceTypographyStyle { context.templateConfig.typography }
    private var density: InvoiceDensity { context.templateConfig.density }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            InvoicePageBackground(config: context.templateConfig)

            VStack(alignment: .leading, spacing: 0) {

                // ── Header Band ──────────────────────────────────────
                headerBand
                    .frame(height: 88)

                // ── Bill To / Dates meta row ─────────────────────────
                metaRow
                    .padding(.horizontal, A4.margin)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                // ── Hairline ─────────────────────────────────────────
                Rectangle()
                    .fill(primary.opacity(0.18))
                    .frame(height: 0.75)
                    .padding(.horizontal, A4.margin)

                Spacer().frame(height: 10)

                // ── Line Items Table ─────────────────────────────────
                InvoiceLineItemsTable(
                    context: context,
                    headerBackground: primary,
                    headerForeground: .white,
                    altRowBackground: context.templateConfig.backgroundColor.opacity(0.6),
                    showRowNumbers: false
                )
                .padding(.horizontal, A4.margin)
                .cornerRadius(context.templateConfig.cornerStyle.radius)

                Spacer().frame(height: 14)

                // ── Totals ───────────────────────────────────────────
                InvoiceTotalsBlock(
                    context: context,
                    grandTotalAccent: secondary,
                    style: .rightAligned
                )
                .frame(width: 240, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, A4.margin)

                Spacer()

                // ── Footer ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(primary.opacity(0.15))
                        .frame(height: 0.75)
                    InvoicePaymentFooter(context: context, accentColor: secondary)
                        .padding(.horizontal, A4.margin)
                        .padding(.vertical, 10)
                    InvoiceLegalFooterView(footer: context.legalFooter, typography: typo)
                        .padding(.horizontal, A4.margin)
                        .padding(.bottom, 10)
                }
            }

            InvoiceBrandBorderOverlay(config: context.templateConfig)
        }
        .frame(width: A4.width, height: A4.height)
    }

    private var headerBand: some View {
        ZStack(alignment: .leading) {
            InvoiceBrandHeaderBackground(config: context.templateConfig)
            InvoiceBrandMotifOverlay(config: context.templateConfig)

            HStack(alignment: .center, spacing: 12) {
                if context.templateConfig.logoPosition != .none,
                   let data = context.profile.logoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 48)
                        .cornerRadius(context.templateConfig.cornerStyle.radius)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.issuerBlock.title.isEmpty ? "Your Business" : context.issuerBlock.title)
                        .font(typo.headingFont(size: 17, weight: .bold))
                        .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig))
                    if let subtitle = context.issuerBlock.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(typo.bodyFont(size: 9))
                            .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig).opacity(0.75))
                    } else if !context.profile.displayName.isEmpty {
                        Text(context.profile.displayName)
                            .font(typo.bodyFont(size: 9))
                            .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig).opacity(0.75))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(context.settings.documentLabel.uppercased())
                        .font(typo.headingFont(size: 20, weight: .black))
                        .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig))
                    Text(context.invoice.invoiceNumber)
                        .font(typo.bodyFont(size: 8.5))
                        .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig).opacity(0.8))
                }
            }
            .padding(.horizontal, A4.margin)
        }
    }

    private var metaRow: some View {
        HStack(alignment: .top, spacing: 0) {
            InvoicePartyBlockView(
                block: context.recipientBlock,
                accentColor: primary,
                typography: typo
            )
            Spacer()
            // Dates
            VStack(alignment: .trailing, spacing: 3) {
                dateRow("Issue Date", context.invoice.issueDate)
                dateRow("Due Date",   context.invoice.dueDate)
                if context.settings.showTaxID {
                    let taxLine = context.issuerBlock.lines.first { $0.hasPrefix("Tax ID:") }
                    if let taxLine {
                        Text(taxLine)
                            .font(typo.bodyFont(size: 8))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
            }
        }
    }

    private func dateRow(_ label: String, _ date: Date) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(typo.bodyFont(size: 8, weight: .medium))
                .foregroundColor(Color(UIColor.secondaryLabel))
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(typo.bodyFont(size: 8, weight: .semibold))
                .foregroundColor(Color(UIColor.label))
        }
    }
}

// MARK: - 2. Minimalist Template

/// Clean, white-space-driven, typographic hierarchy. No color blocks.
public struct MinimalistInvoiceTemplateView: View {
    public let context: InvoiceRenderContext

    private var primary: Color   { context.templateConfig.primaryColor }
    private var secondary: Color { context.templateConfig.secondaryColor }
    private var typo: InvoiceTypographyStyle { context.templateConfig.typography }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            InvoicePageBackground(config: context.templateConfig)

            VStack(alignment: .leading, spacing: 0) {

                Spacer().frame(height: 44)

                ZStack(alignment: .topLeading) {
                    if context.templateConfig.showsHeaderDecoration {
                        InvoiceBrandMotifOverlay(config: context.templateConfig)
                            .frame(height: 72)
                    }

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            if context.templateConfig.logoPosition != .none,
                               let data = context.profile.logoData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 32)
                            }
                            Text(context.issuerBlock.title.isEmpty ? "Your Business" : context.issuerBlock.title)
                                .font(typo.headingFont(size: 22, weight: .light))
                                .foregroundColor(secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(context.settings.documentLabel.uppercased())
                                .font(typo.bodyFont(size: 9, weight: .semibold))
                                .foregroundColor(primary)
                                .tracking(2.5)
                            Text(context.invoice.invoiceNumber)
                                .font(typo.headingFont(size: 13))
                                .foregroundColor(secondary)
                        }
                    }
                    .padding(.horizontal, A4.margin)
                }
                .frame(height: context.templateConfig.showsHeaderDecoration ? 72 : nil, alignment: .bottom)

                Spacer().frame(height: 20)
                thinRule
                Spacer().frame(height: 14)

                // ── Meta: client + dates ─────────────────────────────
                HStack(alignment: .top) {
                    InvoicePartyBlockView(
                        block: context.recipientBlock,
                        accentColor: secondary,
                        typography: typo
                    )
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        minDateRow("Issued", context.invoice.issueDate)
                        minDateRow("Due",    context.invoice.dueDate)
                    }
                }
                .padding(.horizontal, A4.margin)

                Spacer().frame(height: 18)
                thinRule
                Spacer().frame(height: 6)

                // ── Column headers ───────────────────────────────────
                HStack(spacing: 0) {
                    Text("Description")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Qty")
                        .frame(width: 36, alignment: .trailing)
                    Text("Rate")
                        .frame(width: 72, alignment: .trailing)
                    Text("Amount")
                        .frame(width: 80, alignment: .trailing)
                }
                .font(typo.bodyFont(size: 7.5, weight: .semibold))
                .foregroundColor(primary) // Use primary color for table headers
                .tracking(0.4)
                .padding(.horizontal, A4.margin)
                .padding(.vertical, 4)

                thinRule

                // ── Items ────────────────────────────────────────────
                ForEach(context.invoice.lineItems) { item in
                    HStack(spacing: 0) {
                        Text(item.description)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                        Text(String(format: "%.1f", item.quantity))
                            .frame(width: 36, alignment: .trailing)
                        Text(context.formatAmount(item.unitPrice))
                            .frame(width: 72, alignment: .trailing)
                        Text(context.formatAmount(item.total))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(typo.bodyFont(size: 8.5))
                    .foregroundColor(Color(UIColor.label))
                    .padding(.horizontal, A4.margin)
                    .padding(.vertical, context.templateConfig.density.rowHeight * 0.35)
                    Rectangle()
                        .fill(secondary.opacity(0.1)) // Subtle tint for row separators
                        .frame(height: 0.5)
                        .padding(.horizontal, A4.margin)
                }

                Spacer().frame(height: 14)
                thinRule
                Spacer().frame(height: 10)

                // ── Totals ───────────────────────────────────────────
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(context.totals.taxLines) { line in
                        minTotalsRow(label: line.label, value: context.formatAmount(line.amount), bold: false)
                    }
                    minTotalsRow(label: "Subtotal", value: context.formatAmount(context.totals.subtotal), bold: false)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 0.5)
                        .padding(.vertical, 4)
                    minTotalsRow(label: "TOTAL", value: context.formatAmount(context.totals.grandTotal), bold: true)
                }
                .padding(.horizontal, A4.margin)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()

                // ── Footer ───────────────────────────────────────────
                thinRule
                InvoicePaymentFooter(context: context, accentColor: secondary)
                    .padding(.horizontal, A4.margin)
                    .padding(.vertical, 12)
                InvoiceLegalFooterView(footer: context.legalFooter, typography: typo)
                    .padding(.horizontal, A4.margin)
                    .padding(.bottom, 12)
                Spacer().frame(height: 12)
            }

            InvoiceBrandBorderOverlay(config: context.templateConfig)
        }
        .frame(width: A4.width, height: A4.height)
    }

    private var thinRule: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: 0.5)
            .padding(.horizontal, A4.margin)
    }

    private func minDateRow(_ label: String, _ date: Date) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(typo.bodyFont(size: 7.5))
                .foregroundColor(secondary) // Use secondary (accent) color
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(typo.bodyFont(size: 8, weight: .medium))
                .foregroundColor(Color(UIColor.label))
        }
    }

    private func minTotalsRow(label: String, value: String, bold: Bool) -> some View {
        HStack(spacing: 24) {
            Text(label)
                .font(typo.bodyFont(size: bold ? 9.5 : 8, weight: bold ? .bold : .regular))
                .foregroundColor(bold ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
            Text(value)
                .font(typo.bodyFont(size: bold ? 10 : 8, weight: bold ? .bold : .regular))
                .foregroundColor(Color(UIColor.label))
        }
    }
}

// MARK: - 3. Executive Template

/// Corporate, dual-column, premium feel.
/// Full-width accent header banner + From/BillTo two-column + alternating rows.
public struct ExecutiveInvoiceTemplateView: View {
    public let context: InvoiceRenderContext

    private var primary: Color   { context.templateConfig.primaryColor }
    private var secondary: Color { context.templateConfig.secondaryColor }
    private var typo: InvoiceTypographyStyle { context.templateConfig.typography }
    private var density: InvoiceDensity { context.templateConfig.density }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            InvoicePageBackground(config: context.templateConfig)

            VStack(alignment: .leading, spacing: 0) {

                // ── Full-width header banner ──────────────────────────
                executiveBanner
                    .frame(height: 110)

                // ── From / Bill To two-column ─────────────────────────
                HStack(alignment: .top, spacing: 0) {
                    InvoicePartyBlockView(
                        block: context.issuerBlock,
                        accentColor: primary,
                        typography: typo
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, A4.margin)
                    .padding(.vertical, 14)

                    Rectangle()
                        .fill(primary.opacity(0.15))
                        .frame(width: 0.75)

                    InvoicePartyBlockView(
                        block: context.recipientBlock,
                        accentColor: primary,
                        typography: typo
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, A4.margin)
                    .padding(.vertical, 14)
                }
                .background(secondary.opacity(0.04))

                Rectangle()
                    .fill(primary.opacity(0.12))
                    .frame(height: 0.75)

                Spacer().frame(height: 8)

                // ── Line Items Table ─────────────────────────────────
                InvoiceLineItemsTable(
                    context: context,
                    headerBackground: secondary.opacity(0.9),
                    headerForeground: .white,
                    altRowBackground: secondary.opacity(0.06),
                    showRowNumbers: true
                )
                .padding(.horizontal, A4.margin)

                Spacer().frame(height: 10)

                // ── Grand Total banner ────────────────────────────────
                grandTotalBanner

                Spacer()

                // ── Footer ───────────────────────────────────────────
                Rectangle()
                    .fill(primary.opacity(0.10))
                    .frame(height: 0.75)

                InvoicePaymentFooter(context: context, accentColor: primary)
                    .padding(.horizontal, A4.margin)
                    .padding(.vertical, 10)
                InvoiceLegalFooterView(footer: context.legalFooter, typography: typo)
                    .padding(.horizontal, A4.margin)
                    .padding(.bottom, 12)

                Spacer().frame(height: 8)
            }

            InvoiceBrandBorderOverlay(config: context.templateConfig)
        }
        .frame(width: A4.width, height: A4.height)
    }

    private var executiveBanner: some View {
        ZStack {
            InvoiceBrandHeaderBackground(config: context.templateConfig)
            if context.templateConfig.backgroundStyle == .gradient || context.templateConfig.headerMotif == .topGradientBand {
                LinearGradient(
                    colors: [primary, secondary.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            InvoiceBrandMotifOverlay(config: context.templateConfig)

            HStack(alignment: .center, spacing: 14) {
                if context.templateConfig.logoPosition != .none,
                   let data = context.profile.logoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 52)
                        .cornerRadius(context.templateConfig.cornerStyle.radius)
                        .overlay(
                            RoundedRectangle(cornerRadius: context.templateConfig.cornerStyle.radius)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.profile.businessName.isEmpty ? "Your Business" : context.profile.businessName)
                        .font(typo.headingFont(size: 18, weight: .bold))
                        .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig))
                    if !context.profile.displayName.isEmpty {
                        Text(context.profile.displayName)
                            .font(typo.bodyFont(size: 8.5))
                            .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig).opacity(0.7))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(context.settings.documentLabel.uppercased())
                        .font(typo.headingFont(size: 16, weight: .black))
                        .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig))
                        .tracking(1.5)
                    Text(context.invoice.invoiceNumber)
                        .font(typo.bodyFont(size: 8, weight: .semibold))
                        .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig).opacity(0.8))
                    Rectangle()
                        .fill(InvoiceBrandRendering.headerForeground(config: context.templateConfig).opacity(0.3))
                        .frame(height: 0.5)
                    HStack(spacing: 12) {
                        Text("Issued: \(context.invoice.issueDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(typo.bodyFont(size: 7.5))
                            .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig).opacity(0.8))
                        Text("Due: \(context.invoice.dueDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(typo.bodyFont(size: 7.5, weight: .semibold))
                            .foregroundColor(InvoiceBrandRendering.headerForeground(config: context.templateConfig))
                    }
                }
            }
            .padding(.horizontal, A4.margin)
        }
    }

    private var grandTotalBanner: some View {
        HStack {
            // Subtotal + tax breakdown
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subtotal")
                        .font(typo.bodyFont(size: 7.5))
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Text(context.formatAmount(context.totals.subtotal))
                        .font(typo.bodyFont(size: 9, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                }
                ForEach(context.totals.taxLines) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.label)
                            .font(typo.bodyFont(size: 7.5))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        Text(context.formatAmount(line.amount))
                            .font(typo.bodyFont(size: 9, weight: .semibold))
                            .foregroundColor(Color(UIColor.label))
                    }
                }
            }
            .padding(.leading, A4.margin)
            .padding(.vertical, 10)

            Spacer()

            // Grand total accent block
            HStack(spacing: 10) {
                Text("TOTAL DUE")
                    .font(typo.bodyFont(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(1)
                Text(context.formatAmount(context.totals.grandTotal))
                    .font(typo.headingFont(size: 15, weight: .black))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(primary)
        }
        .background(primary.opacity(0.07))
    }
}
