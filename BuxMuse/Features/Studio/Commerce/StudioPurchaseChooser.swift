//
//  StudioPurchaseChooser.swift
//  BuxMuse — Simple Studio or Pro Studio (one path at a time + cross-upsell).
//

import SwiftUI

/// Shared copy: Studio IAPs sit on top of BuxMuse and never replace base app access.
struct StudioAddOnRequirementNotice: View {
    enum Presentation {
        case inline
        case callout
    }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    var presentation: Presentation = .inline

    var body: some View {
        let content = HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                .padding(.top, 1)

            BuxCatalogDynamicText(key: "Studio add-ons require an active BuxMuse subscription. They do not replace it.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme).opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }

        switch presentation {
        case .inline:
            content
        case .callout:
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(themeManager.contrastAccentColor(for: colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.08))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(themeManager.contrastAccentColor(for: colorScheme).opacity(0.18), lineWidth: 1)
                }
        }
    }
}

enum StudioPurchaseTier: String, CaseIterable, Identifiable {
    case simple
    case pro

    var id: String { rawValue }
}

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
    var onPurchaseSimple: () async throws -> Void
    var onPurchasePro: () async throws -> Void
    var onError: (String) -> Void = { _ in }

    @State private var selectedTier: StudioPurchaseTier = .simple

    var body: some View {
        VStack(alignment: .leading, spacing: style == .settingsList ? BuxTokens.section : BuxTokens.tight) {
            tierIntro

            if purchaseManager.hasProStudio {
                ownedStatusCard(
                    title: "Pro Studio",
                    subtitle: "Active — includes Simple Studio",
                    badge: "Active"
                )
            } else if purchaseManager.hasSimpleStudio {
                ownedStatusCard(
                    title: "Simple Studio",
                    subtitle: "Unlocked on this Apple ID",
                    badge: "Owned"
                )
                proOnlyCard
            } else {
                tierPicker
                activeTierContent
                crossUpsellLink
            }
        }
        .onAppear {
            if purchaseManager.hasSimpleStudio && !purchaseManager.hasProStudio {
                selectedTier = .pro
            }
        }
    }

    private var tierIntro: some View {
        Group {
            if style == .subscriptionCards {
                BuxSectionHeader(title: BuxCatalogLabel.string("Studio add-ons", locale: appSettingsManager.interfaceLocale))
                    .environmentObject(themeManager)
                BuxCatalogDynamicText(key: "Simple Studio for invoices and a work ledger — or Pro Studio for tax tools, PDF design, and unlimited projects.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)
                StudioAddOnRequirementNotice(presentation: .inline)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .padding(.top, 4)
            } else {
                BuxCatalogDynamicText(key: "Pick Simple for invoices and a work ledger, or Pro for tax tools and unlimited projects.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme).opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .buxFormFieldPadding()

                StudioAddOnRequirementNotice(presentation: .callout)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .buxFormFieldPadding()
            }
        }
    }

    private var tierPicker: some View {
        BuxSegmentedCapsuleSelector(leadingSelected: selectedTier == .simple) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    selectedTier = .simple
                }
            } label: {
                BuxSegmentedCapsuleSegment(
                    title: BuxCatalogLabel.string("Simple", locale: appSettingsManager.interfaceLocale),
                    isSelected: selectedTier == .simple
                )
            }
            .buttonStyle(.plain)
        } trailing: {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    selectedTier = .pro
                }
            } label: {
                BuxSegmentedCapsuleSegment(
                    title: BuxCatalogLabel.string("Pro", locale: appSettingsManager.interfaceLocale),
                    isSelected: selectedTier == .pro,
                    trailingAccessory: AnyView(ProFeatureBadge(compact: true))
                )
            }
            .buttonStyle(.plain)
        }
        .environmentObject(themeManager)
        .modifier(StudioChooserFieldPadding(style: style))
    }

    @ViewBuilder
    private var activeTierContent: some View {
        switch selectedTier {
        case .simple:
            if style == .subscriptionCards {
                simpleSubscriptionCard
            } else {
                simpleSettingsPanel
            }
        case .pro:
            VStack(alignment: .leading, spacing: BuxTokens.tight) {
                proBillingToggle
                if style == .subscriptionCards {
                    proSubscriptionCard
                } else {
                    proSettingsPanel
                }
            }
        }
    }

    @ViewBuilder
    private var proBillingToggle: some View {
        if selectedTier == .pro || style == .subscriptionCards {
            BuxBillingPeriodToggle(
                billingPeriod: $billingPeriod,
                caption: style == .settingsList ? nil : "Pro Studio billing"
            )
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
            .modifier(StudioChooserFieldPadding(style: style))
        }
    }

    private var crossUpsellLink: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selectedTier = selectedTier == .simple ? .pro : .simple
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedTier == .simple ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(selectedTier == .simple
                     ? BuxCatalogLabel.string("Need tax tools? See Pro Studio", locale: appSettingsManager.interfaceLocale)
                     : BuxCatalogLabel.string("Just need invoices? See Simple Studio", locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.leading)
            }
            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .modifier(StudioChooserFieldPadding(style: style))
    }

    // MARK: - Subscription cards

    private var simpleSubscriptionCard: some View {
        StudioPricingCard(
            title: "Simple Studio",
            subtitle: "Add-on · requires BuxMuse · one-time unlock",
            priceID: .studioSimple,
            badge: nil,
            bullets: [
                "Work ledger and basic invoices",
                "Up to 3 workspaces",
                "Mileage and payment tracking"
            ],
            buttonTitle: simpleButtonTitle,
            isSecondary: true,
            isEnabled: !purchaseManager.isPurchasing
                && !purchaseManager.isLoadingProducts
                && !(purchaseManager.didLoadProducts && purchaseManager.products.isEmpty),
            action: { Task { await runPurchase(onPurchaseSimple) } }
        )
    }

    private var proSubscriptionCard: some View {
        StudioPricingCard(
            title: "Pro Studio",
            subtitle: proCardSubtitle,
            priceID: billingPeriod.studioProProductID,
            badge: "Includes Simple",
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

    private var proOnlyCard: some View {
        Group {
            proBillingToggle
            if style == .subscriptionCards {
                proSubscriptionCard
            } else {
                proSettingsPanel
            }
            crossUpsellToProOnly
        }
    }

    private var crossUpsellToProOnly: some View {
        BuxCatalogDynamicText(key: "Pro includes everything in Simple — upgrade when you need tax tools and unlimited projects.")
            .font(.system(size: 12, weight: .medium))
            .buxLabelSecondary()
            .fixedSize(horizontal: false, vertical: true)
            .modifier(StudioChooserFieldPadding(style: style))
    }

    // MARK: - Settings panels

    private var simpleSettingsPanel: some View {
        settingsProductPanel(
            title: "Simple Studio",
            showsProBadge: false,
            priceID: .studioSimple,
            bullets: [
                "Work ledger and basic invoices",
                "Up to 3 workspaces",
                "Mileage and payment tracking"
            ],
            billingNote: "One-time unlock · requires BuxMuse",
            buttonTitle: simpleButtonTitle,
            action: { Task { await runPurchase(onPurchaseSimple) } }
        )
    }

    private var proSettingsPanel: some View {
        settingsProductPanel(
            title: "Pro Studio",
            showsProBadge: true,
            priceID: billingPeriod.studioProProductID,
            bullets: proCardBullets,
            billingNote: billingPeriod == .yearly
                ? "Yearly subscription · includes Simple"
                : "Monthly subscription · includes Simple",
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
                if let price = purchaseManager.displayPrice(for: priceID) {
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
                systemImage: "plus.circle.fill",
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
        .padding(.horizontal, style == .settingsList ? 0 : 0)
    }

    private var proCardSubtitle: String {
        if purchaseManager.ownsSimpleOneTimePurchase {
            return "Add-on · requires BuxMuse · includes Simple · request a Simple refund from Apple after upgrading"
        }
        return billingPeriod == .yearly
            ? "Add-on · requires BuxMuse · includes Simple · billed yearly"
            : "Add-on · requires BuxMuse · includes Simple · billed monthly"
    }

    private var proCardBullets: [String] {
        [
            "Everything in Simple Studio",
            "Tax Studio and PDF designer",
            "Unlimited projects and Pro work tools"
        ]
    }

    private var simpleButtonTitle: String {
        if let price = purchaseManager.displayPrice(for: .studioSimple) {
            return BuxLocalizedString.format("Unlock Simple — %@", locale: appSettingsManager.interfaceLocale, price)
        }
        return BuxCatalogLabel.string("Unlock Simple Studio", locale: appSettingsManager.interfaceLocale)
    }

    private var proButtonTitle: String {
        if let price = purchaseManager.displayPrice(for: billingPeriod.studioProProductID) {
            return BuxLocalizedString.format("Subscribe to Pro — %@", locale: appSettingsManager.interfaceLocale, price)
        }
        return BuxCatalogLabel.string("Subscribe to Pro Studio", locale: appSettingsManager.interfaceLocale)
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
                systemImage: isSecondary ? "plus.circle.fill" : "sparkles",
                role: isSecondary ? .secondary : .primary,
                expands: true,
                isEnabled: isEnabled,
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
}
