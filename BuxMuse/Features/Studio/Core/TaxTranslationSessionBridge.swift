//
//  TaxTranslationSessionBridge.swift
//  BuxMuse
//
//  Hosts Apple TranslationSession via SwiftUI `.translationTask` (required on iOS 18).
//

import Combine
import SwiftUI
import Translation

@MainActor
final class TaxTranslationSessionBridge: ObservableObject {
    static let shared = TaxTranslationSessionBridge()

    @Published private(set) var configuration: TranslationSession.Configuration?
    private var pending: [PendingJob] = []
    private var targetTag: String?

    private struct PendingJob {
        let preset: TaxInfo
        let catalogUpdatedAt: String?
        let interfaceLocale: Locale
        let continuation: CheckedContinuation<TaxLocalizedPresetResult, Never>
    }

    private init() {}

    func localizedPreset(
        _ preset: TaxInfo,
        catalogUpdatedAt: String?,
        interfaceLocale: Locale
    ) async -> TaxLocalizedPresetResult {
        guard TaxPresetTranslator.translationTargetTag(for: interfaceLocale) != nil else {
            return TaxLocalizedPresetResult(preset: preset, usedEnglishFallback: false)
        }

        return await withCheckedContinuation { continuation in
            pending.append(
                PendingJob(
                    preset: preset,
                    catalogUpdatedAt: catalogUpdatedAt,
                    interfaceLocale: interfaceLocale,
                    continuation: continuation
                )
            )
            let tag = TaxPresetTranslator.translationTargetTag(for: interfaceLocale)
            targetTag = tag
            if configuration == nil, let tag {
                configuration = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: tag)
                )
            } else {
                configuration?.invalidate()
            }
        }
    }

    fileprivate func runPending(using session: TranslationSession) async {
        let jobs = pending
        pending.removeAll()
        for job in jobs {
            let result = await TaxPresetTranslator.localizedPreset(
                job.preset,
                catalogUpdatedAt: job.catalogUpdatedAt,
                interfaceLocale: job.interfaceLocale,
                session: session
            )
            job.continuation.resume(returning: result)
        }
    }
}

extension TaxPresetTranslator {
    @MainActor
    static func localizedPreset(
        _ preset: TaxInfo,
        catalogUpdatedAt: String?,
        interfaceLocale: Locale
    ) async -> TaxLocalizedPresetResult {
        await TaxTranslationSessionBridge.shared.localizedPreset(
            preset,
            catalogUpdatedAt: catalogUpdatedAt,
            interfaceLocale: interfaceLocale
        )
    }
}

/// Invisible host — attach once near the app root (e.g. Studio shell).
struct TaxTranslationSessionBridgeView: View {
    @ObservedObject private var bridge = TaxTranslationSessionBridge.shared

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(bridge.configuration) { session in
                await bridge.runPending(using: session)
            }
    }
}
