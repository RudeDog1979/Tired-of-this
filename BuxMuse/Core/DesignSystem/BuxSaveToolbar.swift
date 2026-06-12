//
//  BuxSaveToolbar.swift
//  BuxMuse — toolbar Save affordance (✓, disabled when nothing to save).
//

import SwiftUI
import UIKit

struct BuxToolbarSaveButton: View {
    var isDirty: Bool
    var action: () -> Void

    var body: some View {
        BuxToolbarConfirmButton(
            accessibilityLabel: "Save",
            isEnabled: isDirty,
            action: action
        )
        .contentTransition(.opacity)
    }
}

enum BuxSaveFeedback {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
