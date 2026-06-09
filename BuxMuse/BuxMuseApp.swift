//
//  BuxMuseApp.swift
//  BuxMuse
//

import SwiftUI

@main
struct BuxMuseApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .buxAppContainerEnvironment(container, padBrain: container.padNavigationBrain)
                .task {
                    _ = await ExpenseRenewalReminderScheduler.requestAuthorizationIfNeeded()
                    container.scheduleEngagementRefresh()
                    container.scheduleTipsRefresh()
                    container.scheduleTaxCatalogRefresh()
                }
                .onOpenURL { url in
                    guard StudioTimerDeepLink.matches(url) else { return }
                    container.navigationCoordinator.openStudioLogTime()
                }
        }
        .commands {
            BuxPadKeyboardCommands(padBrain: container.padNavigationBrain)
        }

        WindowGroup(id: BuxPadWindowID.expense, for: UUID.self) { $sessionId in
            if let sessionId {
                BuxPadExpenseWindowRoot(sessionId: sessionId, container: container)
                    .buxAppContainerEnvironment(
                        container,
                        padBrain: container.padSceneBrainRegistry.brain(for: sessionId)
                    )
            }
        }
        .defaultSize(width: 1100, height: 800)
        .handlesExternalEvents(matching: Set(arrayLiteral: BuxPadWindowID.expense))

        WindowGroup(id: BuxPadWindowID.studio, for: BuxPadStudioWindowPayload.self) { $payload in
            if let payload {
                BuxPadStudioWindowRoot(payload: payload, container: container)
                    .buxAppContainerEnvironment(
                        container,
                        padBrain: container.padSceneBrainRegistry.brain(for: payload.sessionId)
                    )
            }
        }
        .defaultSize(width: 1200, height: 860)
        .handlesExternalEvents(matching: Set(arrayLiteral: BuxPadWindowID.studio))

        WindowGroup(id: BuxPadWindowID.presentation, for: BuxPadPresentationPayload.self) { $payload in
            if let payload {
                BuxPadPresentationWindowRoot(payload: payload, container: container)
            }
        }
        .defaultSize(width: 1400, height: 900)
        .handlesExternalEvents(matching: Set(arrayLiteral: BuxPadWindowID.presentation))
    }
}
