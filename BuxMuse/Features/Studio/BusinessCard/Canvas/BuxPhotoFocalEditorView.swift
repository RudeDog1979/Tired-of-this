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
    /// When set, the focal window matches card proportions instead of a square.
    var viewportSize: CGSize? = nil
    var viewportCornerRadius: CGFloat = 12
    let onDone: () -> Void

    @State private var scale: CGFloat = 1
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let viewport = resolvedViewport(in: geo.size)
                VStack(spacing: 16) {
                    ZStack {
                        Color.black.opacity(0.92)
                        focalViewport(size: viewport)
                    }
                    .frame(height: viewport.height + 48)
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
                        let vp = viewportSize ?? CGSize(width: 320, height: 320)
                        transform = ProBusinessCardPhotoTransform(
                            zoom: Double(scale),
                            offsetX: Double(offset.width / max(1, vp.width)),
                            offsetY: Double(offset.height / max(1, vp.height)),
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
            let vp = viewportSize ?? CGSize(width: 320, height: 320)
            offset = CGSize(width: CGFloat(transform.offsetX) * vp.width, height: CGFloat(transform.offsetY) * vp.height)
            lastOffset = offset
        }
    }

    private func resolvedViewport(in geo: CGSize) -> CGSize {
        if let viewportSize { return viewportSize }
        let side = min(geo.width - 40, geo.height * 0.62, 440)
        return CGSize(width: side, height: side)
    }

    private func focalViewport(size: CGSize) -> some View {
        BuxPhotoFocalStage(
            image: image,
            scale: $scale,
            rotation: $rotation,
            offset: $offset,
            lastScale: $lastScale,
            lastOffset: $lastOffset,
            viewportSize: size,
            cornerRadius: viewportCornerRadius,
            cropIsCircle: cropIsCircle
        )
    }
}

/// Shared pan / pinch / rotate stage (SwiftUI) — used by focal sheet and background photo editor.
struct BuxPhotoFocalStage: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var rotation: Double
    @Binding var offset: CGSize
    @Binding var lastScale: CGFloat
    @Binding var lastOffset: CGSize
    let viewportSize: CGSize
    var cornerRadius: CGFloat = 12
    var cropIsCircle: Bool = false
    var onGestureEnded: (() -> Void)? = nil

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipShape(cropIsCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            .overlay {
                if cropIsCircle {
                    Circle().stroke(Color.white, lineWidth: 2)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white, lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { v in
                        offset = CGSize(
                            width: lastOffset.width + v.translation.width,
                            height: lastOffset.height + v.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                        onGestureEnded?()
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { v in
                        scale = min(5, max(1, lastScale * v))
                    }
                    .onEnded { _ in
                        lastScale = scale
                        onGestureEnded?()
                    }
            )
    }
}

private struct AnyShape: Shape {
    private let builder: @Sendable (CGRect) -> Path
    init<S: Shape>(_ shape: S) { builder = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { builder(rect) }
}
