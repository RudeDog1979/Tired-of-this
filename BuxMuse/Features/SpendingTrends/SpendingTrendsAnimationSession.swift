//
//  SpendingTrendsAnimationSession.swift
//  BuxMuse
//
//  Persists chart entrance state — animate once per period page, like ExpenseCarouselSession.
//

import Combine
import Foundation

@MainActor
final class SpendingTrendsAnimationSession: ObservableObject {
    static let shared = SpendingTrendsAnimationSession()

    /// Anchor ids that already played the chart entrance this session.
    private(set) var playedAnchorIds: Set<String> = []
    /// Frozen progress per anchor — not @Published; views read via playToken bump once.
    private(set) var progressByAnchorId: [String: Double] = [:]

    @Published private(set) var playToken = UUID()

    private init() {}

    func progress(for anchorId: String) -> Double {
        if let value = progressByAnchorId[anchorId] {
            return value
        }
        return playedAnchorIds.contains(anchorId) ? 1 : 0
    }

    func shouldAnimate(_ anchorId: String) -> Bool {
        !playedAnchorIds.contains(anchorId)
    }

    func commitProgress(_ value: Double, for anchorId: String) {
        progressByAnchorId[anchorId] = value
        if value >= 1 {
            playedAnchorIds.insert(anchorId)
        }
        playToken = UUID()
    }

    func requestEntrance(for anchorId: String) {
        guard shouldAnimate(anchorId) else {
            progressByAnchorId[anchorId] = 1
            return
        }
        progressByAnchorId[anchorId] = 0
        playToken = UUID()
    }

    func finishEntrance(for anchorId: String) {
        playedAnchorIds.insert(anchorId)
        progressByAnchorId[anchorId] = 1
        playToken = UUID()
    }
}
