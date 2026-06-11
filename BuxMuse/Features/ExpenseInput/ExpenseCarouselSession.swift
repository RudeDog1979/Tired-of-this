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

    /// Active hero carousel page — drives the compact island subtitle on iPhone.
    @Published private(set) var activePageIndex: Int = 0

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

    func syncActivePage(_ index: Int) {
        guard activePageIndex != index else { return }
        activePageIndex = index
    }

    private func resetAnimationState() {
        playedPages.removeAll()
        pageProgress.removeAll()
        playRequest = UUID()
    }
}
