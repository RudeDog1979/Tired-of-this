//
//  BuxSaveToolbar.swift
//  BuxMuse — toolbar Save affordance (disabled when nothing to save).
//

import SwiftUI
import UIKit

/// Navigation bar Save — same label; grays out when there are no unsaved changes.
struct BuxToolbarSaveButton: View {
    var isDirty: Bool
    var action: () -> Void

    var body: some View {
        Button("Save", action: action)
            .fontWeight(.semibold)
            .disabled(!isDirty)
            .opacity(isDirty ? 1 : 0.4)
            .contentTransition(.opacity)
    }
}

enum BuxSaveFeedback {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
