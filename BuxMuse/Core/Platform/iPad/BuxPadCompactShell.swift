//
//  BuxPadCompactShell.swift
//  BuxMuse — iPad compact width (Slide Over, 1/3 Split View): bottom tab bar.
//

import SwiftUI

struct BuxPadCompactShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
    }
}
