//
//  BuxKeyboardToolbar.swift
//  BuxMuse
//
//  Native keyboard dismiss — scroll/swipe only (no custom accessory bar).
//

import SwiftUI
import UIKit

enum BuxKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    /// Interactive scroll / swipe-down on keyboard — standard iOS, no extra toolbar icons.
    func buxScrollDismissesKeyboard() -> some View {
        scrollDismissesKeyboard(.interactively)
    }
}
