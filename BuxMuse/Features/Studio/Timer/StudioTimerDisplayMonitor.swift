//
//  StudioTimerDisplayMonitor.swift
//  BuxMuse
//
//  Drives Live Activity updates when the display is on (lock screen or in-app),
//  and rests while the screen is off to save battery.
//

import UIKit

@MainActor
final class StudioTimerDisplayMonitor {
    static let shared = StudioTimerDisplayMonitor()

    private var isDisplayAwake = true
    private var observers: [any NSObjectProtocol] = []
    private var reevaluateTask: Task<Void, Never>?

    private static let watchedNotifications: [Notification.Name] = [
        UIScreen.brightnessDidChangeNotification,
        UIApplication.didBecomeActiveNotification,
        UIApplication.didEnterBackgroundNotification
    ]

    private init() {}

    func start() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default
        for name in Self.watchedNotifications {
            observers.append(
                center.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { _ in
                    MainActor.assumeIsolated {
                        StudioTimerDisplayMonitor.shared.scheduleReevaluateDisplayPowerState()
                    }
                }
            )
        }

        reevaluateDisplayPowerState()
    }

    func handleSceneBecameInactive() {
        scheduleReevaluateDisplayPowerState()
        StudioTimerController.shared.syncLiveActivityOnForeground()
    }

    func handleSceneBecameActive() {
        scheduleReevaluateDisplayPowerState()
        StudioTimerController.shared.syncLiveActivityOnForeground()
    }

    func handleSceneEnteredBackground() {
        scheduleReevaluateDisplayPowerState()
    }

    func handleTimerRunningStateChanged() {
        // Widget extension animates elapsed/progress; app only pushes on user actions + wake.
    }

    private func scheduleReevaluateDisplayPowerState() {
        reevaluateTask?.cancel()
        reevaluateTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            reevaluateDisplayPowerState()
        }
    }

    private func reevaluateDisplayPowerState() {
        let awake = Self.isDisplayLikelyAwake
        let changed = awake != isDisplayAwake
        isDisplayAwake = awake
        StudioTimerLiveActivityManager.setDisplayAwake(awake)

        if awake, changed {
            StudioTimerController.shared.syncLiveActivityOnForeground()
        }
    }

    private static var isDisplayLikelyAwake: Bool {
        if UIApplication.shared.applicationState == .active {
            return true
        }
        return UIScreen.main.brightness > 0.01
    }
}
