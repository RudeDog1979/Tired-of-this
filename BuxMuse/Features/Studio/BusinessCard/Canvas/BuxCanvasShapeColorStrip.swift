//
//  BuxCanvasShapeColorStrip.swift
//  BuxMuse — quick fill colors for selected shape layers
//

import SwiftUI

struct BuxCanvasShapeColorStrip: View {
    let palette: ProBusinessCardPalette
    let currentHex: String
    let onPick: (String) -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    private var swatches: [(String, String)] {
        [
            ("Accent", palette.accentHex),
            ("Text", palette.foregroundHex),
            ("Paper", palette.backgroundHex),
            ("#111827", "#111827"),
            ("#FFFFFF", "#FFFFFF"),
            ("#00000000", "#00000000"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BuxCatalogDynamicText(key: "Shape color")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(swatches, id: \.1) { label, hex in
                        Button {
                            onPick(hex)
                        } label: {
                            VStack(spacing: 3) {
                                Circle()
                                    .fill(hex == "#00000000" ? Color.clear : Color(hex: hex))
                                    .overlay(
                                        Circle().stroke(
                                            currentHex == hex ? themeManager.current.accentColor : Color.secondary.opacity(0.35),
                                            lineWidth: currentHex == hex ? 2.5 : 1
                                        )
                                    )
                                    .frame(width: 28, height: 28)
                                Text(label)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
