//
//  StudioAgreementTermsComposer.swift
//  BuxMuse
//

import Foundation

enum StudioAgreementTermsComposer {

    static func body(
        for clauseId: String,
        overrides: [String: String],
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> String? {
        guard let clause = StudioAgreementTermsLibrary.clause(id: clauseId) else { return nil }
        let custom = overrides[clauseId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !custom.isEmpty { return custom }
        return clause.catalogDefaultBody(locale: locale).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func composedText(
        enabledClauseIds: [String],
        overrides: [String: String],
        customText: String,
        includeDisclaimer: Bool = true,
        locale: Locale = BuxInterfaceLocale.currentInterfaceLocale
    ) -> String {
        var sections: [String] = []
        let ordered = StudioAgreementTermsLibrary.allClauses
            .filter { enabledClauseIds.contains($0.id) }

        for clause in ordered {
            guard let text = body(for: clause.id, overrides: overrides, locale: locale), !text.isEmpty else { continue }
            sections.append("\(clause.catalogTitle(locale: locale))\n\(text)")
        }

        let extra = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty {
            sections.append(
                "\(BuxCatalogLabel.string("Additional terms", locale: locale))\n\(extra)"
            )
        }

        guard !sections.isEmpty else {
            if includeDisclaimer {
                return BuxCatalogLabel.string(StudioAgreementTermsLibrary.disclaimer, locale: locale)
            }
            return ""
        }

        var result = sections.joined(separator: "\n\n")
        if includeDisclaimer {
            result += "\n\n" + BuxCatalogLabel.string(StudioAgreementTermsLibrary.disclaimer, locale: locale)
        }
        return result
    }
}

extension AgreementDraft {

    public func composedTermsAndConditions(locale: Locale = BuxInterfaceLocale.currentInterfaceLocale) -> String {
        StudioAgreementTermsComposer.composedText(
            enabledClauseIds: enabledTermsClauseIds,
            overrides: termsClauseOverrides,
            customText: termsCustomText,
            locale: locale
        )
    }

    public var hasTermsContent: Bool {
        !enabledTermsClauseIds.isEmpty
            || !termsCustomText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public mutating func applyTermsPack(_ pack: StudioAgreementTermsPack, replace: Bool) {
        let ids = StudioAgreementTermsLibrary.clauseIds(for: pack)
        if replace {
            enabledTermsClauseIds = ids
        } else {
            var set = Set(enabledTermsClauseIds)
            set.formUnion(ids)
            enabledTermsClauseIds = StudioAgreementTermsLibrary.allClauses
                .map(\.id)
                .filter { set.contains($0) }
        }
    }

    @MainActor
    public mutating func applyDefaultTermsFromSettings() {
        let settings = SettingsStore.shared
        if enabledTermsClauseIds.isEmpty {
            enabledTermsClauseIds = settings.agreementDefaultEnabledClauseIds
        }
        if termsCustomText.isEmpty, !settings.agreementDefaultCustomTerms.isEmpty {
            termsCustomText = settings.agreementDefaultCustomTerms
        }
    }
}
