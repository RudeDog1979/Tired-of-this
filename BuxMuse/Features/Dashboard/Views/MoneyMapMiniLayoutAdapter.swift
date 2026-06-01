//
//  MoneyMapMiniLayoutAdapter.swift
//  BuxMuse
//
//  Maps full-map saved drag offsets onto the dashboard mini preview.
//

import CoreGraphics

enum MoneyMapMiniLayoutAdapter {
    private static let fullStagePadding: CGFloat = 24
    private static let miniStagePadding: CGFloat = 20

    /// Converts a persisted full-map offset into the mini canvas equivalent.
    static func miniOffset(
        for node: MoneyMapNode,
        graph: MoneyMapGraph,
        storedFullOffset: CGSize,
        miniContentSize: CGSize,
        isLandscape: Bool
    ) -> CGSize {
        guard storedFullOffset != .zero, miniContentSize.width > 1, miniContentSize.height > 1 else {
            return .zero
        }

        let fullContentSize = referenceFullContentSize(matchingWidth: miniContentSize.width, isLandscape: isLandscape)
        let fullBase = basePoint(for: node, graph: graph, contentSize: fullContentSize, mode: .full, isLandscape: isLandscape)
        let fullFinal = CGPoint(
            x: fullBase.x + storedFullOffset.width,
            y: fullBase.y + storedFullOffset.height
        )

        let miniBase = basePoint(for: node, graph: graph, contentSize: miniContentSize, mode: .mini, isLandscape: isLandscape)
        let scaledFinal = CGPoint(
            x: fullFinal.x / fullContentSize.width * miniContentSize.width,
            y: fullFinal.y / fullContentSize.height * miniContentSize.height
        )

        return CGSize(width: scaledFinal.x - miniBase.x, height: scaledFinal.y - miniBase.y)
    }

    private static func referenceFullContentSize(matchingWidth miniWidth: CGFloat, isLandscape: Bool) -> CGSize {
        // Dashboard + full map share the same horizontal inset; stage padding differs by 4pt.
        let fullWidth = miniWidth + miniStagePadding - fullStagePadding
        let fullHeight = MoneyMapDisplayMode.full.canvasHeight(isLandscape: isLandscape) - fullStagePadding
        return CGSize(width: max(1, fullWidth), height: max(1, fullHeight))
    }

    private static func basePoint(
        for node: MoneyMapNode,
        graph: MoneyMapGraph,
        contentSize: CGSize,
        mode: MoneyMapDisplayMode,
        isLandscape: Bool
    ) -> CGPoint {
        let margin = layoutMargin(in: contentSize, graph: graph, mode: mode, isLandscape: isLandscape)
        let center = CGPoint(x: contentSize.width / 2, y: contentSize.height / 2)
        let usableW = contentSize.width - margin * 2
        let usableH = contentSize.height - margin * 2
        let maxRing = CGFloat(graph.nodes.map(\.ring).max() ?? 0)
        let ringStep: CGFloat = mode == .mini ? 14 : 18
        let nodeRadius = maxNodeRadius(graph: graph, mode: mode)
        let labelAllowance: CGFloat = mode == .full ? 20 : 4
        let maxOrbit = min(usableW, usableH) / 2 - nodeRadius - labelAllowance
        let requestedBase = min(usableW, usableH) * mode.radiusScale(isLandscape: isLandscape)
        let ringSpan = maxRing * ringStep
        let baseRadius = min(requestedBase, max(0, maxOrbit - ringSpan))
        let ringOffset = CGFloat(node.ring) * ringStep
        let rx = (baseRadius + ringOffset) * (isLandscape ? 1.08 : 1.0)
        let ry = (baseRadius + ringOffset) * (isLandscape ? 0.90 : 1.0)
        return CGPoint(x: center.x + cos(node.angle) * rx, y: center.y + sin(node.angle) * ry)
    }

    private static func maxNodeRadius(graph: MoneyMapGraph, mode: MoneyMapDisplayMode) -> CGFloat {
        let maxWeight = graph.nodes.map(\.weight).max() ?? 1
        return (36 + maxWeight * 22) * mode.nodeScale / 2
    }

    private static func layoutMargin(
        in size: CGSize,
        graph: MoneyMapGraph,
        mode: MoneyMapDisplayMode,
        isLandscape: Bool
    ) -> CGFloat {
        mode.edgeInset(isLandscape: isLandscape) + maxNodeRadius(graph: graph, mode: mode) + (mode == .full ? 8 : 4)
    }
}
