//
//  StudioAgreementTermsComposer.swift
//  BuxMuse
//

import Foundation

enum StudioAgreementTermsComposer {

    static func body(
        for clauseId: String,
        overrides: [String: String]
    ) -> String? {
        guard let clause = StudioAgreementTermsLibrary.clause(id: clauseId) else { return nil }
        let custom = overrides[clauseId]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !custom.isEmpty { return custom }
        return clause.defaultBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func composedText(
        enabledClauseIds: [String],
        overrides: [String: String],
        customText: String,
        includeDisclaimer: Bool = true
    ) -> String {
        var sections: [String] = []
        let ordered = StudioAgreementTermsLibrary.allClauses
            .filter { enabledClauseIds.contains($0.id) }

        for clause in ordered {
            guard let text = body(for: clause.id, overrides: overrides), !text.isEmpty else { continue }
            sections.append("\(clause.title)\n\(text)")
        }

        let extra = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty {
            sections.append("Additional terms\n\(extra)")
        }

        guard !sections.isEmpty else {
            if includeDisclaimer { return StudioAgreementTermsLibrary.disclaimer }
            return ""
        }

        var result = sections.joined(separator: "\n\n")
        if includeDisclaimer {
            result += "\n\n" + StudioAgreementTermsLibrary.disclaimer
        }
        return result
    }
}

extension AgreementDraft {

    public var composedTermsAndConditions: String {
        StudioAgreementTermsComposer.composedText(
            enabledClauseIds: enabledTermsClauseIds,
            overrides: termsClauseOverrides,
            customText: termsCustomText
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
