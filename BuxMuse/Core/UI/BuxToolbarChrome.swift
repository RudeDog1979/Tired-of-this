//
//  BuxToolbarChrome.swift
//  BuxMuse
//
//  Let Apple style toolbar controls — no .glass / .circle forced on nav bar items.
//  Only in-content chevrons use explicit round glass (the pattern that already worked).
//

import SwiftUI

enum BuxToolbarMetrics {
    static let iconPointSize: CGFloat = 20
    static let iconWeight: Font.Weight = .semibold
    static let navButtonSize: CGFloat = 44
    static let profileAvatarSize: CGFloat = 28
    static let contentCircleDiameter: CGFloat = 30
}

// MARK: - Glyph

struct BuxToolbarGlyph: View {
    let systemName: String
    var pointSize: CGFloat = BuxToolbarMetrics.iconPointSize
    var weight: Font.Weight = BuxToolbarMetrics.iconWeight

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: pointSize, weight: weight))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.primary)
    }
}

// MARK: - Toolbar icon — glyph only, system styles the bar

struct BuxToolbarIconButton: View {
    let systemName: String
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BuxToolbarGlyph(systemName: systemName)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Role buttons — Apple owns ✕ and ✓ on iOS 26

struct BuxToolbarCancelButton: View {
    let action: () -> Void

    var body: some View {
        if BuxPlatform.supportsCloseRole, #available(iOS 26, *) {
            Button(role: .close, action: action)
                .accessibilityLabel("Cancel")
        } else {
            BuxToolbarIconButton(systemName: "xmark", accessibilityLabel: "Cancel", action: action)
        }
    }
}

struct BuxToolbarConfirmButton: View {
    var accessibilityLabel: String = "Save"
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Group {
            if BuxPlatform.supportsConfirmRole, #available(iOS 26, *) {
                Button(role: .confirm, action: action)
                    .accessibilityLabel(accessibilityLabel)
            } else {
                BuxToolbarIconButton(
                    systemName: "checkmark",
                    accessibilityLabel: accessibilityLabel,
                    action: action
                )
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

struct BuxToolbarDoneButton: View {
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        BuxToolbarConfirmButton(accessibilityLabel: "Done", isEnabled: isEnabled, action: action)
    }
}

struct BuxToolbarDestructiveButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(accessibilityLabel, role: .destructive, action: action)
            .tint(BuxTokens.destructive)
    }
}

// MARK: - Navigation icons (toolbar — no custom glass)

struct BuxToolbarButton: View {
    let systemName: String
    var accessibilityLabel: String
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        BuxToolbarIconButton(systemName: systemName, accessibilityLabel: accessibilityLabel, action: action)
    }
}

struct BuxToolbarBackButton: View {
    let action: () -> Void

    var body: some View {
        BuxToolbarIconButton(systemName: "chevron.left", accessibilityLabel: "Back", action: action)
    }
}

typealias BuxToolbarCloseButton = BuxToolbarCancelButton

struct BuxNavIconButton: View {
    let systemName: String
    var accessibilityLabel: String
    var useAccent: Bool = false
    let action: () -> Void

    var body: some View {
        BuxToolbarIconButton(systemName: systemName, accessibilityLabel: accessibilityLabel, action: action)
    }
}

struct BuxToolbarBellButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let action: () -> Void
    var unreadCount: Int = 0

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: BuxToolbarMetrics.iconPointSize, weight: BuxToolbarMetrics.iconWeight))
                    .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                    .padding(4)
                if unreadCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: -2, y: 2)
                }
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Notifications")
    }
}

/// Menu / NavigationLink label — icon only; never wrap Menu in custom glass.
struct BuxToolbarIcon: View {
    let systemName: String
    var prominent: Bool = false

    var body: some View {
        BuxToolbarGlyph(systemName: systemName)
    }
}

extension View {
    func buxToolbarTextActionStyle(accent: Color) -> some View {
        font(.system(size: 15, weight: .semibold))
            .foregroundStyle(accent)
    }

    /// No-op — do not stack styles on toolbar menus.
    func buxToolbarButtonStyle() -> some View { self }
    func buxToolbarRoundGlassMenuStyle() -> some View { self }
    func buxSystemGlassToolbarStyle() -> some View { self }
    func buxSystemGlassCircleStyle() -> some View { self }
    func buxSystemRoundGlassStyle() -> some View { self }
}

// MARK: - In-content chevrons ONLY — explicit round glass (reference pattern)

struct BuxContentGlassIconButton: View {
    @ObservedObject private var settings = SettingsStore.shared

    let systemName: String
    var diameter: CGFloat = BuxToolbarMetrics.contentCircleDiameter
    var pointSize: CGFloat = 12
    var accessibilityLabel: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BuxToolbarGlyph(systemName: systemName, pointSize: pointSize)
                .frame(width: diameter, height: diameter)
        }
        .applyCardChevronGlass(settings: settings, diameter: diameter)
        .accessibilityLabel(accessibilityLabel.isEmpty ? systemName : accessibilityLabel)
    }
}

private extension View {
    @ViewBuilder
    func applyCardChevronGlass(settings: SettingsStore, diameter: CGFloat) -> some View {
        if settings.useGlassmorphism {
            if #available(iOS 26, *) {
                self
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            } else {
                self
                    .buttonStyle(.plain)
                    .background { BuxGlassCircleBackground(diameter: diameter) }
            }
        } else {
            self.buttonStyle(.plain)
        }
    }
}

extension View {
    /// Hero card round controls — Liquid Glass on iOS 26, material circle fallback.
    @ViewBuilder
    func buxHeroGlassCircleButtonStyle(diameter: CGFloat) -> some View {
        let settings = SettingsStore.shared
        if settings.useGlassmorphism {
            if #available(iOS 26, *) {
                self
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            } else {
                self
                    .buttonStyle(BuxmationPressCardStyle())
                    .background { BuxGlassCircleBackground(diameter: diameter) }
            }
        } else {
            self
                .buttonStyle(BuxmationPressCardStyle())
                .background { BuxGlassCircleBackground(diameter: diameter) }
        }
    }
}

/// Decorative row icon — glyph only.
struct BuxContentGlassIcon: View {
    let systemName: String
    var diameter: CGFloat = 34
    var pointSize: CGFloat = 15

    var body: some View {
        BuxToolbarGlyph(systemName: systemName, pointSize: pointSize, weight: .semibold)
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}

// MARK: - Profile toolbar

struct BuxProfileToolbarLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        if let data = settings.profileAvatarData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: BuxToolbarMetrics.profileAvatarSize, height: BuxToolbarMetrics.profileAvatarSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(themeManager.contrastAccentColor(for: colorScheme).opacity(0.35), lineWidth: 1)
                )
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
        }
    }
}

struct BuxProfileToolbarMenu<MenuContent: View>: View {
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            BuxProfileToolbarLabel()
        }
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
        .buttonStyle(.borderless)
        .accessibilityLabel("Profile")
    }
}
