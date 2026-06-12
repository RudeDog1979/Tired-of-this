//
//  MoneyMapLayoutStore.swift
//  BuxMuse
//
//  Single source of truth for user-dragged Money Map node offsets.
//

import Combine
import CoreGraphics
import Foundation

@MainActor
final class MoneyMapLayoutStore: ObservableObject {
    static let shared = MoneyMapLayoutStore()

    @Published private(set) var offsets: [String: CGSize] = [:]

    private static let key = "buxmuse.moneymap.nodeOffsets"

    private init() {
        offsets = Self.readFromDisk()
    }

    func offset(for nodeID: String) -> CGSize {
        offsets[nodeID] ?? .zero
    }

    func setOffset(_ offset: CGSize, for nodeID: String) {
        var next = offsets
        if offset == .zero {
            next.removeValue(forKey: nodeID)
        } else {
            next[nodeID] = offset
        }
        apply(next)
    }

    func apply(_ next: [String: CGSize]) {
        offsets = next
        Self.writeToDisk(next)
    }

    func resetAll() {
        offsets = [:]
        UserDefaults.standard.removeObject(forKey: Self.key)
    }

    var layoutToken: String {
        guard !offsets.isEmpty else { return "default" }
        return offsets.keys.sorted().map { id in
            let o = offsets[id]!
            return "\(id):\(Int(o.width.rounded())):\(Int(o.height.rounded()))"
        }.joined(separator: ";")
    }

    private static func readFromDisk() -> [String: CGSize] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let raw = try? JSONDecoder().decode([String: CodableSize].self, from: data) else {
            return [:]
        }
        return raw.mapValues { CGSize(width: $0.w, height: $0.h) }
    }

    private static func writeToDisk(_ offsets: [String: CGSize]) {
        let encoded = offsets.mapValues { CodableSize(w: Double($0.width), h: Double($0.height)) }
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private struct CodableSize: Codable {
        let w: Double
        let h: Double
    }
}
