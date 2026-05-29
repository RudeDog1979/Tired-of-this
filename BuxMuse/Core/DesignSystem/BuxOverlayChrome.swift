//
//  BuxOverlayChrome.swift
//  BuxMuse
//
//  Shared overlay shell — detail hubs, full-screen modals (visual only).
//

import SwiftUI

// MARK: - Icon button (glass / material — labelPrimary glyph)

struct BuxIconButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let systemImage: String
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                BuxGlassCircleBackground(diameter: 44)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(BuxMicroShrinkStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Overlay header

struct BuxOverlayHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let onBack: () -> Void
    var backAccessibilityLabel: String = "Back"

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

            HStack {
                BuxIconButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: backAccessibilityLabel,
                    action: onBack
                )
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, BuxLayout.marginHorizontal)
        .padding(.top, BuxOverlayMetrics.headerTopInset)
        .padding(.bottom, BuxLayout.section)
    }
}

enum BuxOverlayMetrics {
    static let headerTopInset: CGFloat = 60
    static let scrollBottomInset: CGFloat = 80
}

// MARK: - Detail overlay scaffold

struct BuxDetailOverlayScaffold<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let title: String
    let onDismiss: () -> Void
    var showsBackdropDismiss: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            BuxHeroMeshBackground()

            if showsBackdropDismiss {
                Color.black.opacity(colorScheme == .dark ? 0.55 : 0.35)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }
            }

            VStack(spacing: 0) {
                BuxOverlayHeader(title: title, onBack: onDismiss)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: BuxLayout.section) {
                        content()
                    }
                    .padding(.vertical, BuxLayout.section)
                    .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                    .buxScreenContentMargins()
                }
                .buxReportsContainerWidth()
            }
        }
    }
}

// MARK: - Card helpers

extension View {
    /// Standard detail-hub card padding + mesh chrome.
    func buxDetailSectionCard(cornerRadius: CGFloat = BuxDetailStyle.cardRadius) -> some View {
        padding(BuxDetailStyle.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .buxDetailCard(cornerRadius: cornerRadius)
    }

    func buxDetailRowCard(minHeight: CGFloat? = nil) -> some View {
        padding(BuxDetailStyle.cardPadding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .buxDetailCard(cornerRadius: BuxDetailStyle.rowCardRadius)
    }
}
