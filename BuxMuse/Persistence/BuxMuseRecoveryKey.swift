//
//  BuxMuseRecoveryKey.swift
//  BuxMuse
//
//  Human-readable recovery keys for encrypted backups — never persisted by BuxMuse.
//

import Foundation
import Security

enum BuxMuseRecoveryKey {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    private static let payloadLength = 20

    /// Generates a new recovery key, e.g. `BM-7KHD-9FMT-2PLQ-8XWN-4JRS-6CYV-0ABT`
    static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: payloadLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, payloadLength, &bytes)
        guard status == errSecSuccess else {
            return format(randomFallbackBytes())
        }
        return format(bytes)
    }

    /// Strips dashes/spaces for key derivation input.
    static func normalized(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("BM") {
            return trimmed
                .replacingOccurrences(of: "BM-", with: "BM")
                .replacingOccurrences(of: "-", with: "")
                .filter { $0.isLetter || $0.isNumber }
        }
        return trimmed.filter { $0.isLetter || $0.isNumber }
    }

    static func isRecoveryKeyFormat(_ input: String) -> Bool {
        normalized(input).hasPrefix("BM") && normalized(input).count >= 10
    }

    static func displayFormatted(_ normalized: String) -> String {
        let core = normalized.hasPrefix("BM") ? String(normalized.dropFirst(2)) : normalized
        let chunks = stride(from: 0, to: core.count, by: 4).map { start in
            let end = min(start + 4, core.count)
            let s = core.index(core.startIndex, offsetBy: start)
            let e = core.index(core.startIndex, offsetBy: end)
            return String(core[s..<e])
        }
        return "BM-" + chunks.joined(separator: "-")
    }

    private static func format(_ bytes: [UInt8]) -> String {
        var output = "BM"
        var buffer = 0
        var bits = 0
        for byte in bytes {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                let index = (buffer >> bits) & 31
                output.append(alphabet[index])
            }
        }
        if bits > 0 {
            let index = (buffer << (5 - bits)) & 31
            output.append(alphabet[index])
        }
        return displayFormatted(output)
    }

    private static func randomFallbackBytes() -> [UInt8] {
        (0..<payloadLength).map { _ in UInt8.random(in: 0...255) }
    }
}

public struct BuxMuseBackupResult: Equatable {
    public let archiveData: Data
    public let recoveryKey: String?
    public let usesRecoveryKey: Bool
}
