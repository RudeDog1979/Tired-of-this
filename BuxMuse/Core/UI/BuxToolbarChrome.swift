//
//  BuxToolbarChrome.swift
//  BuxMuse
//
//  Shared navigation bar presence + native Liquid Glass toolbar icon buttons.
//

import SwiftUI

enum BuxToolbarMetrics {
    static let iconPointSize: CGFloat = 20
    static let iconWeight: Font.Weight = .semibold
    static let navButtonSize: CGFloat = 44
    static let profileAvatarSize: CGFloat = 28
    /// Softer accent on prominent toolbar actions (e.g. Expenses +).
    static let prominentAccentOpacity: CGFloat = 0.78
}

/// Standard SF Symbol sizing for navigation bar actions (legacy — prefer BuxNavIconButton).
struct BuxToolbarIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: BuxToolbarMetrics.iconPointSize, weight: BuxToolbarMetrics.iconWeight))
            .symbolRenderingMode(.monochrome)
    }
}

// MARK: - Native glass circle (iOS 26+) + material fallback

private struct BuxToolbarNativeGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    var prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), settings.useGlassmorphism {
            content.buxApplyNativeToolbarGlass(prominent: prominent)
        } else if settings.useGlassmorphism {
            content
                .buttonStyle(.plain)
                .background {
                    if prominent {
                        Circle()
                            .fill(
                                themeManager.current.accentColor
                                    .opacity(BuxToolbarMetrics.prominentAccentOpacity)
                            )
                            .frame(
                                width: BuxToolbarMetrics.navButtonSize,
                                height: BuxToolbarMetrics.navButtonSize
                            )
                    } else {
                        BuxGlassCircleBackground(diameter: BuxToolbarMetrics.navButtonSize)
                    }
                }
                .clipShape(Circle())
                .contentShape(Circle())
        } else {
            content.buttonStyle(.plain)
        }
    }
}

@available(iOS 26.0, *)
extension View {
    @ViewBuilder
    fileprivate func buxApplyNativeToolbarGlass(prominent: Bool) -> some View {
        if prominent {
            buttonBorderShape(.circle)
                .buttonStyle(GlassProminentButtonStyle())
        } else {
            buttonBorderShape(.circle)
                .buttonStyle(GlassButtonStyle())
        }
    }
}

extension View {
    func buxToolbarNativeGlassCircle(prominent: Bool = false) -> some View {
        modifier(BuxToolbarNativeGlassModifier(prominent: prominent))
    }
}

// MARK: - Glass circle nav button

struct BuxNavIconButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    let systemName: String
    var accessibilityLabel: String
    var useAccent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .fontWeight(.regular)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(useAccent ? Color.white : iconForeground)
        }
        .tint(useAccent ? themeManager.current.accentColor.opacity(BuxToolbarMetrics.prominentAccentOpacity) : .primary)
        .buxToolbarNativeGlassCircle(prominent: useAccent)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconForeground: Color {
        themeManager.labelPrimary(for: colorScheme)
    }
}

// MARK: - Profile toolbar (Menu label)

struct BuxProfileToolbarLabel: View {
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        if let data = settings.profileAvatarData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: BuxToolbarMetrics.profileAvatarSize, height: BuxToolbarMetrics.profileAvatarSize)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: BuxToolbarMetrics.iconPointSize, weight: .regular))
                .symbolRenderingMode(.monochrome)
        }
    }
}

/// Studio / profile Menu — circular native glass chrome on the label.
struct BuxProfileToolbarMenu<MenuContent: View>: View {
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            BuxProfileToolbarLabel()
        }
        .buxToolbarNativeGlassCircle()
        .accessibilityLabel("Profile")
    }
}

typealias BuxProfileToolbarAvatar = BuxProfileToolbarLabel

struct BuxProfileToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BuxProfileToolbarLabel()
        }
        .buxToolbarNativeGlassCircle()
        .accessibilityLabel("Profile")
    }
}

extension View {
    func buxPolishedNavigationBar() -> some View {
        toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }

    func buxRootNavigationChrome() -> some View {
        buxPolishedNavigationBar()
            .buxStableNavigationBarWithKeyboard()
    }
}
