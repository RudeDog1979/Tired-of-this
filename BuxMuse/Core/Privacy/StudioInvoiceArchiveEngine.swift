//
//  StudioInvoiceArchiveEngine.swift
//  BuxMuse
//
//  Packages Simple + Pro invoice PDF/PNG exports and optional receipt photos into a ZIP.
//

import Foundation
import PDFKit
import SwiftUI
import UIKit

public struct StudioInvoiceArchiveRow: Identifiable, Hashable, Sendable {
    public enum Tier: String, Codable, Sendable {
        case simple
        case pro
    }

    public let id: UUID
    public let tier: Tier
    public let customerName: String
    public let amount: Decimal
    public let date: Date
    public let statusLabel: String
    public let hasLinkedTwin: Bool
}

public struct StudioInvoiceArchiveManifest: Codable, Sendable {
    public struct InvoiceEntry: Codable, Sendable {
        public let id: String
        public let tier: String
        public let customerName: String
        public let amount: String
        public let pdfPath: String
        public let pngPath: String
    }

    public let version: Int
    public let exportedAt: String
    public let invoices: [InvoiceEntry]
    public let receiptImages: [BuxReceiptZIPManifestEntry]?
}

public enum StudioInvoiceArchiveEngine {

    public enum ExportError: LocalizedError {
        case nothingToExport
        case writeFailed

        public var errorDescription: String? {
            switch self {
            case .nothingToExport:
                return "Select at least one invoice or include receipt photos to export."
            case .writeFailed:
                return "Could not create the invoice archive."
            }
        }
    }

    public static func simpleRows(
        simpleStore: SimpleStudioStore,
        studioStore: StudioStore
    ) -> [StudioInvoiceArchiveRow] {
        simpleStore.invoices.map { invoice in
            StudioInvoiceArchiveRow(
                id: invoice.id,
                tier: .simple,
                customerName: invoice.customerName,
                amount: invoice.amount,
                date: invoice.createdAt,
                statusLabel: invoice.status.rawValue.capitalized,
                hasLinkedTwin: studioStore.invoices.contains { $0.id == invoice.id }
            )
        }
    }

    public static func proRows(
        simpleStore: SimpleStudioStore,
        studioStore: StudioStore
    ) -> [StudioInvoiceArchiveRow] {
        studioStore.invoices.map { invoice in
            let clientName = studioStore.clients.first { $0.id == invoice.clientId }?.name ?? "Client"
            return StudioInvoiceArchiveRow(
                id: invoice.id,
                tier: .pro,
                customerName: clientName,
                amount: invoice.total,
                date: invoice.issueDate,
                statusLabel: invoice.status.rawValue.capitalized,
                hasLinkedTwin: simpleStore.invoices.contains { $0.id == invoice.id }
            )
        }
    }

    public static func hasLinkedTwin(
        tier: StudioInvoiceArchiveRow.Tier,
        id: UUID,
        simpleStore: SimpleStudioStore,
        studioStore: StudioStore
    ) -> Bool {
        switch tier {
        case .simple:
            studioStore.invoices.contains { $0.id == id }
        case .pro:
            simpleStore.invoices.contains { $0.id == id }
        }
    }

