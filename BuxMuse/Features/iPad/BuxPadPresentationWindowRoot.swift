//
//  BuxPadPresentationWindowRoot.swift
//  BuxMuse — External display window (invoice preview + money map).
//

import SwiftUI

struct BuxPadPresentationWindowRoot: View {
    let payload: BuxPadPresentationPayload
    @ObservedObject var container: AppContainer

    private var padBrain: BuxPadNavigationBrain {
        container.padNavigationBrain
    }

    var body: some View {
        Group {
            switch payload.kind {
            case .moneyMap:
                BuxPadExternalMoneyMapHost()
            case .invoicePreview:
                BuxPadExternalInvoicePreviewHost()
            }
        }
        .buxPadWindowEnvironment(container: container, padBrain: padBrain)
        .buxPadEnvironment()
        .buxPadReportsContainerMetrics()
        .buxPadPublishesSceneScale()
        .preferredColorScheme(nil)
        .userActivity(BuxPadSceneActivity.presentationWindow) { activity in
            activity.title = presentationTitle
            activity.isEligibleForSearch = false
            activity.isEligibleForHandoff = false
            activity.userInfo = BuxPadSceneRestoration.userInfo(
                sessionId: payload.sessionId,
                snapshot: padBrain.exportSnapshot(),
                presentationKind: payload.kind.rawValue
            )
        }
        .onContinueUserActivity(BuxPadSceneActivity.presentationWindow) { activity in
            guard let snapshot = BuxPadSceneRestoration.snapshot(from: activity.userInfo) else { return }
            padBrain.applySnapshot(snapshot)
            if let raw = BuxPadSceneRestoration.presentationKind(from: activity.userInfo),
               let kind = BuxPadExternalPresentationKind(rawValue: raw) {
                padBrain.requestExternalPresentation(kind)
            }
        }
    }

    private var presentationTitle: String {
        switch payload.kind {
        case .moneyMap: return "BuxMuse Money Map"
        case .invoicePreview: return "BuxMuse Invoice Preview"
        }
    }
}
