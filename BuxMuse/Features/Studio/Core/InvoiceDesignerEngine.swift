//
//  InvoiceDesignerEngine.swift
//  BuxMuse
//
//  Observable engine for the Invoice Designer Hub.
//  Handles live-math, defaults loading, snapshot building, and PDF generation.
//  Does NOT interfere with StudioBrain's global tax calculations.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Invoice Designer Engine

@MainActor
public final class InvoiceDesignerEngine: ObservableObject {

    // MARK: Published State
    @Published public var templateConfig: InvoiceTemplateConfig = .default
    @Published public var taxConfig: InvoiceTaxEngineConfig     = .default
    @Published public var paymentConfig: InvoicePaymentConfig   = .default
    @Published public var currentLineItems: [StudioInvoiceLineItem] = []
    @Published public var totalsDisplay: InvoiceTotalsDisplay   = .zero
    @Published public var isConfigured: Bool = false

    private var clientRegionCode: String?
    private var taxLocale: Locale = .current

    // MARK: Init (parameterless for @StateObject compatibility)
    public init() {}

    // MARK: - Bootstrap

    /// Called from `StudioInvoiceEditorView.onAppear`.
    public func loadDefaults(
        settings: StudioInvoiceSettings,
        taxProfile: StudioTaxProfile,
        existingSnapshot: InvoiceDesignerSnapshot?,
        lineItems: [StudioInvoiceLineItem] = [],
        clientRegionCode: String? = nil,
        locale: Locale = .current
    ) {
        self.clientRegionCode = clientRegionCode
        self.taxLocale = locale
        if let snap = existingSnapshot {
            // Restore from historical snapshot (editing a previously designed invoice)
            templateConfig = snap.templateConfig
            taxConfig      = snap.taxConfig
            paymentConfig  = snap.paymentConfig
        } else {
            // Seed from global settings
            templateConfig = settings.defaultTemplateConfig ?? .default

            taxConfig = InvoiceTaxProfileResolver.config(
                taxProfile: taxProfile,
                settings: settings,
                source: settings.defaultInvoiceTaxSource,
                clientRegionCode: clientRegionCode,
                locale: locale
            )

            // Seed payment config from settings bank details
            var pConfig = settings.defaultPaymentConfig ?? .default
            if settings.showBankDetails && !settings.bankDetails.isEmpty {
                pConfig.showBankBlock = true
                // Legacy bank details are a freeform string — put it in bankName for display
                pConfig.bankName = settings.bankDetails
            }
            paymentConfig = pConfig
        }

        currentLineItems = lineItems
        isConfigured     = true
        recomputeTotals()
    }

    /// Sync line items whenever the editor changes them.
    public func updateLineItems(_ items: [StudioInvoiceLineItem]) {
        currentLineItems = items
        recomputeTotals()
    }

    /// Re-applies tax lines from Tax Profile, custom defaults, or clears tax.
    public func applyTaxSource(
        _ source: InvoiceTaxSource,
        taxProfile: StudioTaxProfile,
        settings: StudioInvoiceSettings,
        clientRegionCode: String? = nil,
        locale: Locale? = nil
    ) {
        if let clientRegionCode { self.clientRegionCode = clientRegionCode }
        if let locale { self.taxLocale = locale }
        taxConfig = InvoiceTaxProfileResolver.config(
            taxProfile: taxProfile,
            settings: settings,
            source: source,
            existingRates: source == .custom ? taxConfig.rates : [],
            clientRegionCode: self.clientRegionCode,
            locale: self.taxLocale
        )
        recomputeTotals()
    }

    public func updateClientRegion(_ code: String?) {
        clientRegionCode = code
    }

    // MARK: - Math Engine

    /// Recomputes `totalsDisplay` from current state. Decimal-precise, no Double money math.
    public func recomputeTotals() {
        totalsDisplay = Self.computeTotals(
            items: currentLineItems,
            taxConfig: taxConfig,
            currencyCode: totalsDisplay.currencyCode
        )
    }