    @MainActor
    public static func exportToTemporaryZIP(
        simpleIDs: Set<UUID>,
        proIDs: Set<UUID>,
        includeReceiptPhotos: Bool,
        simpleStore: SimpleStudioStore,
        studioStore: StudioStore,
        themeManager: ThemeManager,
        appSettings: AppSettingsManager
    ) throws -> URL {
        var files: [(path: String, data: Data)] = []
        var manifestInvoices: [StudioInvoiceArchiveManifest.InvoiceEntry] = []
        var receiptManifest: [BuxReceiptZIPManifestEntry] = []

        let simpleTargets = simpleStore.invoices.filter { simpleIDs.contains($0.id) }
        for invoice in simpleTargets {
            let base = "invoices/simple/\(invoice.id.uuidString)"
            let card = simpleCardView(
                invoice: invoice,
                studioStore: studioStore,
                themeManager: themeManager,
                appSettings: appSettings
            )

            if let pdf = SimpleStudioBusinessCardPDFExporter.generatePDF(from: card.frame(width: 340)),
               let png = SimpleStudioShareHelper.renderCard(card.frame(width: 340))?.pngData() {
                let pdfPath = "\(base).pdf"
                let pngPath = "\(base).png"
                files.append((path: pdfPath, data: pdf))
                files.append((path: pngPath, data: png))
                manifestInvoices.append(
                    StudioInvoiceArchiveManifest.InvoiceEntry(
                        id: invoice.id.uuidString,
                        tier: StudioInvoiceArchiveRow.Tier.simple.rawValue,
                        customerName: invoice.customerName,
                        amount: invoice.amount.description,
                        pdfPath: pdfPath,
                        pngPath: pngPath
                    )
                )
            }
        }

        let proTargets = studioStore.invoices.filter { proIDs.contains($0.id) }
        for invoice in proTargets {
            let base = "invoices/pro/\(invoice.id.uuidString)"
            guard let pdf = proPDFData(invoice: invoice, studioStore: studioStore, appSettings: appSettings) else {
                continue
            }
            let pdfPath = "\(base).pdf"
            files.append((path: pdfPath, data: pdf))

            var pngPath = "\(base).png"
            if let png = pngFromPDF(pdf) {
                files.append((path: pngPath, data: png))
            } else {
                pngPath = ""
            }

            let clientName = studioStore.clients.first { $0.id == invoice.clientId }?.name ?? "Client"
            manifestInvoices.append(
                StudioInvoiceArchiveManifest.InvoiceEntry(
                    id: invoice.id.uuidString,
                    tier: StudioInvoiceArchiveRow.Tier.pro.rawValue,
                    customerName: clientName,
                    amount: invoice.total.description,
                    pdfPath: pdfPath,
                    pngPath: pngPath
                )
            )
        }

        if includeReceiptPhotos {
            BuxReceiptZIPExporter.appendReceiptImages(to: &files, manifest: &receiptManifest)
        }

        guard !manifestInvoices.isEmpty || !receiptManifest.isEmpty else {
            throw ExportError.nothingToExport
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let manifest = StudioInvoiceArchiveManifest(
            version: 1,
            exportedAt: stamp,
            invoices: manifestInvoices,
            receiptImages: receiptManifest.isEmpty ? nil : receiptManifest
        )
        let manifestData = try JSONEncoder().encode(manifest)
        files.append((path: "manifest.json", data: manifestData))

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("buxmuse_invoices_\(stamp).zip")
        let zipData = BuxMinimalZIPWriter.archive(files: files)
        guard !zipData.isEmpty else { throw ExportError.writeFailed }
        try zipData.write(to: zipURL, options: .atomic)
        return zipURL
    }

    @MainActor
    private static func simpleCardView(
        invoice: SimpleInvoice,
        studioStore: StudioStore,
        themeManager: ThemeManager,
        appSettings: AppSettingsManager
    ) -> SimpleInvoiceCardView {
        let businessName: String = {
            let name = studioStore.profile.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
            return SettingsStore.shared.resolvedDisplayName
        }()
        return SimpleInvoiceCardView(
            businessName: businessName,
            customerName: invoice.customerName,
            amountFormatted: appSettings.format(invoice.amount),
            description: invoice.jobDescription,
            isPaid: invoice.status == .paid,
            accent: themeManager.current.accentColor,
            locale: appSettings.interfaceLocale
        )
    }

    private static func proPDFData(
        invoice: StudioInvoice,
        studioStore: StudioStore,
        appSettings: AppSettingsManager
    ) -> Data? {
        let client = studioStore.clients.first { $0.id == invoice.clientId }
        if let snapshot = invoice.designerSnapshot {
            let ctx = InvoiceDesignerEngine.buildRenderContext(
                invoice: invoice,
                client: client,
                profile: studioStore.profile,
                settings: studioStore.invoiceSettings,
                snapshot: snapshot,
                taxProfile: studioStore.taxProfile,
                currencyCode: appSettings.selectedCurrency.id
            )
            return InvoiceDesignerEngine.generatePDF(context: ctx)
        }
        return StudioInvoicePDFRenderer.generatePDF(
            invoice: invoice,
            client: client,
            profile: studioStore.profile,
            settings: studioStore.invoiceSettings,
            taxProfile: studioStore.taxProfile,
            countryCode: appSettings.selectedCountry.id
        )
    }

    private static func pngFromPDF(_ data: Data) -> Data? {
        guard let doc = PDFDocument(data: data), let page = doc.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(bounds)
            ctx.cgContext.translateBy(x: 0, y: bounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return image.pngData()
    }
}
