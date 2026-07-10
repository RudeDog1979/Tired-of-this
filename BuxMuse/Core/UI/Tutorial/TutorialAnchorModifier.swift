//
//  TutorialAnchorModifier.swift
//  BuxMuse
//

import SwiftUI

struct TutorialAnchorGlobalFrameKey: PreferenceKey {
    static var defaultValue: [TutorialAnchorID: CGRect] = [:]

    static func reduce(
        value: inout [TutorialAnchorID: CGRect],
        nextValue: () -> [TutorialAnchorID: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

enum TutorialCoachMarkLayer {
    case dashboard
    case root
    case sheet
    case settingsDetail

    private static func isDashboardAnchor(_ anchor: TutorialAnchorID) -> Bool {
        switch anchor {
        case .homeBudgetRing, .homeIncomeButton, .homeExpenseButton, .homeDebtDiscovery, .homeStudioDiscovery, .homeFinish:
            return true
        default:
            return false
        }
    }

    /// Root-level overlay layer (dashboard + tab steps). Sheet/detail layers render locally.
    static func rootOverlayLayer(for coordinator: AppTutorialCoordinator) -> TutorialCoachMarkLayer? {
        guard coordinator.isActive, let anchor = coordinator.currentStep?.anchor else { return nil }
        if anchor.hostsInSheet || anchor.hostsInSettingsDetail { return nil }
        if isDashboardAnchor(anchor) { return .dashboard }
        return .root
    }

    func shouldShow(for coordinator: AppTutorialCoordinator) -> Bool {
        guard coordinator.isActive, let anchor = coordinator.currentStep?.anchor else {
            return false
        }
        switch self {
        case .dashboard:
            return Self.isDashboardAnchor(anchor)
        case .root:
            return !anchor.hostsInSheet
                && !anchor.hostsInSettingsDetail
                && !Self.isDashboardAnchor(anchor)
        case .sheet:
            return anchor.hostsInSheet
        case .settingsDetail:
            return anchor.hostsInSettingsDetail
        }
    }
}

struct TutorialAnchorModifier: ViewModifier {
    let id: TutorialAnchorID

    func body(content: Content) -> some View {
        content
            .id(id.rawValue)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TutorialAnchorGlobalFrameKey.self,
                        value: [id: proxy.frame(in: .global)]
                    )
                }
            }
    }
}

extension View {
    func tutorialAnchor(
        _ id: TutorialAnchorID,
        coordinator: AppTutorialCoordinator
    ) -> some View {
        modifier(TutorialAnchorModifier(id: id))
    }

    func tutorialScrollToActiveAnchor(
        coordinator: AppTutorialCoordinator,
        proxy: ScrollViewProxy
    ) -> some View {
        onChange(of: coordinator.currentStep?.id) { _, stepID in
            scrollTutorialAnchor(stepID: stepID, coordinator: coordinator, proxy: proxy)
        }
        .onChange(of: coordinator.layoutEpoch) { _, _ in
            scrollTutorialAnchor(
                stepID: coordinator.currentStep?.id,
                coordinator: coordinator,
                proxy: proxy
            )
        }
    }

    func tutorialCoachMarkOverlay(
        layer: TutorialCoachMarkLayer,
        coordinator: AppTutorialCoordinator,
        reservesTabBarSpace: Bool = false
    ) -> some View {
        overlayPreferenceValue(TutorialAnchorGlobalFrameKey.self) { globalFrames in
            TutorialCoachMarkOverlayLayer(
                layer: layer,
                coordinator: coordinator,
                globalFrames: globalFrames,
                reservesTabBarSpace: reservesTabBarSpace
            )
        }
    }

    /// Full-screen root tutorial above tab chrome (dashboard + tab-level steps). iPhone and iPad.
    func buxRootTutorialOverlay(coordinator: AppTutorialCoordinator) -> some View {
        overlayPreferenceValue(TutorialAnchorGlobalFrameKey.self) { globalFrames in
            if let layer = TutorialCoachMarkLayer.rootOverlayLayer(for: coordinator) {
                TutorialCoachMarkOverlayLayer(
                    layer: layer,
                    coordinator: coordinator,
                    globalFrames: globalFrames,
                    reservesTabBarSpace: !BuxPadIdiom.isPad
                )
                .zIndex(25_000)
            }
        }
    }

    /// Backward-compatible alias — same behavior on iPhone and iPad.
    func buxPhoneTutorialOverlay(
        coordinator: AppTutorialCoordinator,
        isPad: Bool
    ) -> some View {
        buxRootTutorialOverlay(coordinator: coordinator)
    }
}

private func scrollTutorialAnchor(
    stepID: String?,
    coordinator: AppTutorialCoordinator,
    proxy: ScrollViewProxy
) {
    guard coordinator.isActive, let anchor = coordinator.currentStep?.anchor else { return }
    guard coordinator.currentStep?.id == stepID else { return }

    let scrollAnchor = anchor.tutorialScrollAnchor
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation(.none) {
            proxy.scrollTo(anchor.rawValue, anchor: scrollAnchor)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.none) {
                proxy.scrollTo(anchor.rawValue, anchor: scrollAnchor)
            }
        }
    }
}

func tutorialHighlightRect(
    for anchorID: TutorialAnchorID?,
    globalFrames: [TutorialAnchorID: CGRect],
    overlayOrigin: CGPoint
) -> CGRect? {
    guard let anchorID, let global = globalFrames[anchorID] else { return nil }
    guard global.width > 1, global.height > 1 else { return nil }
    let local = global.offsetBy(dx: -overlayOrigin.x, dy: -overlayOrigin.y)
    return local.insetBy(
        dx: -BuxCoachMarkCalloutLayout.highlightPadding,
        dy: -BuxCoachMarkCalloutLayout.highlightPadding
    )
}
