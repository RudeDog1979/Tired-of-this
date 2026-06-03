//
//  BuxDesignerColorKit.swift
//  BuxMuse — Photoshop-style color + opacity for Bux Canvas (additive)
//

import SwiftUI
import UIKit

// MARK: - Codec (6- or 8-digit hex, ARGB when alpha < 1)

enum BuxDesignerColorCodec {

    static func color(from hex: String) -> Color {
        Color(hex: hex)
    }

    static func hex(from color: Color, forceAlpha: Bool = false) -> String {
        UIColor(color).buxDesignerHexString(forceAlpha: forceAlpha)
    }

    static func colorOpacity(from hex: String) -> Double {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard normalized.count == 8, let value = UInt64(normalized, radix: 16) else { return 1 }
        return Double(value >> 24) / 255
    }

    /// Six-digit `#RRGGBB` extracted from a 6- or 8-digit hex string.
    static func rgbHex(from hex: String) -> String {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
        switch normalized.count {
        case 6:
            return "#\(normalized)"
        case 8:
            let rgb = normalized.suffix(6)
            return "#\(rgb)"
        default:
            return "#111827"
        }
    }

    static func hsb(from hex: String) -> (hue: Double, saturation: Double, brightness: Double) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        let ui = UIColor(color(from: hex))
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return (Double(h), Double(s), Double(b))
        }
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &bl, alpha: &a)
        let maxC = max(r, g, bl)
        let minC = min(r, g, bl)
        let delta = maxC - minC
        guard delta > 0.001 else { return (0, 0, Double(maxC)) }
        let hue: CGFloat
        if maxC == r {
            hue = (g - bl) / delta + (g < bl ? 6 : 0)
        } else if maxC == g {
            hue = (bl - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        return (Double(hue / 6), Double(delta / maxC), Double(maxC))
    }

    static func hex(fromHue hue: Double, saturation: Double, brightness: Double, alpha: Double) -> String {
        let color = Color(
            hue: min(1, max(0, hue)),
            saturation: min(1, max(0, saturation)),
            brightness: min(1, max(0, brightness))
        )
        return hexByUpdatingAlpha(hex(from: color), alpha: alpha)
    }

    static func hexByUpdatingAlpha(_ hex: String, alpha: Double) -> String {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
        switch normalized.count {
        case 6:
            guard let value = UInt64(normalized, radix: 16) else { return hex }
            r = value >> 16
            g = (value >> 8) & 0xFF
            b = value & 0xFF
        case 8:
            guard let value = UInt64(normalized, radix: 16) else { return hex }
            r = (value >> 16) & 0xFF
            g = (value >> 8) & 0xFF
            b = value & 0xFF
        default:
            return hex
        }
        let a = UInt64(min(1, max(0, alpha)) * 255)
        if a >= 255 { return String(format: "#%02X%02X%02X", r, g, b) }
        return String(format: "#%02X%02X%02X%02X", a, r, g, b)
    }
}

private extension UIColor {
    func buxDesignerHexString(forceAlpha: Bool) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        if forceAlpha || a < 0.995 {
            return String(format: "#%02X%02X%02X%02X", Int(a * 255), Int(r * 255), Int(g * 255), Int(b * 255))
        }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Recents

enum BuxDesignerColorRecents {
    private static let key = "bux.designer.color.recents"
    private static let cap = 18

    static var all: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func remember(_ hex: String) {
        let normalized = hex.uppercased()
        var list = all.filter { $0.uppercased() != normalized }
        list.insert(normalized, at: 0)
        UserDefaults.standard.set(Array(list.prefix(cap)), forKey: key)
    }
}

// MARK: - Presets (additive — keeps BuxCanvasColorPresets.all intact)

enum BuxDesignerColorPresets {

    struct Group: Identifiable {
        let id: String
        let title: String
        let colors: [String]
    }

