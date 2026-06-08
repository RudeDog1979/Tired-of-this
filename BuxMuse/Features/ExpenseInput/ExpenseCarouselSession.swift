//
//  ExpenseCarouselSession.swift
//  BuxMuse
//
//  Persists hero carousel animation state across tab switches.
//

import Combine
import Foundation

@MainActor
final class ExpenseCarouselSession: ObservableObject {
    static let shared = ExpenseCarouselSession()

    /// Only published when a full replay is requested — not on every animation frame.
    @Published private(set) var playRequest = UUID()

    /// Persisted across tab switches; intentionally not @Published.
    var playedPages: Set<Int> = []
    var pageProgress: [Int: Double] = [:]

    private(set) var hasPlayedInitialCarousel = false
    private(set) var lastAnimatedDataToken: String?

    private init() {}

    func playInitialIfNeeded(dataToken: String) {
        guard !hasPlayedInitialCarousel else { return }
        hasPlayedInitialCarousel = true
        lastAnimatedDataToken = dataToken
        resetAnimationState()
    }

    func bumpForDataChange(dataToken: String) {
        guard lastAnimatedDataToken != dataToken else { return }
        lastAnimatedDataToken = dataToken
        if !hasPlayedInitialCarousel {
            hasPlayedInitialCarousel = true
        }
        resetAnimationState()
    }

    func syncPlaybackState(playedPages: Set<Int>, pageProgress: [Int: Double]) {
        self.playedPages = playedPages
        self.pageProgress = pageProgress
    }

    private func resetAnimationState() {
        playedPages.removeAll()
        pageProgress.removeAll()
        playRequest = UUID()
    }
}
