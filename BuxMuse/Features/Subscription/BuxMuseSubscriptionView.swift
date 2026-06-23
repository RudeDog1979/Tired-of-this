//
//  BuxMuseSubscriptionView.swift
//  BuxMuse — Base app subscription paywall + Studio add-ons.
//

import SwiftUI

struct BuxMuseSubscriptionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var purchaseManager = StudioPurchaseManager.shared
    @ObservedObject private var settingsStore = SettingsStore.shared

    /// Full-screen paywall when trial expired. When false, embed in Settings navigation.
    var isBlocking: Bool = false

    @State private var baseBillingPeriod: BuxMuseBillingPeriod = .yearly
    @State private var proBillingPeriod: BuxMuseBillingPeriod = .monthly
    @State private var errorMessage: String?
    @State private var didAnimateYearly = false

    var body: some View {
        Group {
            if isBlocking {
                NavigationStack {
                    subscriptionContent
                }
                .interactiveDismissDisabled(true)
            } else {
                subscriptionContent
            }
        }
    }

    private var subscriptionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BuxTokens.section) {
                headerBlock
                if purchaseManager.didLoadProducts && purchaseManager.products.isEmpty {
                    productsUnavailableBanner
                }
                billingToggle
                baseAppCard
                if isBlocking && !hasStudioPurchaseAccess {
                    studioUnavailableFootnote
                    if hasStudioEntitlementWithoutBaseAccess {
                        studioEntitlementWithoutBaseNotice
                    }
                }
                if hasStudioPurchaseAccess {
                    optionalAddOnsDivider
                    StudioPurchaseChooser(
                        style: .subscriptionCards,
                        billingPeriod: $proBillingPeriod,
                        onPurchaseSimple: { try await StudioPurchaseFlow.purchaseSimple(purchaseManager: purchaseManager) },
                        onPurchasePro: { _ = try await purchaseManager.purchaseProStudio(period: proBillingPeriod) },
                        onError: { errorMessage = $0 }
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                }
                enterpriseBlock
                footerBlock
                restoreButton
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.vertical, BuxTokens.section)
        }
        .background {
            BuxLandingTintBackground()
        }
        .background(themeManager.screenBackground(for: colorScheme))
        .buxCatalogNavigationTitle(isBlocking ? "Subscribe to continue" : "Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            BuxCatalogLabel.string("Purchase failed", locale: appSettingsManager.interfaceLocale),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(BuxCatalogLabel.string("OK", locale: appSettingsManager.interfaceLocale), role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            await purchaseManager.loadProducts()
        }
    }

    private var productsUnavailableBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.orange)
                .padding(.top, 1)
            Text(
                purchaseManager.lastErrorMessage
                    ?? BuxCatalogLabel.string(
                        "App Store products could not be loaded. For Xcode testing, run from the BuxMuse scheme with the StoreKit configuration file. For TestFlight, upload a build and use a Sandbox Apple ID.",
                        locale: appSettingsManager.interfaceLocale
                    )
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BuxTokens.marginRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.cardFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if settingsStore.isPremiumTrialActive {
                BuxCatalogDynamicText(key: "Your 7-day trial is active")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                Text(BuxLocalizedString.format(
                    "%lld days remaining — subscribe anytime to keep access after the trial.",
                    locale: appSettingsManager.interfaceLocale,
                    Int64(settingsStore.premiumTrialDaysRemaining)
                ))
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
            } else if isBlocking {
                BuxCatalogDynamicText(key: "Your trial has ended. Subscribe to keep using BuxMuse.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            } else if purchaseManager.baseSubscriptionActive {
                BuxCatalogDynamicText(key: "Your BuxMuse subscription is active.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            } else {
                BuxCatalogDynamicText(key: "£1.99/month or £14.99/year for the full app. Studio is optional.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
            }
        }
    }

    private var hasStudioPurchaseAccess: Bool {
        purchaseManager.baseSubscriptionActive
            || settingsStore.isPremiumTrialActive
            || settingsStore.premiumLegacyEntitled
    }

    private var hasStudioEntitlementWithoutBaseAccess: Bool {
        purchaseManager.proSubscriptionActive
            || purchaseManager.ownsSimpleOneTimePurchase
            || settingsStore.studioLegacySimpleEntitled
            || settingsStore.studioLegacyProEntitled
    }

    private var baseAppBadge: String? {
        purchaseManager.baseSubscriptionActive ? nil : "Required"
    }

    private var optionalAddOnsDivider: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            Divider()
                .padding(.vertical, 4)
            BuxCatalogDynamicText(key: "Optional add-ons")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
    }

    private var studioUnavailableFootnote: some View {
        BuxCatalogDynamicText(key: "Studio add-ons are available after BuxMuse is active.")
            .font(.system(size: 12, weight: .medium))
            .buxLabelSecondary()
            .fixedSize(horizontal: false, vertical: true)
    }

    private var studioEntitlementWithoutBaseNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .padding(.top, 1)
            BuxCatalogDynamicText(
                key: purchaseManager.proSubscriptionActive || settingsStore.studioLegacyProEntitled
                    ? "Pro Studio is active on this Apple ID, but BuxMuse is required to open the app."
                    : "Simple Studio is active on this Apple ID, but BuxMuse is required to open the app."
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BuxTokens.marginRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.cardFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
    }

    private var billingToggle: some View {
        BuxBillingPeriodToggle(
            billingPeriod: $baseBillingPeriod,
            caption: "BuxMuse billing"
        )
        .environmentObject(themeManager)
        .environmentObject(appSettingsManager)
    }

    private var baseAppCard: some View {
        pricingCard(
            title: "BuxMuse",
            subtitle: baseAppSubtitle,
            priceID: baseBillingPeriod.baseProductID,
            badge: baseAppBadge,
            bullets: [
                "Budgets, expenses, goals, and insights",
                "Required for app access after your trial",
                "Studio add-ons are optional and sold separately"
            ],
            buttonTitle: baseAppButtonTitle,
            isSubscribed: purchaseManager.baseSubscriptionActive,
            action: { Task { await purchaseBaseApp() } }
        )
        .id(baseBillingPeriod)
        .scaleEffect(didAnimateYearly && baseBillingPeriod == .yearly ? 1.01 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: baseBillingPeriod)
        .onChange(of: baseBillingPeriod) { _, newValue in
            if newValue == .yearly { didAnimateYearly = true }
        }
    }

    private var baseAppSubtitle: String {
        if let price = purchaseManager.displayPrice(for: baseBillingPeriod.baseProductID) {
            return baseBillingPeriod == .yearly
                ? BuxLocalizedString.format("Full app · %@/year", locale: appSettingsManager.interfaceLocale, price)
                : BuxLocalizedString.format("Full app · %@/month", locale: appSettingsManager.interfaceLocale, price)
        }
        return baseBillingPeriod == .yearly
            ? BuxCatalogLabel.string("Full app · £14.99/year", locale: appSettingsManager.interfaceLocale)
            : BuxCatalogLabel.string("Full app · £1.99/month", locale: appSettingsManager.interfaceLocale)
    }

    private var enterpriseBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            BuxCatalogDynamicText(key: "Teams & enterprise")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            BuxCatalogDynamicText(key: "Volume licensing, onboarding, and custom invoicing — contact us.")
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
            Link(destination: URL(string: "mailto:hello@buxmuse.app?subject=BuxMuse%20Enterprise")!) {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                    BuxCatalogDynamicText(key: "Contact sales")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
        }
        .padding(BuxTokens.marginRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.cardFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
    }

    private var footerBlock: some View {
        BuxCatalogDynamicText(key: "No BuxMuse accounts. Your data stays on this device. Optional sync via your Apple ID.")
            .font(.system(size: 11, weight: .medium))
            .buxLabelSecondary()
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var restoreButton: some View {
        Button {
            Task { await purchaseManager.restorePurchases() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                BuxCatalogDynamicText(key: "Restore purchases")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
            .frame(maxWidth: .infinity)
        }
        .disabled(purchaseManager.isRestoring)
    }

    private func pricingCard(
        title: String,
        subtitle: String,
        priceID: BuxMuseProductID,
        badge: String?,
        bullets: [String],
        buttonTitle: String,
        isSecondary: Bool = false,
        isSubscribed: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(BuxCatalogLabel.string(subtitle, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
                Spacer(minLength: 8)
                if let badge {
                    Text(BuxCatalogLabel.string(badge, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.contrastAccentColor(for: colorScheme).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let price = purchaseManager.displayPrice(for: priceID) {
                Text(price)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        Text(BuxCatalogLabel.string(bullet, locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    }
                }
            }

            BuxButton(
                title: buttonTitle,
                systemImage: isSubscribed ? "checkmark.seal.fill" : (isSecondary ? "plus.circle.fill" : "sparkles"),
                role: isSecondary ? .secondary : .primary,
                expands: true,
                isEnabled: !purchaseManager.isPurchasing
                    && !purchaseManager.isLoadingProducts
                    && !isSubscribed
                    && !(purchaseManager.didLoadProducts && purchaseManager.products.isEmpty),
                action: action
            )
            .environmentObject(themeManager)
        }
        .padding(BuxTokens.marginRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                .fill(themeManager.cardFill(for: colorScheme))
        }
        .overlay {
            RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
        }
    }

    private var baseAppButtonTitle: String {
        if purchaseManager.baseSubscriptionActive {
            return BuxCatalogLabel.string("Subscribed", locale: appSettingsManager.interfaceLocale)
        }
        if let price = purchaseManager.displayPrice(for: baseBillingPeriod.baseProductID) {
            return BuxLocalizedString.format("Subscribe — %@", locale: appSettingsManager.interfaceLocale, price)
        }
        return BuxCatalogLabel.string("Subscribe", locale: appSettingsManager.interfaceLocale)
    }

    private func purchaseBaseApp() async {
        guard !purchaseManager.baseSubscriptionActive else { return }
        do {
            _ = try await purchaseManager.purchaseBaseSubscription(period: baseBillingPeriod)
        } catch StudioPurchaseError.userCancelled {
            return
        } catch {
            errorMessage = purchaseManager.userFacingErrorMessage(
                for: error,
                locale: appSettingsManager.interfaceLocale
            )
        }
    }
}
