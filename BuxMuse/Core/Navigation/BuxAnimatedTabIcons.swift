//
//  BuxAnimatedTabIcons.swift
//  BuxMuse
//
//  Studio tab glyph for in-app use (e.g. Freelance module headers).
//

import SwiftUI

/// Person-at-laptop vector glyph (dashboard widget, in-app labels).
struct StudioTabGlyph: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .frame(width: 7, height: 7)
                .offset(y: -15)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .frame(width: 13, height: 7)
                .offset(y: -9)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .strokeBorder(lineWidth: 1.4)
                .background(RoundedRectangle(cornerRadius: 1.5).fill(Color.clear))
                .frame(width: 15, height: 9)
                .offset(y: -3)

            RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                .frame(width: 17, height: 2.5)
        }
        .frame(width: 22, height: 22)
    }
}
