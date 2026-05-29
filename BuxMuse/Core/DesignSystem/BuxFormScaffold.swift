//
//  BuxFormScaffold.swift
//  BuxMuse
//
//  System-grouped Form chrome for task surfaces (HIG-aligned).
//

import SwiftUI

// MARK: - Form scaffold backdrop

struct BuxFormScaffold<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .buxThemedPresentation()
    }
}

extension View {
    /// Native grouped Form — transparent scroll background on themed screens.
    func buxThemedFormStyle() -> some View {
        modifier(BuxThemedFormStyleModifier())
    }

    /// Alias for settings / sheet forms.
    func buxSystemFormStyle() -> some View {
        buxThemedFormStyle()
    }
}

private struct BuxThemedFormStyleModifier: ViewModifier {
    @Environment(\.settingsEnhancedTint) private var settingsEnhancedTint

    func body(content: Content) -> some View {
        if settingsEnhancedTint {
            content
                .scrollContentBackground(.hidden)
                .buxScrollDismissesKeyboard()
                .buxListContentMargins()
        } else {
            content
                .scrollContentBackground(.hidden)
                .buxScrollDismissesKeyboard()
        }
    }
}