    public static func computeTotals(
        items: [StudioInvoiceLineItem],
        taxConfig: InvoiceTaxEngineConfig,
        currencyCode: String
    ) -> InvoiceTotalsDisplay {

        let subtotalAll = items.reduce(Decimal(0)) { $0 + $1.total }
        let weightedTaxableBase = InvoiceLineTaxMath.weightedTaxableSum(items: items)

        var taxLines: [InvoiceTotalsDisplay.TaxLineItem] = []
        var runningTotal: Decimal = subtotalAll

        if taxConfig.mode == .exclusive {
            for rate in taxConfig.rates {
                let base = rate.isCompounding ? runningTotal : weightedTaxableBase
                let amount = (base * rate.percentage / 100).rounded(scale: 2)
                taxLines.append(.init(id: rate.id, label: "\(rate.label) \(rate.percentage)%", amount: amount))
                runningTotal += amount
            }
        } else {
            for rate in taxConfig.rates {
                let grossBase = rate.isCompounding ? runningTotal : weightedTaxableBase
                let divisor = 1 + rate.percentage / 100
                let extracted = (grossBase - grossBase / divisor).rounded(scale: 2)
                taxLines.append(.init(id: rate.id, label: "\(rate.label) \(rate.percentage)% (incl.)", amount: extracted))
            }
            runningTotal = subtotalAll
        }

        return InvoiceTotalsDisplay(
            subtotal:     subtotalAll,
            taxLines:     taxLines,
            grandTotal:   runningTotal,
            currencyCode: currencyCode
        )
    }

    // MARK: - Snapshot

    /// Builds a Codable snapshot of the current design state.
    public func buildSnapshot(
        issuerParty: InvoicePartyDetails? = nil,
        recipientParty: InvoicePartyDetails? = nil
    ) -> InvoiceDesignerSnapshot {
        InvoiceDesignerSnapshot(
            templateConfig: templateConfig,
            taxConfig:      taxConfig,
            paymentConfig:  paymentConfig,
            lockedAt:       Date(),
            issuerPartySnapshot: issuerParty,
            recipientPartySnapshot: recipientParty
        )
    }

    // MARK: - Render Context Builder