    static let groups: [Group] = [
        Group(id: "neutrals", title: "Neutrals", colors: [
            "#000000", "#111827", "#1F2937", "#374151", "#6B7280", "#9CA3AF", "#D1D5DB", "#F3F4F6", "#FFFFFF", "#00000000"
        ]),
        Group(id: "brand", title: "Vivid", colors: [
            "#5A55F5", "#4F46E5", "#2563EB", "#0284C7", "#0891B2", "#00C882", "#10B981", "#84CC16", "#EAB308", "#F59E0B"
        ]),
        Group(id: "warm", title: "Warm", colors: [
            "#FF3366", "#F43F5E", "#E11D48", "#C2410C", "#EA580C", "#D97706", "#B45309", "#92400E", "#D4AF37", "#FDE68A"
        ]),
        Group(id: "cool", title: "Cool & dark", colors: [
            "#0F172A", "#0B1220", "#1E1B4B", "#312E81", "#581C87", "#A21CAF", "#22D3EE", "#38BDF8", "#818CF8", "#C4B5FD"
        ]),
        Group(id: "legacy", title: "Quick picks", colors: BuxCanvasColorPresets.all),
    ]

    static func swatches(for palette: ProBusinessCardPalette?) -> [(String, String)] {
        guard let palette else { return [] }
        return [
            ("Accent", palette.accentHex),
            ("Text", palette.foregroundHex),
            ("Paper", palette.backgroundHex),
        ]
    }
}

// MARK: - Checkerboard (transparent preview)

/// Compact color preview — circle with checkerboard and true alpha.
struct BuxDesignerColorWell: View {
    let hex: String
    var size: CGFloat = 36
    var showsRing: Bool = true

    private var isClear: Bool { hex.uppercased() == "#00000000" }

    var body: some View {
        ZStack {
            BuxDesignerTransparencyGrid(cell: max(3, size / 10))
                .clipShape(Circle())
            if !isClear {
                Circle()
                    .fill(BuxDesignerColorCodec.color(from: hex))
            }
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1, size * 0.06)
                )
                .padding(size * 0.08)
        }
        .frame(width: size, height: size)
        .overlay {
            if showsRing {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.22), lineWidth: 2)
            } else {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 1.5, y: 0.5)
    }
}

// MARK: - HSB controls (replaces system ColorPicker on canvas sheet)

struct BuxDesignerHSBControls: View {
    @Binding var hex: String
    @Binding var alpha: Double
    var accent: Color

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var didSeed = false
    @State private var isCommittingHSB = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            saturationBrightnessField
            hueSlider
        }
        .onAppear {
            guard !didSeed else { return }
            didSeed = true
            loadHSBFromHex()
        }
        .onChange(of: hex) { _, _ in
            guard !isCommittingHSB else { return }
            loadHSBFromHex()
        }
    }

    private var saturationBrightnessField: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .shadow(color: .black.opacity(0.35), radius: 2)
                    .frame(width: 18, height: 18)
                    .position(
                        x: CGFloat(saturation) * size.width,
                        y: (1 - CGFloat(brightness)) * size.height
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        saturation = min(1, max(0, Double(value.location.x / size.width)))
                        brightness = min(1, max(0, 1 - Double(value.location.y / size.height)))
                        commitHSB()
                    }
            )
        }
        .frame(height: 168)
    }

    private var hueSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hue")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            ZStack {
                LinearGradient(
                    colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 1, brightness: 1) },
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 14)
                .clipShape(Capsule())
                Slider(value: $hue, in: 0...0.999)
                    .tint(.clear)
                    .onChange(of: hue) { _, _ in commitHSB() }
            }
        }
    }

    private func loadHSBFromHex() {
        let parts = BuxDesignerColorCodec.hsb(from: hex)
        hue = parts.hue
        saturation = parts.saturation
        brightness = parts.brightness
        alpha = BuxDesignerColorCodec.colorOpacity(from: hex)
    }

    private func commitHSB() {
        isCommittingHSB = true
        hex = BuxDesignerColorCodec.hex(fromHue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        isCommittingHSB = false
    }
}

struct BuxDesignerTransparencyGrid: View {
    var cell: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col).isMultiple(of: 2)
                    let rect = CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? Color.white : Color(white: 0.82))
                    )
                }
            }
        }
    }
}
