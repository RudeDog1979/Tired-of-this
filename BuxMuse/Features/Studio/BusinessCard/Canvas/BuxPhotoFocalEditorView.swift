//
//  BuxPhotoFocalEditorView.swift
//  BuxMuse
//
//  BuxMuse proprietary focal editor — pan, pinch, rotate like Apple Photos.
//

import SwiftUI

struct BuxPhotoFocalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let image: UIImage
    @Binding var transform: ProBusinessCardPhotoTransform
    var cropIsCircle: Bool = false
    let onDone: () -> Void

    @State private var scale: CGFloat = 1
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let viewport = min(geo.size.width - 40, geo.size.height * 0.62, 440)
                VStack(spacing: 16) {
                    ZStack {
                        Color.black.opacity(0.92)
                        focalViewport(size: viewport)
                    }
                    .frame(height: viewport + 48)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "minus.magnifyingglass").foregroundStyle(Color.white.opacity(0.55))
                            Slider(value: $scale, in: 1...4).tint(themeManager.current.accentColor)
                            Image(systemName: "plus.magnifyingglass").foregroundStyle(Color.white.opacity(0.55))
                        }
                        HStack {
                            Image(systemName: "rotate.left").foregroundStyle(Color.white.opacity(0.55))
                            Slider(value: $rotation, in: -180...180).tint(themeManager.current.accentColor)
                            Image(systemName: "rotate.right").foregroundStyle(Color.white.opacity(0.55))
                        }
                        Text("Drag to reposition · pinch or slide to zoom")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .padding(.horizontal, 20)
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        transform = ProBusinessCardPhotoTransform(
                            zoom: Double(scale),
                            offsetX: Double(offset.width / 200) * 0.5,
                            offsetY: Double(offset.height / 200) * 0.5,
                            rotation: rotation
                        )
                        onDone()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .foregroundStyle(.white)
        .onAppear {
            scale = max(1, CGFloat(transform.zoom))
            lastScale = scale
            rotation = transform.rotation
            offset = CGSize(width: CGFloat(transform.offsetX) * 400, height: CGFloat(transform.offsetY) * 400)
            lastOffset = offset
        }
    }

    private func focalViewport(size: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .frame(width: size, height: size)
            .clipShape(cropIsCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 12)))
            .overlay {
                if cropIsCircle {
                    Circle().stroke(Color.white, lineWidth: 2)
                } else {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 2)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { v in
                        offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height)
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { v in scale = min(4, max(1, lastScale * v)) }
                    .onEnded { _ in lastScale = scale }
            )
    }
}

private struct AnyShape: Shape {
    private let builder: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) { builder = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { builder(rect) }
}
