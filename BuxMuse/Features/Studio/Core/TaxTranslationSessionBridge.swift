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
    private var pending: [PendingWork] = []
    private var configurationKey: String?

    private enum PendingWork {
        case preset(PresetJob)
        case text(TextJob)
    }

    private struct PresetJob {
        let preset: TaxInfo
        let catalogUpdatedAt: String?
        let interfaceLocale: Locale
        let continuation: CheckedContinuation<TaxLocalizedPresetResult, Never>
    }

    private struct TextJob {
        let text: String
        let sourceTag: String
        let targetTag: String
        let continuation: CheckedContinuation<String, Never>
    }

    private init() {}

    func localizedPreset(
        _ preset: TaxInfo,
        catalogUpdatedAt: String?,
        interfaceLocale: Locale
    ) async -> TaxLocalizedPresetResult {
        guard TaxPresetTranslator.translationTargetTag(for: interfaceLocale) != nil else {
            configuration = nil
            configurationKey = nil
            return TaxLocalizedPresetResult(preset: preset, usedEnglishFallback: false)
        }

        return await withCheckedContinuation { continuation in
            pending.append(
                .preset(
                    PresetJob(
                        preset: preset,
                        catalogUpdatedAt: catalogUpdatedAt,
                        interfaceLocale: interfaceLocale,
                        continuation: continuation
                    )
                )
            )
            if let tag = TaxPresetTranslator.translationTargetTag(for: interfaceLocale) {
                prepareConfiguration(sourceTag: TaxPresetTranslator.canonicalSourceTag, targetTag: tag)
            }
        }
    }

    func translate(_ text: String, sourceTag: String, targetTag: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        if sourceTag == targetTag { return text }

        return await withCheckedContinuation { continuation in
            pending.append(
                .text(
                    TextJob(
                        text: trimmed,
                        sourceTag: sourceTag,
                        targetTag: targetTag,
                        continuation: continuation
                    )
                )
            )
            prepareConfiguration(sourceTag: sourceTag, targetTag: targetTag)
        }
    }

    private func prepareConfiguration(sourceTag: String, targetTag: String) {
        let key = "\(sourceTag)|\(targetTag)"
        if configurationKey != key {
            configurationKey = key
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: sourceTag),
                target: Locale.Language(identifier: targetTag)
            )
        } else {
            configuration?.invalidate()
        }
    }

    fileprivate func runPending(using session: TranslationSession) async {
        let jobs = pending
        pending.removeAll()
        for job in jobs {
            switch job {
            case .preset(let presetJob):
                let result = await TaxPresetTranslator.localizedPreset(
                    presetJob.preset,
                    catalogUpdatedAt: presetJob.catalogUpdatedAt,
                    interfaceLocale: presetJob.interfaceLocale,
                    session: session
                )
                presetJob.continuation.resume(returning: result)
            case .text(let textJob):
                do {
                    let response = try await session.translate(textJob.text)
                    textJob.continuation.resume(returning: response.targetText)
                } catch {
                    textJob.continuation.resume(returning: textJob.text)
                }
            }
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
