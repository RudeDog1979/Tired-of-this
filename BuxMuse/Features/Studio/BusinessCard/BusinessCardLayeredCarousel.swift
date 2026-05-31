//
//  BusinessCardLayeredCarousel.swift
//  BuxMuse
//
//  Scroll-based layered carousel — floating cards, no hard edge masks.
//

import SwiftUI

struct BusinessCardLayeredCarousel<Item: Hashable, Label: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var activeID: Item?
    let items: [Item]
    var cardWidth: CGFloat
    var height: CGFloat
    var spacing: CGFloat = -26
    var contentMargins: CGFloat = 44
    var showsPageIndicator: Bool = true
    @ViewBuilder var label: (Item) -> Label
    @ViewBuilder var card: (Item, Bool) -> AnyView

    init(
        activeID: Binding<Item?>,
        items: [Item],
        cardWidth: CGFloat,
        height: CGFloat,
        spacing: CGFloat = -26,
        contentMargins: CGFloat = 44,
        showsPageIndicator: Bool = true,
        @ViewBuilder label: @escaping (Item) -> Label,
        @ViewBuilder card: @escaping (Item, Bool) -> some View
    ) {
        _activeID = activeID
        self.items = items
        self.cardWidth = cardWidth
        self.height = height
        self.spacing = spacing
        self.contentMargins = contentMargins
        self.showsPageIndicator = showsPageIndicator
        self.label = label
        self.card = { item, active in AnyView(card(item, active)) }
    }

    private var activeIndex: Int {
        guard let activeID, let idx = items.firstIndex(where: { $0 == activeID }) else { return 0 }
        return idx
    }

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        let isActive = item == activeID
                        VStack(spacing: 8) {
                            card(item, isActive)
                                .frame(width: cardWidth)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                        .opacity(phase.isIdentity ? 1 : 0.78)
                                }
                            label(item)
                        }
                        .zIndex(layerOrder(for: index))
                        .id(item)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 12)
            }
            .scrollClipDisabled()
            .contentMargins(.horizontal, contentMargins, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $activeID)
            .frame(height: height)

            if showsPageIndicator, items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { index in
                        Capsule()
                            .fill(
                                index == activeIndex
                                    ? themeManager.current.accentColor
                                    : themeManager.pillInactiveLabelColor(for: colorScheme).opacity(0.35)
                            )
                            .frame(width: index == activeIndex ? 18 : 6, height: 6)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.86), value: activeIndex)
            }
        }
    }

    private func layerOrder(for index: Int) -> Double {
        let distance = abs(Double(index - activeIndex))
        return max(10 - distance, 0.1)
    }
}

/// Scale helper shared by landing carousels.
enum BusinessCardGalleryScale {
    static func thumbScale(design: ProBusinessCardDesign, slotWidth: CGFloat, maxScale: CGFloat = 0.82) -> CGFloat {
        let cardW = design.aspect.previewSize.width
        guard cardW > 0 else { return maxScale }
        return min(maxScale, slotWidth / cardW)
    }

    static func thumbHeight(design: ProBusinessCardDesign, slotWidth: CGFloat, maxScale: CGFloat = 0.82) -> CGFloat {
        design.aspect.previewSize.height * thumbScale(design: design, slotWidth: slotWidth, maxScale: maxScale)
    }
}
