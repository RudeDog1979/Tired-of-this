//
//  BuxVaultSplashView.swift
//  BuxMuse
//
//  Vault-branded splash — entitlement check, privacy blur, and app lock share this chrome.
//

import SwiftUI

/// Shield + BuxMuse logo stack used inside vault splash surfaces.
struct BuxVaultSplashBrandStack: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var showsTitle: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .accessibilityHidden(true)

            Image("BuxMuseLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 200)
                .accessibilityLabel("BuxMuse")

            if showsTitle {
                BuxCatalogDynamicText(key: "BuxMuse Vault Active")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }
        }
    }
}

/// Full-screen vault material backdrop — title omitted for cold-open entitlement checks.
struct BuxVaultSplashView: View {
    var showsTitle: Bool = false

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThickMaterial)
                .ignoresSafeArea()

            BuxVaultSplashBrandStack(showsTitle: showsTitle)
        }
    }
}
