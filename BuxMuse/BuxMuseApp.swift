//
//  BuxMuseApp.swift
//  BuxMuse
//

import SwiftUI
import CloudKit

@main
struct BuxMuseApp: App {
    @UIApplicationDelegateAdaptor(PersonalCloudSyncAppDelegate.self) private var appDelegate
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .buxPreferredColorScheme()
                .buxAppContainerEnvironment(container, padBrain: container.padNavigationBrain)
                .task {
                    _ = await BuxNotificationPolicy.requestAuthorizationIfNeeded()
                    container.rescheduleAllLocalNotifications()
                    container.scheduleTipsRefresh()
                    container.scheduleTaxCatalogRefresh()
                }
                .onOpenURL { url in
                    if StudioTimerDeepLink.matches(url) {
                        container.navigationCoordinator.openStudioLogTime()
                        return
                    }
                    Task {
                        let metadata = try? await CKContainer(identifier: HouseholdSyncEngine.containerIdentifier)
                            .shareMetadata(for: url)
                        if let metadata {
                            try? await HouseholdSyncEngine.shared.acceptShare(metadata: metadata)
                        }
                    }
                }
        }
        .commands {
            BuxPadKeyboardCommands(padBrain: container.padNavigationBrain)
        }

        WindowGroup(id: BuxPadWindowID.expense, for: UUID.self) { $sessionId in
            if let sessionId {
                BuxPadExpenseWindowRoot(sessionId: sessionId, container: container)
                    .buxPreferredColorScheme()
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
                    .buxPreferredColorScheme()
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
                    .buxPreferredColorScheme()
            }
        }
        .defaultSize(width: 1400, height: 900)
        .handlesExternalEvents(matching: Set(arrayLiteral: BuxPadWindowID.presentation))
    }
}
