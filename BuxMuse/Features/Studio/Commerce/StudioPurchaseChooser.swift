//
//  StudioPurchaseChooser.swift
//  BuxMuse — Pro upgrade chooser (Standard already includes Simple Studio).
//

import SwiftUI

struct StudioPurchaseChooser: View {
    enum Style {
        case subscriptionCards
        case settingsList
    }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var purchaseManager = StudioPurchaseManager.shared

    let style: Style
    @Binding var billingPeriod: BuxMuseBillingPeriod
    var onPurchasePro: () async throws -> Void
    var onError: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .settingsList ? BuxTokens.section : BuxTokens.tight) {
            if purchaseManager.hasProStudio {
                ownedStatusCard(
                    title: "BuxMuse Pro",
                    subtitle: "Active — includes all Standard features",
                    badge: "Active"
                )
            } else {
                tierIntro
                proBillingToggle
                if style == .subscriptionCards {
                    proSubscriptionCard
                } else {
                    proSettingsPanel
                }
            }
        }
    }

    private var tierIntro: some View {
        Group {
            if style == .subscriptionCards {
                BuxCatalogDynamicText(key: "Upgrade for invoice designer, Business Card Studio, Tax Studio, unlimited workspaces, and every Pro tool. Includes everything in Standard.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                BuxCatalogDynamicText(key: "Upgrade to BuxMuse Pro for invoice designer, Business Card Studio, Tax Studio, unlimited workspaces, and every Pro tool.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme).opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .buxFormFieldPadding()
            }
        }
    }

    private var proBillingToggle: some View {
        BuxBillingPeriodToggle(
            billingPeriod: $billingPeriod,
            caption: style == .settingsList ? nil : "BuxMuse Pro billing"
        )
        .environmentObject(themeManager)
        .environmentObject(appSettingsManager)
        .modifier(StudioChooserFieldPadding(style: style))
    }

    private var proSubscriptionCard: some View {
        StudioPricingCard(
            title: "BuxMuse Pro",
            subtitle: proCardSubtitle,
            priceID: billingPeriod.proProductID,
            badge: "Includes Standard",
            bullets: proCardBullets,
            buttonTitle: proButtonTitle,
            isSecondary: true,
            isEnabled: !purchaseManager.isPurchasing
                && !purchaseManager.isLoadingProducts
                && !(purchaseManager.didLoadProducts && purchaseManager.products.isEmpty),
            action: { Task { await runPurchase(onPurchasePro) } }
        )
        .id(billingPeriod)
    }

    private var proSettingsPanel: some View {
        settingsProductPanel(
            title: "BuxMuse Pro",
            showsProBadge: true,
            priceID: billingPeriod.proProductID,
            bullets: proCardBullets,
            billingNote: billingPeriod == .yearly
                ? "Yearly subscription · includes Standard"
                : "Monthly subscription · includes Standard",
            buttonTitle: proButtonTitle,
            action: { Task { await runPurchase(onPurchasePro) } }
        )
        .id(billingPeriod)
    }

    private func settingsProductPanel(
        title: String,
        showsProBadge: Bool,
        priceID: BuxMuseProductID,
        bullets: [String],
        billingNote: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        if showsProBadge {
                            ProFeatureBadge(compact: true)
                        }
                    }
                    Text(BuxCatalogLabel.string(billingNote, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
                Spacer(minLength: 8)
                if let price = purchaseManager.pricePerPeriodLabel(
                    for: priceID,
                    locale: appSettingsManager.interfaceLocale
                ) ?? purchaseManager.displayPrice(for: priceID) {
                    Text(price)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.trailing)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .padding(.top, 2)
                        Text(BuxCatalogLabel.string(bullet, locale: appSettingsManager.interfaceLocale))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme).opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
            }

            BuxButton(
                title: buttonTitle,
                systemImage: "sparkles",
                role: .secondary,
                expands: true,
                isEnabled: !purchaseManager.isPurchasing
                    && !purchaseManager.isLoadingProducts
                    && !(purchaseManager.didLoadProducts && purchaseManager.products.isEmpty),
                action: action
            )
            .environmentObject(themeManager)
        }
        .padding(BuxLayout.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(themeManager.cardFill(for: colorScheme).opacity(colorScheme == .dark ? 0.55 : 0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
        }
        .modifier(StudioChooserFieldPadding(style: style))
    }

    private func ownedStatusCard(title: String, subtitle: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(BuxCatalogLabel.string(subtitle, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 12, weight: .medium))
                        .buxLabelSecondary()
                }
                Spacer()
                Text(BuxCatalogLabel.string(badge, locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.contrastAccentColor(for: colorScheme).opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(BuxTokens.marginRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.cardFill(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
    }

    private var proCardSubtitle: String {
        let locale = appSettingsManager.interfaceLocale
        return billingPeriod == .yearly
            ? BuxCatalogLabel.string("Includes all Standard features · billed yearly", locale: locale)
            : BuxCatalogLabel.string("Includes all Standard features · billed monthly", locale: locale)
    }

    private var proCardBullets: [String] {
        [
            "Includes all Standard BuxMuse features",
            "Invoice designer with brand templates",
            "Business Card Studio — templates, QR & print-ready cards",
            "Tax Studio — deductions, mileage & estimates",
            "Unlimited gig workspaces (Simple caps at 3)",
            "Anti-Scope Creep Radar & Agreement Scratchpad",
            "Pro Search across clients, jobs & invoices",
            "Project planner & Studio Insights"
        ]
    }

    private var proButtonTitle: String {
        if purchaseManager.hasProStudio {
            return BuxCatalogLabel.string("BuxMuse Pro active", locale: appSettingsManager.interfaceLocale)
        }
        return BuxStoreKitPriceCopy.upgradeToProCTA(
            for: purchaseManager.product(for: billingPeriod.proProductID),
            locale: appSettingsManager.interfaceLocale
        )
    }

    private func runPurchase(_ action: () async throws -> Void) async {
        do {
            try await action()
        } catch StudioPurchaseError.userCancelled {
            return
        } catch {
            onError(purchaseManager.userFacingErrorMessage(for: error, locale: appSettingsManager.interfaceLocale))
        }
    }
}

// MARK: - Settings field padding

private struct StudioChooserFieldPadding: ViewModifier {
    let style: StudioPurchaseChooser.Style

    func body(content: Content) -> some View {
        if style == .settingsList {
            content.buxFormFieldPadding()
        } else {
            content
        }
    }
}

// MARK: - Pricing card (subscription screen)

private struct StudioPricingCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @ObservedObject private var purchaseManager = StudioPurchaseManager.shared

    let title: String
    let subtitle: String
    let priceID: BuxMuseProductID
    let badge: String?
    let bullets: [String]
    let buttonTitle: String
    var isSecondary: Bool = true
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BuxCatalogLabel.string(title, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    Text(subtitle)
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
                systemImage: isSecondary ? "sparkles" : "sparkles",
                role: isSecondary ? .secondary : .primary,
                expands: true,
                isEnabled: isEnabled,
                action: action
            )
            .environmentObject(themeManager)

            BuxSubscriptionLegalLinks(layout: .stacked)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .padding(.top, 4)

            BuxSubscriptionAutoRenewDisclosure()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .padding(.top, 2)
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
}
