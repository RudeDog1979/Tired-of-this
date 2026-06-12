//
//  BuxAdaptiveEnvironment.swift
//  BuxMuse — iPad layout mode + idiom gate. Never affects iPhone rendering.
//

import SwiftUI

enum BuxLayoutMode: Equatable {
    case compact
    case regular
}

enum BuxPadIdiom {
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

private struct BuxLayoutModeKey: EnvironmentKey {
    static let defaultValue: BuxLayoutMode = .compact
}

private struct BuxContainerWidthEnvKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct BuxContainerHeightEnvKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var buxLayoutMode: BuxLayoutMode {
        get { self[BuxLayoutModeKey.self] }
        set { self[BuxLayoutModeKey.self] = newValue }
    }

    var buxContainerWidth: CGFloat {
        get { self[BuxContainerWidthEnvKey.self] }
        set { self[BuxContainerWidthEnvKey.self] = newValue }
    }

    var buxContainerHeight: CGFloat {
        get { self[BuxContainerHeightEnvKey.self] }
        set { self[BuxContainerHeightEnvKey.self] = newValue }
    }
}

extension BuxLayoutMode {
    init(horizontalSizeClass: UserInterfaceSizeClass?) {
        self = horizontalSizeClass == .regular ? .regular : .compact
    }
}

private struct BuxPadEnvironmentModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .environment(\.buxLayoutMode, BuxLayoutMode(horizontalSizeClass: horizontalSizeClass))
    }
}

extension View {
    /// Apply on iPad shell only. Sets `buxLayoutMode` from size class.
    func buxPadEnvironment() -> some View {
        modifier(BuxPadEnvironmentModifier())
    }
}
