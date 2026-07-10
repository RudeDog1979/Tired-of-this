//
//  AppTutorialOverlay.swift
//  BuxMuse
//

import SwiftUI

struct TutorialCoachMarkOverlayLayer: View {
    let layer: TutorialCoachMarkLayer
    @ObservedObject var coordinator: AppTutorialCoordinator
    let globalFrames: [TutorialAnchorID: CGRect]
    var reservesTabBarSpace: Bool = false

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var frozenStepID: String?
    @State private var frozenGlobalHighlight: CGRect?
    @State private var freezeTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            if layer.shouldShow(for: coordinator), let step = coordinator.currentStep {
                let overlayOrigin = geometry.frame(in: .global).origin
                let liveHighlight = tutorialHighlightRect(
                    for: step.anchor,
                    globalFrames: globalFrames,
                    overlayOrigin: overlayOrigin
                )
                let displayHighlight = displayHighlight(
                    for: step,
                    live: liveHighlight,
                    overlayOrigin: overlayOrigin
                )

                ZStack(alignment: .topLeading) {
                    TutorialScrimLayer(highlight: displayHighlight)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    if let displayHighlight {
                        BuxCoachMarkHighlightRing(
                            rect: displayHighlight,
                            accent: themeManager.contrastAccentColor(for: colorScheme)
                        )
                    }

                    coachMarkCard(
                        step: step,
                        cardWidth: BuxCoachMarkCalloutLayout.cardWidth(for: geometry.size.width),
                        placement: step.anchor?.coachMarkCardPlacement ?? .bottom,
                        safeInsets: geometry.safeAreaInsets
                    )
                }
                .onAppear {
                    scheduleFreeze(step: step, globalHighlight: globalHighlight(for: step.anchor))
                }
                .onChange(of: step.id) { _, _ in
                    clearFreeze()
                    scheduleFreeze(step: step, globalHighlight: globalHighlight(for: step.anchor))
                }
                .onChange(of: frameToken(for: step.anchor)) { _, _ in
                    scheduleFreeze(step: step, globalHighlight: globalHighlight(for: step.anchor))
                }
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .zIndex(10_000)
        .allowsHitTesting(layer.shouldShow(for: coordinator))
    }

    private func globalHighlight(for anchorID: TutorialAnchorID?) -> CGRect? {
        guard let anchorID, let global = globalFrames[anchorID] else { return nil }
        guard global.width > 1, global.height > 1 else { return nil }
        return global.insetBy(
            dx: -BuxCoachMarkCalloutLayout.highlightPadding,
            dy: -BuxCoachMarkCalloutLayout.highlightPadding
        )
    }

    private func calloutBottomInset(safeInsets: EdgeInsets) -> CGFloat {
        let tabBarHeight: CGFloat = reservesTabBarSpace ? 49 : 0
        return max(16, safeInsets.bottom + 12 + tabBarHeight)
    }

    private func frameToken(for anchorID: TutorialAnchorID?) -> String {
        guard let anchorID, let frame = globalFrames[anchorID] else { return "missing" }
        return "\(anchorID.rawValue)-\(Int(frame.origin.x))-\(Int(frame.origin.y))-\(Int(frame.width))-\(Int(frame.height))"
    }

    private func displayHighlight(
        for step: TutorialStepDefinition,
        live: CGRect?,
        overlayOrigin: CGPoint
    ) -> CGRect? {
        if frozenStepID == step.id, let frozenGlobalHighlight {
            return frozenGlobalHighlight.offsetBy(dx: -overlayOrigin.x, dy: -overlayOrigin.y)
        }
        return live
    }

    private func clearFreeze() {
        freezeTask?.cancel()
        frozenStepID = nil
        frozenGlobalHighlight = nil
    }

    private func scheduleFreeze(step: TutorialStepDefinition, globalHighlight: CGRect?) {
        freezeTask?.cancel()
        let stepID = step.id
        guard let globalHighlight else { return }

        freezeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled, coordinator.currentStep?.id == stepID else { return }
            frozenStepID = stepID
            frozenGlobalHighlight = globalHighlight
        }
    }

    @ViewBuilder
    private func coachMarkCard(
        step: TutorialStepDefinition,
        cardWidth: CGFloat,
        placement: TutorialCoachMarkCardPlacement,
        safeInsets: EdgeInsets
    ) -> some View {
        let fill = themeManager.cardFill(for: colorScheme)
        let card = BuxCoachMarkPopover(
            progressLabel: coordinator.stepProgressLabel,
            titleKey: step.titleKey,
            bodyKey: step.bodyKey,
            primaryButtonKey: step.isFinishStep ? "Finish tour" : "Next",
            showsSkip: true,
            onPrimary: { coordinator.advanceNext() },
            onSkip: { coordinator.skipTour() }
        )
        .environmentObject(themeManager)
        .environmentObject(appSettingsManager)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fill)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        switch placement {
        case .bottom:
            card
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 16)
                .padding(.bottom, calloutBottomInset(safeInsets: safeInsets))
        case .screenCenter:
            card
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 16)
        }
    }
}

extension AppTutorialOverlay {
    static func showsAtRoot(for coordinator: AppTutorialCoordinator) -> Bool {
        TutorialCoachMarkLayer.root.shouldShow(for: coordinator)
    }

    static func showsInSheet(for coordinator: AppTutorialCoordinator) -> Bool {
        guard coordinator.isActive else { return false }
        guard let anchor = coordinator.currentStep?.anchor else { return false }
        return anchor.hostsInSheet
    }

    static func showsInSettingsDetail(for coordinator: AppTutorialCoordinator) -> Bool {
        guard coordinator.isActive else { return false }
        guard let anchor = coordinator.currentStep?.anchor else { return false }
        return anchor.hostsInSettingsDetail
    }
}

enum AppTutorialOverlay {}
