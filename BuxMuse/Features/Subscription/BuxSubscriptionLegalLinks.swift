//
//  BuxSubscriptionLegalLinks.swift
//  BuxMuse — App Store required Privacy Policy + EULA links for subscriptions.
//

import SwiftUI

enum BuxLegalURL {
    static let privacyPolicy = URL(string: "https://buxmuse.com/privacy-policy/")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

struct BuxSubscriptionLegalLinks: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var layout: Layout = .horizontal

    enum Layout {
        case horizontal
        case stacked
    }

    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                HStack(spacing: 16) {
                    privacyLink
                    Text("·")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    termsLink
                }
            case .stacked:
                VStack(spacing: 8) {
                    privacyLink
                    termsLink
                }
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var privacyLink: some View {
        Link(destination: BuxLegalURL.privacyPolicy) {
            BuxCatalogDynamicText(key: "Privacy Policy")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
        }
    }

    private var termsLink: some View {
        Link(destination: BuxLegalURL.termsOfUse) {
            BuxCatalogDynamicText(key: "Terms of Use")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
        }
    }
}

struct BuxSubscriptionAutoRenewDisclosure: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var body: some View {
        BuxCatalogDynamicText(
            key: "Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
        )
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}
