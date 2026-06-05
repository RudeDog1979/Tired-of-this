//
//  ProBusinessCardStudioLanding.swift
//  BuxMuse
//
//  Premium landing — featured hero deck + compact template rows.
//

import SwiftUI

// MARK: - Ribbon headers

struct BusinessCardStudioRibbon: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(BusinessCardL10n.line(title, locale: appSettingsManager.interfaceLocale).uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.current.accentColor,
                            themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.55 : 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.28), lineWidth: 0.5)
                }
        }
        .shadow(color: themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14), radius: 10, y: 4)
    }
}

// MARK: - Featured carousel (hero deck)

struct BusinessCardFeaturedCarousel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @Binding var featuredTemplate: ProBusinessCardTemplate
    let templates: [ProBusinessCardTemplate]
    let preview: (ProBusinessCardTemplate) -> ProBusinessCardDesign
    let logoData: Data?
    var onStart: (ProBusinessCardTemplate) -> Void

    /// Hero deck — noticeably larger than template rows below.
    private var cardWidth: CGFloat {
        min(UIScreen.main.bounds.width * 0.92, 390)
    }

    private var featuredMaxScale: CGFloat { 0.94 }

    private var carouselHeight: CGFloat {
        let maxThumb = templates.map {
            BusinessCardGalleryScale.thumbHeight(design: preview($0), slotWidth: cardWidth, maxScale: featuredMaxScale)
        }.max() ?? 180
        return maxThumb + 62
    }

    private var activeBinding: Binding<ProBusinessCardTemplate?> {
        Binding(
            get: { featuredTemplate },
            set: { if let v = $0 { featuredTemplate = v } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessCardStudioRibbon(
                title: "Featured looks",
                subtitle: BusinessCardL10n.line("Swipe the deck — tap to open", locale: appSettingsManager.interfaceLocale),
                systemImage: "sparkles"
            )

            BusinessCardLayeredCarousel(
                activeID: activeBinding,
                items: templates,
                cardWidth: cardWidth,
                height: carouselHeight,
                spacing: -32,
                contentMargins: 20
            ) { template in
                templateLabel(template)
            } card: { template, isActive in
                featuredCard(template, isActive: isActive)
            }
            .environmentObject(themeManager)
        }
    }

    private func featuredCard(_ template: ProBusinessCardTemplate, isActive: Bool) -> some View {
        let design = preview(template)
        let scale = BusinessCardGalleryScale.thumbScale(design: design, slotWidth: cardWidth, maxScale: featuredMaxScale)

        return BusinessCardCarouselTapCard(isActive: isActive, accentShadow: true) {
            onStart(template)
        } content: {
            ProBusinessCardDesignThumbnail(
                design: design,
                logoData: logoData,
                scale: scale,
                galleryPreview: true
            )
            .frame(maxWidth: .infinity)
        }
    }

    private func templateLabel(_ template: ProBusinessCardTemplate) -> some View {
        VStack(spacing: 3) {
            Text(template.catalogTitle(locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            Text(template.catalogSubtitle(locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            BuxCatalogDynamicText(key: "Tap to open")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(themeManager.current.accentColor)
        }
        .frame(maxWidth: cardWidth)
        .opacity(template == featuredTemplate ? 1 : 0.6)
    }
}

// MARK: - All templates showcase (compact decks)

struct BusinessCardTemplateShowcase: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let preview: (ProBusinessCardTemplate) -> ProBusinessCardDesign
    let logoData: Data?
    var onStart: (ProBusinessCardTemplate) -> Void

    @State private var activeByCollection: [ProBusinessCardCollection: ProBusinessCardTemplate] = [:]

    private var deckWidth: CGFloat {
        min(UIScreen.main.bounds.width * 0.66, 268)
    }

    private var templateMaxScale: CGFloat { 0.72 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BusinessCardStudioRibbon(
                title: "All templates",
                subtitle: BusinessCardL10n.format(
                    "%lld geometric & editorial presets",
                    locale: appSettingsManager.interfaceLocale,
                    Int64(ProBusinessCardTemplate.launchTemplates.count)
                ),
                systemImage: "square.grid.3x3.fill"
            )

            ForEach(ProBusinessCardCollection.allCases) { collection in
                collectionDeck(collection)
            }
        }
        .onAppear {
            for collection in ProBusinessCardCollection.allCases {
                if activeByCollection[collection] == nil {
                    activeByCollection[collection] = collection.templates.first
                }
            }
        }
    }

    private func collectionDeck(_ collection: ProBusinessCardCollection) -> some View {
        let templates = collection.templates
        let binding = Binding<ProBusinessCardTemplate?>(
            get: { activeByCollection[collection] ?? templates.first },
            set: { if let v = $0 { activeByCollection[collection] = v } }
        )
        let deckHeight = templates.map {
            BusinessCardGalleryScale.thumbHeight(design: preview($0), slotWidth: deckWidth, maxScale: templateMaxScale)
        }.max().map { $0 + 40 } ?? 180

        return VStack(alignment: .leading, spacing: 8) {
            Text(collection.catalogTitle(locale: appSettingsManager.interfaceLocale))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.current.accentColor)
                .padding(.leading, 2)

            BusinessCardLayeredCarousel(
                activeID: binding,
                items: templates,
                cardWidth: deckWidth,
                height: deckHeight,
                spacing: -16,
                contentMargins: 20,
                showsPageIndicator: templates.count > 2
            ) { template in
                Text(template.catalogTitle(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: deckWidth, alignment: .center)
            } card: { template, isActive in
                templateCard(template, isActive: isActive)
            }
            .environmentObject(themeManager)
        }
    }

    private func templateCard(_ template: ProBusinessCardTemplate, isActive: Bool) -> some View {
        let design = preview(template)
        let scale = BusinessCardGalleryScale.thumbScale(design: design, slotWidth: deckWidth, maxScale: templateMaxScale)

        return BusinessCardCarouselTapCard(isActive: isActive, accentShadow: false) {
            onStart(template)
        } content: {
            ProBusinessCardDesignThumbnail(
                design: design,
                logoData: logoData,
                scale: scale,
                galleryPreview: true
            )
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Tappable carousel card

struct BusinessCardCarouselTapCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var isActive: Bool
    var accentShadow: Bool
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                if isActive && accentShadow {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.clear)
                        .shadow(
                            color: themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.16),
                            radius: 10,
                            y: 7
                        )
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 4)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action()
                }
            )
            .accessibilityAddTraits(.isButton)
    }
}
