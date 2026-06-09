//
//  StudioTimerActivityKitGateway.swift
//  BuxMuse
//
//  ActivityKit update/end run on concurrent executors — opt out of default @MainActor isolation.
//

@preconcurrency import ActivityKit
import Foundation

nonisolated enum StudioTimerActivityKitGateway {
    static func update(
        _ activity: Activity<StudioTimerAttributes>,
        content: ActivityContent<StudioTimerAttributes.ContentState>
    ) async {
        await activity.update(content)
    }

    static func end(
        _ activity: Activity<StudioTimerAttributes>,
        content: ActivityContent<StudioTimerAttributes.ContentState>,
        dismissalPolicy: ActivityUIDismissalPolicy
    ) async {
        await activity.end(content, dismissalPolicy: dismissalPolicy)
    }

    static func endAll() async {
        for activity in Activity<StudioTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
