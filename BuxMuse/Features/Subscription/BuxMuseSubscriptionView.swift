//
//  BuxMuseSubscriptionView.swift
//  BuxMuse — Standard / Pro two-tier subscription paywall.
//

import SwiftUI

struct BuxMuseSubscriptionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var purchaseManager = StudioPurchaseManager.shared
    @ObservedObject private var settingsStore = SettingsStore.shared

    /// Full-screen paywall when access is locked. When false, embed in Settings navigation.
    var isBlocking: Bool = false

    @State private var standardBillingPeriod: BuxMuseBillingPeriod = .yearly
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
        ZStack {
            BuxLandingTintBackground()
                .ignoresSafeArea()

            subscriptionScroll
        }
        .buxPushedNavigationChrome()
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

    private var subscriptionScroll: some View {
        ScrollView(showsIndicators: false) {
            subscriptionStack
                .padding(.top, BuxLayout.tight)
                .padding(.bottom, 32)
        }
        .buxScrollContentMargins()
        .scrollContentBackground(.hidden)
        .buxSettingsDrillInChrome()
        .scrollDismissesKeyboard(.interactively)
    }

    private var subscriptionStack: some View {
        VStack(alignment: .leading, spacing: BuxTokens.section) {
            headerBlock
            if purchaseManager.didLoadProducts && purchaseManager.products.isEmpty {
                productsUnavailableBanner
            }
            billingToggle
            standardCard
            if purchaseManager.hasActiveSubscription && !purchaseManager.hasProStudio {
                proUpgradeDivider
                StudioPurchaseChooser(
                    style: .subscriptionCards,
                    billingPeriod: $proBillingPeriod,
                    onPurchasePro: { _ = try await purchaseManager.purchaseProSubscription(period: proBillingPeriod) },
                    onError: { errorMessage = $0 }
                )
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
            }
            footerBlock
            BuxSubscriptionLegalLinks()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
            restoreButton
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
            if purchaseManager.baseInIntroductoryOffer {
                BuxCatalogDynamicText(key: "Your BuxMuse free trial is active")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                if let days = purchaseManager.baseIntroOfferDaysRemaining {
                    Text(BuxLocalizedString.format(
                        "%lld days remaining — cancel anytime in Settings before renewal.",
                        locale: appSettingsManager.interfaceLocale,
                        Int64(days)
                    ))
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                } else if let afterTrial = purchaseManager.subscribeAfterTrialLabel(
                    for: standardBillingPeriod.standardProductID,
                    locale: appSettingsManager.interfaceLocale
                ) {
                    Text(afterTrial)
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
            } else if settingsStore.isPremiumTrialActive {
                // Legacy local trial (pre–StoreKit intro) — duration from remaining days, not a hardcoded "7".
                BuxCatalogDynamicText(key: "Your free trial is active")
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
                Text(blockingHeaderText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            } else if purchaseManager.hasProStudio {
                BuxCatalogDynamicText(key: "Your BuxMuse Pro subscription is active.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            } else if purchaseManager.baseSubscriptionActive {
                BuxCatalogDynamicText(key: "Your BuxMuse Standard subscription is active.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            } else if purchaseManager.baseIntroOfferEligible {
                Text(BuxStoreKitIntroOfferCopy.tryStandardFreeHeader(
                    for: purchaseManager.product(for: standardBillingPeriod.standardProductID),
                    locale: appSettingsManager.interfaceLocale
                ))
                .font(.system(size: 13, weight: .medium))
                .buxLabelSecondary()
            } else {
                BuxCatalogDynamicText(key: "BuxMuse Standard includes personal finance and Simple Studio.")
                    .font(.system(size: 13, weight: .medium))
                    .buxLabelSecondary()
            }
        }
    }

    private var blockingHeaderText: String {
        let product = purchaseManager.product(for: standardBillingPeriod.standardProductID)
        if purchaseManager.baseIntroOfferEligible {
            return BuxStoreKitIntroOfferCopy.startTrialToContinueHeader(
                for: product,
                locale: appSettingsManager.interfaceLocale
            )
        }
        return BuxCatalogLabel.string("Subscribe to continue using BuxMuse.", locale: appSettingsManager.interfaceLocale)
    }

    private var standardBadge: String? {
        if purchaseManager.baseSubscriptionActive || purchaseManager.hasProStudio {
            return nil
        }
        return "Standard"
    }

    private var proUpgradeDivider: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            Divider()
                .padding(.vertical, 4)
            BuxCatalogDynamicText(key: "Upgrade to Pro")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
    }

    private var billingToggle: some View {
        BuxBillingPeriodToggle(
            billingPeriod: $standardBillingPeriod,
            caption: "BuxMuse billing"
        )
        .environmentObject(themeManager)
        .environmentObject(appSettingsManager)
    }

    private var standardCard: some View {
        pricingCard(
            title: "BuxMuse Standard",
            subtitle: standardSubtitle,
            priceID: standardBillingPeriod.standardProductID,
            badge: standardBadge,
            bullets: standardBullets,
            buttonTitle: standardButtonTitle,
            isSubscribed: purchaseManager.baseSubscriptionActive || purchaseManager.hasProStudio,
            showsSubscriptionLegalFooter: true,
            action: { Task { await purchaseStandard() } }
        )
        .id(standardBillingPeriod)
        .scaleEffect(didAnimateYearly && standardBillingPeriod == .yearly ? 1.01 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: standardBillingPeriod)
        .onChange(of: standardBillingPeriod) { _, newValue in
            if newValue == .yearly { didAnimateYearly = true }
        }
    }

    private var standardSubtitle: String {
        BuxStoreKitPriceCopy.standardSubtitle(
            product: purchaseManager.product(for: standardBillingPeriod.standardProductID),
            introEligible: purchaseManager.baseIntroOfferEligible,
            locale: appSettingsManager.interfaceLocale
        )
    }

    private var standardBullets: [String] {
        let locale = appSettingsManager.interfaceLocale
        let product = purchaseManager.product(for: standardBillingPeriod.standardProductID)
        var bullets = [
            "Budgets, expenses, goals, and insights",
            "Includes Simple Studio"
        ]
        if purchaseManager.baseIntroOfferEligible,
           let trialBullet = BuxStoreKitIntroOfferCopy.trialThenBilledBullet(for: product, locale: locale) {
            bullets.append(trialBullet)
        } else {
            bullets.append("Core access to BuxMuse")
        }
        bullets.append(
            standardBillingPeriod == .yearly
                ? "Auto-renewable subscription · renews every year"
                : "Auto-renewable subscription · renews every month"
        )
        return bullets
    }

    private var footerBlock: some View {
        BuxCatalogDynamicText(key: "No BuxMuse accounts. Your data stays on this device. Optional sync via your Apple ID.")
            .font(.system(size: 11, weight: .medium))
            .buxLabelSecondary()
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var restoreButton: some View {
        BuxRestorePurchasesButton()
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
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
        showsSubscriptionLegalFooter: Bool = false,
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

            if let price = purchaseManager.pricePerPeriodLabel(
                for: priceID,
                locale: appSettingsManager.interfaceLocale
            ) ?? purchaseManager.displayPrice(for: priceID) {
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

            if showsSubscriptionLegalFooter {
                BuxSubscriptionLegalLinks(layout: .stacked)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .padding(.top, 4)

                BuxSubscriptionAutoRenewDisclosure()
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .padding(.top, 2)
            }
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

    private var standardButtonTitle: String {
        if purchaseManager.hasProStudio || purchaseManager.baseSubscriptionActive {
            if purchaseManager.baseInIntroductoryOffer {
                return BuxCatalogLabel.string("Trial active", locale: appSettingsManager.interfaceLocale)
            }
            return BuxCatalogLabel.string("Subscribed", locale: appSettingsManager.interfaceLocale)
        }
        return BuxStoreKitPriceCopy.subscribeOrTrialCTA(
            for: purchaseManager.product(for: standardBillingPeriod.standardProductID),
            introEligible: purchaseManager.baseIntroOfferEligible,
            locale: appSettingsManager.interfaceLocale
        )
    }

    private func purchaseStandard() async {
        guard !purchaseManager.baseSubscriptionActive, !purchaseManager.hasProStudio else { return }
        do {
            _ = try await purchaseManager.purchaseStandardSubscription(period: standardBillingPeriod)
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
