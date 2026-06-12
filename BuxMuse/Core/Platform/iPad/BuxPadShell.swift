//
//  BuxPadShell.swift
//  BuxMuse — Adaptive iPad navigation shell (compact tab bar / regular sidebar).
//

import SwiftUI

struct BuxPadShell<Content: View>: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            switch layoutMode {
            case .regular:
                BuxPadRegularShell(content: content)
            case .compact:
                BuxPadCompactShell(content: content)
            }
        }
        .animation(nil, value: layoutMode)
    }
}
