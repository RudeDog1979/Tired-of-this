//
//  BusinessCard3DLookView.swift
//  BuxMuse
//
//  Solid turntable card — matte stock on the face, system-friendly backdrop.
//

import SwiftUI
import UIKit

struct BusinessCard3DLookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let design: ProBusinessCardDesign
    let logoData: Data?

    @State private var textures: Card3DTexturePair?
    @State private var yaw: Double = 0
    @State private var tilt: Double = 6
    @State private var zoom: CGFloat = 1
    @State private var dragStart: (yaw: Double, tilt: Double)?
    @State private var zoomStart: CGFloat = 1

    /// Fixed studio softbox in screen space (upper-left).
    private static let studioLightX: Double = 0.28
    private static let studioLightY: Double = 0.2

    private var displaySize: CGSize {
        let cardSize = design.aspect.previewSize
        let maxW = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * 0.82
        let maxH = UIScreen.main.bounds.height * 0.48
        let fit = min(maxW / cardSize.width, maxH / cardSize.height, 1.2)
        return CGSize(width: cardSize.width * fit, height: cardSize.height * fit)
    }

    private var cardCorner: CGFloat { min(10, displaySize.height * 0.06) }
    private var cardThickness: CGFloat { max(12, displaySize.width * 0.042) }

    private var yawRadians: Double { yaw * .pi / 180 }
    private var tiltRadians: Double { tilt * .pi / 180 }
    private var edgeScale: CGFloat { CGFloat(abs(sin(yawRadians))) }
    private var showingFront: Bool { cos(yawRadians) >= 0 }

    var body: some View {
        ZStack {
            backdrop

            if let textures {
                cardStage(textures: textures)
            } else {
                ProgressView("Rendering card…")
                    .tint(themeManager.current.accentColor)
            }

            chromeOverlay
        }
        .task(id: textureTaskKey) {
            textures = await Card3DTextureRenderer.render(design: design, logoData: logoData)
        }
        .onDisappear { textures = nil }
    }

    /// System-friendly gradient — no forced dark mode flash.
    private var backdrop: some View {
        LinearGradient(
            colors: [
                Color(hex: design.palette.backgroundHex).opacity(colorScheme == .dark ? 0.22 : 0.32),
                Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.92 : 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var chromeOverlay: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if textures != nil {
                    if abs(zoom - 1) > 0.05 {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                                zoom = 1
                                zoomStart = 1
                            }
                        } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left.circle.fill")
                                .font(.system(size: 26))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            yaw = 0
                            tilt = 6
                            zoom = 1
                            zoomStart = 1
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 26))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            BuxCatalogDynamicText(key: "Drag to spin · pinch to zoom")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
    }

    private func cardStage(textures: Card3DTexturePair) -> some View {
        let stagePad: CGFloat = 56

        return ZStack {
            Ellipse()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.28 : 0.14))
                .frame(width: displaySize.width * 0.88, height: displaySize.height * 0.11)
                .blur(radius: 18)
                .offset(y: displaySize.height * 0.52 + 4)
                .scaleEffect(zoom)
                .allowsHitTesting(false)

            cardBody(textures: textures)
                .scaleEffect(zoom)
                .simultaneousGesture(dragGesture)
                .simultaneousGesture(magnificationGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        zoom = 1
                        zoomStart = 1
                    }
                }
        }
        .padding(stagePad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cardBody(textures: Card3DTexturePair) -> some View {
        ZStack {
            // Paper edge — only when the card is turned enough to see stock (avoids center-line artifact).
            if edgeScale > 0.38 {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.88),
                                Color(white: 0.72),
                                Color(white: 0.82)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: cardThickness * edgeScale * 1.4,
                        height: displaySize.height * 0.98
                    )
            }

            if showingFront {
                cardFace(textures.front)
            } else {
                cardFace(textures.back)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.82)
        .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: 0, z: 0), perspective: 0.92)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.18), radius: 20, x: sin(yawRadians) * 6, y: 12)
        .animation(nil, value: showingFront)
    }

    private func cardFace(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fill)
            .frame(width: displaySize.width, height: displaySize.height)
            .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .compositingGroup()
            .overlay { cardStockMatteGlaze() }
    }

    /// Maps fixed studio light to local UV so highlight slides L↔R as the card flips — not spinning with artwork.
    private func specularCenterOnFace(isBackFace: Bool) -> UnitPoint {
        let facing = isBackFace ? -1.0 : 1.0
        let cosY = cos(yawRadians) * facing
        guard abs(cosY) > 0.12 else {
            return UnitPoint(x: 0.5, y: 0.5)
        }

        let localX = min(max(Self.studioLightX / cosY, 0.06), 0.94)
        let localY = min(max(Self.studioLightY - sin(tiltRadians) * 0.1, 0.06), 0.94)
        return UnitPoint(x: localX, y: localY)
    }

    /// Matte glaze sits ON TOP of the full card composite (photos, logo, text).
    private func cardStockMatteGlaze() -> some View {
        let isBack = !showingFront
        let specCenter = specularCenterOnFace(isBackFace: isBack)
        let cosY = abs(cos(yawRadians))
        let diffuse = 0.45 + 0.5 * cosY

        return ZStack {
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.26 * diffuse),
                            Color.white.opacity(0.06),
                            Color.clear,
                            Color.black.opacity(0.16 * diffuse)
                        ],
                        startPoint: specCenter,
                        endPoint: UnitPoint(x: 1 - specCenter.x + 0.08, y: 1 - specCenter.y + 0.1)
                    )
                )
                .blendMode(.softLight)

            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(isBack ? 0.14 : 0.24),
                            Color.white.opacity(isBack ? 0.05 : 0.08),
                            Color.clear
                        ],
                        center: specCenter,
                        startRadius: 2,
                        endRadius: displaySize.width * 0.48
                    )
                )
                .blendMode(.plusLighter)

            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.clear],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.55, y: 0.38)
                    )
                )
                .blendMode(.overlay)
        }
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragStart == nil { dragStart = (yaw, tilt) }
                guard let start = dragStart else { return }
                yaw = start.yaw + Double(value.translation.width) * 0.42
                tilt = max(-20, min(20, start.tilt - Double(value.translation.height) * 0.11))
            }
            .onEnded { value in
                dragStart = nil
                let flickYaw = Double(value.predictedEndTranslation.width - value.translation.width) * 0.07
                withAnimation(.interpolatingSpring(stiffness: 88, damping: 17)) {
                    yaw += flickYaw
                }
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard value.isFinite, value > 0 else { return }
                let proposed = zoomStart * value
                guard proposed.isFinite else { return }
                zoom = min(max(proposed, 0.65), 1.95)
            }
            .onEnded { value in
                guard value.isFinite, value > 0 else {
                    zoomStart = zoom
                    return
                }
                let final = min(max(zoomStart * value, 0.65), 1.95)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    zoom = final
                    zoomStart = final
                }
            }
    }

    private var textureTaskKey: String {
        "\(design.id)-\(design.updatedAt.timeIntervalSince1970)-\(design.backSide.note)"
    }
}

// MARK: - Texture rendering

struct Card3DTexturePair {
    let front: UIImage
    let back: UIImage
}

enum Card3DTextureRenderer {
    @MainActor
    static func render(design: ProBusinessCardDesign, logoData: Data?) async -> Card3DTexturePair? {
        guard let front = ProBusinessCardExport.renderImage(design: design, logoData: logoData, scale: 2) else {
            return nil
        }
        let backView = ProBusinessCardBackRenderer(design: design, logoData: logoData)
        let renderer = ImageRenderer(content: backView)
        renderer.scale = 2
        guard let back = renderer.uiImage else { return nil }
        return Card3DTexturePair(front: front, back: back)
    }
}
