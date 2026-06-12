//
//  BuxPadOpenWindowActions.swift
//  BuxMuse — Open auxiliary iPad windows (Stage Manager).
//

import SwiftUI

struct BuxPadOpenExpenseWindowButton: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry

    var body: some View {
        if BuxPadIdiom.isPad, !padSceneBrainRegistry.isAuxiliary(padBrain) {
            Button {
                BuxPadWindowLauncher.openExpenseWindow(
                    from: padBrain,
                    registry: padSceneBrainRegistry,
                    openWindow: openWindow
                )
            } label: {
                Label("Open Expenses in New Window", systemImage: "square.split.2x1")
            }
        }
    }
}

struct BuxPadOpenStudioWindowButton: View {
    let destinationRawValue: String?
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var padBrain: BuxPadNavigationBrain
    @EnvironmentObject private var padSceneBrainRegistry: BuxPadSceneBrainRegistry

    init(destination: BuxPadStudioDestination?) {
        destinationRawValue = destination?.rawValue
    }

    init(simpleDestination: BuxPadSimpleStudioDestination?) {
        destinationRawValue = simpleDestination?.rawValue
    }

    var body: some View {
        if BuxPadIdiom.isPad, !padSceneBrainRegistry.isAuxiliary(padBrain) {
            Button {
                BuxPadWindowLauncher.openStudioWindow(
                    destination: destinationRawValue,
                    from: padBrain,
                    registry: padSceneBrainRegistry,
                    openWindow: openWindow
                )
            } label: {
                Label("Open Studio in New Window", systemImage: "macwindow.on.rectangle")
            }
        }
    }
}

/// WindowGroup value for Studio auxiliary scenes.
struct BuxPadStudioWindowPayload: Codable, Hashable, Identifiable {
    var sessionId: UUID
    var destination: String?

    var id: String { sessionId.uuidString }
}
