//
//  BuxShapePickerSheet.swift
//  BuxMuse
//

import SwiftUI

struct BuxShapePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let palette: ProBusinessCardPalette
    var onPickShape: (CardShapeType) -> Void
    var onApplyPack: (BuxBrandStyleEngine.LayoutPack) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Bux Layout Packs") {
                    ForEach(BuxBrandStyleEngine.layoutPacks) { pack in
                        Button {
                            onApplyPack(pack)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pack.title).font(.headline)
                                Text(pack.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Geometric shapes") {
                    ForEach(CardShapeType.geometricShapes) { shape in
                        shapeRow(shape)
                    }
                }

                Section("Basic shapes") {
                    ForEach(CardShapeType.basicShapes) { shape in
                        shapeRow(shape)
                    }
                }
            }
            .navigationTitle("Bux Shapes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func shapeRow(_ shape: CardShapeType) -> some View {
        Button {
            onPickShape(shape)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                BuxGeometricShapeView(
                    type: shape,
                    fill: AnyShapeStyle(Color(hex: palette.accentHex)),
                    stroke: nil,
                    strokeWidth: 0,
                    cornerRadius: 4
                )
                .frame(width: 36, height: 28)
                Text(shape.title)
            }
        }
    }
}