    public func buildRenderContext(
        invoice: StudioInvoice,
        client: StudioClient?,
        profile: StudioProfile,
        settings: StudioInvoiceSettings,
        taxProfile: StudioTaxProfile,
        currencyCode: String,
        snapshot: InvoiceDesignerSnapshot? = nil,
        autoDetectBankType: Bool = true,
        bankTypeOverride: BankAccountType? = nil,
        interfaceLocale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> InvoiceRenderContext {
        let formatter = Self.makeCurrencyFormatter(code: currencyCode)
        let display   = Self.computeTotals(
            items: invoice.lineItems,
            taxConfig: taxConfig,
            currencyCode: currencyCode
        )
        return InvoicePartyEngine.enrichRenderContext(
            invoice: invoice,
            client: client,
            profile: profile,
            settings: settings,
            taxProfile: taxProfile,
            templateConfig: templateConfig,
            taxConfig: taxConfig,
            paymentConfig: paymentConfig,
            totals: display,
            formatAmount: { formatter.string(from: NSDecimalNumber(decimal: $0)) ?? "\(currencyCode) \($0)" },
            snapshotIssuer: snapshot?.issuerPartySnapshot,
            snapshotRecipient: snapshot?.recipientPartySnapshot,
            countryCode: profile.countryCode.isEmpty ? currencyCode : profile.countryCode,
            autoDetectBankType: autoDetectBankType,
            manualOverride: bankTypeOverride,
            interfaceLocale: interfaceLocale
        )
    }

    /// Build a render context directly from a snapshot (for historical PDF re-exports).
    public static func buildRenderContext(
        invoice: StudioInvoice,
        client: StudioClient?,
        profile: StudioProfile,
        settings: StudioInvoiceSettings,
        snapshot: InvoiceDesignerSnapshot,
        taxProfile: StudioTaxProfile,
        currencyCode: String,
        autoDetectBankType: Bool = true,
        bankTypeOverride: BankAccountType? = nil,
        interfaceLocale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> InvoiceRenderContext {
        let formatter = makeCurrencyFormatter(code: currencyCode)
        let display   = computeTotals(
            items: invoice.lineItems,
            taxConfig: snapshot.taxConfig,
            currencyCode: currencyCode
        )
        return InvoicePartyEngine.enrichRenderContext(
            invoice: invoice,
            client: client,
            profile: profile,
            settings: settings,
            taxProfile: taxProfile,
            templateConfig: snapshot.templateConfig,
            taxConfig: snapshot.taxConfig,
            paymentConfig: snapshot.paymentConfig,
            totals: display,
            formatAmount: { formatter.string(from: NSDecimalNumber(decimal: $0)) ?? "\(currencyCode) \($0)" },
            snapshotIssuer: snapshot.issuerPartySnapshot,
            snapshotRecipient: snapshot.recipientPartySnapshot,
            countryCode: profile.countryCode,
            autoDetectBankType: autoDetectBankType,
            manualOverride: bankTypeOverride,
            interfaceLocale: interfaceLocale
        )
    }

    // MARK: - PDF Generation (ImageRenderer, requires @MainActor)

    /// Generates a PDF from the designer context. Uses ImageRenderer for pixel-perfect
    /// visual parity with the on-screen preview canvas. Requires iOS 16+.
    public static func generatePDF(context: InvoiceRenderContext) -> Data {
        let pageW: CGFloat = 612
        let pageH: CGFloat = 792

        let templateView = InvoiceTemplateDispatcher.view(for: context)
            .frame(width: pageW, height: pageH)
            .background(Color.white)

        let renderer  = ImageRenderer(content: templateView)
        renderer.proposedSize = ProposedViewSize(width: pageW, height: pageH)

        let pdfData = NSMutableData()
        renderer.render { size, renderContext in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            
            pdfContext.beginPDFPage(nil)
            // Render the SwiftUI view into the PDF context (vector graphics)
            renderContext(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }

        return pdfData as Data
    }

    // MARK: - QR Code Generation

    /// Generates a QR code UIImage using on-device CIFilter (zero dependencies).
    public static func generateQRImage(from string: String, size: CGFloat = 120) -> UIImage? {
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = string.data(using: .ascii),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }
        let scale     = size / ciImage.extent.width
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaled    = ciImage.transformed(by: transform)
        return UIImage(ciImage: scaled)
    }

    // MARK: - Private Helpers

    private static func makeCurrencyFormatter(code: String) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle    = .currency
        f.currencyCode   = code
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }
}

// MARK: - Line tax math (Phase D)

public enum InvoiceLineTaxMath {
    /// Per-line tax weighting — standard 100%, reduced 50%, exempt/zero 0%.
    public static func weightedTaxableSum(items: [StudioInvoiceLineItem]) -> Decimal {
        items.reduce(Decimal(0)) { sum, item in
            sum + item.total * item.effectiveTaxMultiplier
        }
    }
}

// MARK: - Decimal rounding helper

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var copy   = self
        NSDecimalRound(&result, &copy, scale, .bankers)
        return result
    }
}

// MARK: - Template Dispatcher (resolves style → concrete view)

/// Dispatches to the correct template SwiftUI view based on templateConfig.style.
/// Used by both the preview canvas and PDF generator — single source of truth.
public enum InvoiceTemplateDispatcher {
    @ViewBuilder
    public static func view(for context: InvoiceRenderContext) -> some View {
        switch context.templateConfig.style {
        case .modern:
            ModernInvoiceTemplateView(context: context)
        case .minimalist:
            MinimalistInvoiceTemplateView(context: context)
        case .executive:
            ExecutiveInvoiceTemplateView(context: context)
        }
    }
}
