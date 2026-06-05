//
//  StudioAgreementPDFRenderer.swift
//  BuxMuse
//
//  UIKit PDF layout (iOS 18+). No iOS 26-only APIs.
//

import UIKit

enum StudioAgreementPDFRenderer {

    static func generatePDF(
        draft: AgreementDraft,
        clientName: String?,
        projectName: String?,
        providerName: String?,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> Data? {
        func L(_ key: String) -> String {
            BuxCatalogLabel.string(key, locale: locale)
        }

        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
        let headingFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let metaFont = UIFont.systemFont(ofSize: 10, weight: .medium)

        var y: CGFloat = margin

        return renderer.pdfData { context in
            context.beginPage()
            y = margin

            func drawLine(_ text: String, font: UIFont, color: UIColor = .black, extraSpacing: CGFloat = 6) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let maxSize = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
                let measured = (text as NSString).boundingRect(
                    with: maxSize,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                let rect = CGRect(x: margin, y: y, width: contentWidth, height: ceil(measured.height))
                (text as NSString).draw(in: rect, withAttributes: attrs)
                y = rect.maxY + extraSpacing
            }

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    context.beginPage()
                    y = margin
                }
            }

            drawLine(draft.title, font: titleFont, extraSpacing: 10)
            var meta: [String] = []
            if let clientName, !clientName.isEmpty {
                meta.append("\(L("Client")): \(clientName)")
            }
            if let projectName, !projectName.isEmpty {
                meta.append("\(L("Project")): \(projectName)")
            }
            if let providerName, !providerName.isEmpty {
                meta.append("\(L("Provider")): \(providerName)")
            }
            meta.append("\(L("Status")): \(L(draft.statusDisplayLabel))")
            drawLine(meta.joined(separator: " · "), font: metaFont, color: .darkGray, extraSpacing: 16)

            func section(_ heading: String, body: String) {
                let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                ensureSpace(80)
                drawLine(heading.uppercased(), font: headingFont, color: .darkGray, extraSpacing: 4)
                drawLine(trimmed, font: bodyFont, extraSpacing: 14)
            }

            section(L("Scope"), body: draft.scopeBullets)
            section(L("Deliverables"), body: draft.deliverables)
            section(L("Out of scope"), body: draft.outOfScope)
            section(L("Payment"), body: draft.paymentAmountNotes)
            section(L("Payment terms"), body: draft.paymentTerms)
            section(L("Timeline"), body: draft.timelineNotes)
            if draft.hasTermsContent {
                section(
                    L("Terms & conditions"),
                    body: draft.composedTermsAndConditions(locale: locale)
                )
            }

            if !draft.signOffName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let f = DateFormatter()
                f.locale = locale
                f.dateStyle = .medium
                f.timeStyle = .none
                let dateStr = draft.signOffDate.map { f.string(from: $0) } ?? "—"
                section(L("Approval"), body: "\(draft.signOffName) · \(dateStr)")
            }

            ensureSpace(200)
            drawLine(L("Signatures"), font: headingFont, color: .darkGray, extraSpacing: 12)

            let sigWidth = (contentWidth - 16) / 2
            let sigHeight: CGFloat = 72

            func drawSignatureBlock(
                label: String,
                png: Data?,
                signedAt: Date?,
                x: CGFloat
            ) {
                let frame = CGRect(x: x, y: y, width: sigWidth, height: sigHeight + 28)
                let boxRect = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: sigHeight)
                UIColor(white: 0.96, alpha: 1).setFill()
                UIBezierPath(roundedRect: boxRect, cornerRadius: 6).fill()
                UIColor.lightGray.setStroke()
                UIBezierPath(roundedRect: boxRect, cornerRadius: 6).stroke()

                if let png, let image = UIImage(data: png) {
                    let inset: CGFloat = 6
                    let inner = boxRect.insetBy(dx: inset, dy: inset)
                    let scale = min(inner.width / image.size.width, inner.height / image.size.height)
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let origin = CGPoint(
                        x: inner.midX - size.width / 2,
                        y: inner.midY - size.height / 2
                    )
                    image.draw(in: CGRect(origin: origin, size: size))
                } else {
                    let placeholder = L("Not signed")
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.italicSystemFont(ofSize: 10),
                        .foregroundColor: UIColor.gray
                    ]
                    let size = (placeholder as NSString).size(withAttributes: attrs)
                    (placeholder as NSString).draw(
                        at: CGPoint(
                            x: boxRect.midX - size.width / 2,
                            y: boxRect.midY - size.height / 2
                        ),
                        withAttributes: attrs
                    )
                }

                var caption = label
                if let signedAt {
                    let when = DateFormatter.localizedString(from: signedAt, dateStyle: .medium, timeStyle: .none)
                    caption += " · \(when)"
                }
                let capAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: UIColor.darkGray
                ]
                (caption as NSString).draw(
                    at: CGPoint(x: frame.minX, y: boxRect.maxY + 6),
                    withAttributes: capAttrs
                )
            }

            drawSignatureBlock(
                label: L("Client"),
                png: draft.clientSignaturePNG,
                signedAt: draft.clientSignedAt,
                x: margin
            )
            let providerLabel = draft.providerSignatoryName.isEmpty ? L("Provider") : draft.providerSignatoryName
            drawSignatureBlock(
                label: providerLabel,
                png: draft.providerSignaturePNG,
                signedAt: draft.providerSignedAt,
                x: margin + sigWidth + 16
            )
            y += sigHeight + 40

            ensureSpace(40)
            let footer = draft.hasClientApprovalProof
                ? L("On-device agreement record · BuxMuse Studio")
                : L("Draft · BuxMuse Studio")
            drawLine(footer, font: metaFont, color: .gray, extraSpacing: 0)
        }
    }

    static func temporaryFileURL(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
