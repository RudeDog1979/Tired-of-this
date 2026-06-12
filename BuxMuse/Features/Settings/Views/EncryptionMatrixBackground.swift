//
//  EncryptionMatrixBackground.swift
//  BuxMuse
//
//  Fixed-grid cipher tokens that scramble/decode in place (Matrix-adjacent, no rain).
//

import Combine
import SwiftUI

/// Animated encode/decode token field for archive progress screens.
struct EncryptionMatrixBackground: View {
    let accent: Color

    private let encodeTokens = [
        "AES-GCM", "SHA-256", "SEAL", "WRAP", "NONCE", "SALT", "DERIVE",
        "ENCRYPT", "PACK", "BM-KEY", "BUXMUSE2", "GCM", "PKCS", "0x4F2A",
        "CIPHER", "KEYWRAP", "MANIFEST", "ARCHIVE", "PAYLOAD", "SEALBOX"
    ]

    private let decodeTokens = [
        "DECRYPT", "UNWRAP", "OPEN", "VERIFY", "READ", "PARSE", "RESTORE",
        "IMPORT", "UNSEAL", "DECODE", "VALIDATE", "RECOVER", "UNPACK",
        "0xAF32", "PLAINTEXT", "UNLOCK", "CHECKSUM", "MANIFEST", "INGEST"
    ]

    private let scrambleCharset = Array("ABCDEF0123456789abcdef#x%-_")

    @State private var cells: [CipherCell] = []
    @State private var nextTokenIsEncode = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.06, blue: 0.04),
                        Color(red: 0.02, green: 0.04, blue: 0.03),
                        Color(red: 0.05, green: 0.08, blue: 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(cells) { cell in
                    Text(cell.displayed)
                        .font(.system(size: cell.fontSize, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tokenColor(for: cell))
                        .opacity(cell.opacity)
                        .position(x: cell.x, y: cell.y)
                        .blur(radius: cell.isScrambling ? 0.15 : 0)
                }

                RadialGradient(
                    colors: [
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.42),
                        Color.black.opacity(0.62)
                    ],
                    center: .center,
                    startRadius: 40,
                    endRadius: max(geo.size.width, geo.size.height) * 0.72
                )

                accent.opacity(0.06)
                    .blendMode(.plusLighter)
            }
            .onAppear {
                bootstrapCells(in: geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                bootstrapCells(in: newSize)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onReceive(Timer.publish(every: 0.11, on: .main, in: .common).autoconnect()) { _ in
            advanceCells()
        }
    }

    private func tokenColor(for cell: CipherCell) -> Color {
        let matrixGreen = Color(red: 0.25, green: 0.92, blue: 0.48)
        if cell.isEncode {
            return matrixGreen.opacity(0.55 + cell.opacity * 0.35)
        }
        return accent.opacity(0.35 + cell.opacity * 0.4)
    }

    private func bootstrapCells(in size: CGSize) {
        guard size.width > 40, size.height > 40 else { return }

        let columnStep: CGFloat = 76
        let rowStep: CGFloat = 30
        let columns = max(6, Int(size.width / columnStep))
        let rows = max(10, Int(size.height / rowStep))

        var built: [CipherCell] = []
        var id = 0
        for row in 0..<rows {
            for col in 0..<columns {
                let isEncode = Bool.random()
                let token = randomToken(encode: isEncode)
                let x = columnStep * 0.5 + CGFloat(col) * columnStep + CGFloat.random(in: -6...6)
                let y = rowStep * 0.6 + CGFloat(row) * rowStep + CGFloat.random(in: -4...4)
                built.append(
                    CipherCell(
                        id: id,
                        x: min(max(x, 8), size.width - 8),
                        y: min(max(y, 8), size.height - 8),
                        displayed: token,
                        target: token,
                        isEncode: isEncode,
                        scrambleFramesLeft: 0,
                        opacity: Double.random(in: 0.18...0.55),
                        fontSize: CGFloat.random(in: 8.5...11.5)
                    )
                )
                id += 1
            }
        }
        cells = built
    }

    private func advanceCells() {
        guard !cells.isEmpty else { return }

        var updated = cells
        let mutateCount = max(4, updated.count / 12)

        for index in updated.indices {
            if updated[index].scrambleFramesLeft > 0 {
                updated[index].scrambleFramesLeft -= 1
                if updated[index].scrambleFramesLeft == 0 {
                    updated[index].displayed = updated[index].target
                    updated[index].opacity = Double.random(in: 0.28...0.62)
                } else {
                    updated[index].displayed = scramble(
                        toward: updated[index].target,
                        frame: updated[index].scrambleFramesLeft
                    )
                    updated[index].opacity = Double.random(in: 0.35...0.75)
                }
            }
        }

        var candidates = updated.indices.filter { updated[$0].scrambleFramesLeft == 0 }
        candidates.shuffle()
        for index in candidates.prefix(mutateCount) {
            let isEncode = nextTokenIsEncode
            nextTokenIsEncode.toggle()
            let token = randomToken(encode: isEncode)
            updated[index].target = token
            updated[index].isEncode = isEncode
            updated[index].scrambleFramesLeft = Int.random(in: 3...6)
            updated[index].displayed = scramble(toward: token, frame: updated[index].scrambleFramesLeft)
            updated[index].opacity = Double.random(in: 0.4...0.8)
        }

        cells = updated
    }

    private func randomToken(encode: Bool) -> String {
        let bank = encode ? encodeTokens : decodeTokens
        return bank.randomElement() ?? (encode ? "ENCRYPT" : "DECRYPT")
    }

    private func scramble(toward target: String, frame: Int) -> String {
        guard frame > 0 else { return target }
        return String(target.map { char in
            if char == "-" || char == "_" || char == "." { return char }
            return scrambleCharset.randomElement() ?? char
        })
    }
}

private struct CipherCell: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    var displayed: String
    var target: String
    var isEncode: Bool
    var scrambleFramesLeft: Int
    var opacity: Double
    let fontSize: CGFloat

    var isScrambling: Bool { scrambleFramesLeft > 0 }
}
