//
//  BuxPadSettingsChrome.swift
//  BuxMuse — iPad Settings split layout environment.
//

import SwiftUI

private struct BuxPadSettingsUsesSplitLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var buxPadSettingsUsesSplitLayout: Bool {
        get { self[BuxPadSettingsUsesSplitLayoutKey.self] }
        set { self[BuxPadSettingsUsesSplitLayoutKey.self] = newValue }
    }
}

private enum BuxPadSettingsLayout {
    static let tabBarClearance: CGFloat = 44
}

struct SettingsPadSplitScrollChromeModifier: ViewModifier {
    @Environment(\.buxPadSettingsUsesSplitLayout) private var usesPadSplitLayout

    func body(content: Content) -> some View {
        if usesPadSplitLayout {
            content
                .contentMargins(.top, BuxPadSettingsLayout.tabBarClearance, for: .scrollContent)
                .buxRootTabScrollChrome()
        } else {
            content.buxRootTabScrollChrome()
        }
    }
}
