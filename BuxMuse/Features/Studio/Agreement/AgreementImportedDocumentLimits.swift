//
//  AgreementImportedDocumentLimits.swift
//  BuxMuse — Pro Studio imported agreement limits (PDF / image only).
//

import Foundation

enum AgreementImportedDocumentLimits {
    /// Maximum PDF pages stored on device for an imported agreement.
    static let maxStoredPages = 50
    /// Maximum pages that can receive in-app Pencil / finger markup.
    static let maxSignablePages = 25

    static func limitsNotice(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        StudioAgreementL10n.format(
            "PDFs up to %d pages can be stored. Mark up and sign up to %d pages in BuxMuse — PDF and photos only.",
            locale: locale,
            maxStoredPages,
            maxSignablePages
        )
    }

    static func pageCountExceededMessage(pageCount: Int, locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        StudioAgreementL10n.format(
            "This PDF has %d pages. The limit is %d pages — split the file or use a shorter version.",
            locale: locale,
            pageCount,
            maxStoredPages
        )
    }

    static func signablePageRange(pageCount: Int) -> ClosedRange<Int> {
        let last = min(pageCount, maxSignablePages)
        guard last >= 1 else { return 1...1 }
        return 1...last
    }

    static func canMarkUp(pageIndex: Int, pageCount: Int) -> Bool {
        pageIndex >= 0 && pageIndex < pageCount && pageIndex < maxSignablePages
    }

    static func exceedsSignableLimit(pageCount: Int) -> Bool {
        pageCount > maxSignablePages
    }
}
