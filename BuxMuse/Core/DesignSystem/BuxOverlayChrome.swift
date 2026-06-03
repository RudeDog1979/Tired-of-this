//
//  BuxOverlayChrome.swift
//  BuxMuse
//
//  Shared overlay shell — detail hubs, full-screen modals (visual only).
//

import SwiftUI

enum BuxOverlayMetrics {
    static let headerTopInset: CGFloat = 60
    static let scrollBottomInset: CGFloat = 80
}

// MARK: - Detail overlay scaffold

struct BuxDetailOverlayScaffold<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    let title: String
    /// When true, `title` is looked up in `Localizable.xcstrings` (e.g. "Goal Details"). Merchant names should pass false.
    var localizeTitle: Bool = true
    let onDismiss: () -> Void
    var showsBackdropDismiss: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()

                if showsBackdropDismiss {
                    Color.black.opacity(colorScheme == .dark ? 0.55 : 0.35)
                        .ignoresSafeArea()
                        .onTapGesture { onDismiss() }
                }

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: BuxLayout.section) {
                        content()
                    }
                    .padding(.vertical, BuxLayout.section)
                    .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                    .buxScreenContentMargins()
                }
                .buxDetailScrollChrome()
            }
            .navigationTitle(
                localizeTitle
                    ? BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale)
                    : title
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BuxToolbarBackButton(action: onDismiss)
                }
            }
            .buxDetailNavigationChrome()
            .buxInterfaceLocale()
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
