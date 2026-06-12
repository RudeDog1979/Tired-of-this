//
//  BuxPadSplitScaffold.swift
//  BuxMuse — Sidebar + detail split for regular width; stacked for compact.
//

import SwiftUI

struct BuxPadSplitScaffold<Sidebar: View, Detail: View>: View {
    @Environment(\.buxLayoutMode) private var layoutMode
    @Environment(\.buxContainerWidth) private var containerWidth

    @ViewBuilder var sidebar: () -> Sidebar
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        Group {
            if layoutMode == .regular {
                HStack(spacing: BuxPadLayout.columnGap) {
                    sidebar()
                        .frame(width: BuxPadLayout.splitSidebarWidth(
                            containerWidth: containerWidth,
                            layoutMode: layoutMode
                        ))
                    detail()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, BuxPadLayout.horizontalMargin(layoutMode: layoutMode))
            } else {
                VStack(spacing: 0) {
                    sidebar()
                    detail()
                }
            }
        }
    }
}
