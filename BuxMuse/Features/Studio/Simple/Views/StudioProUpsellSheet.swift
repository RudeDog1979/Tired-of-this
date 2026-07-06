//
//  StudioProUpsellSheet.swift
//  BuxMuse
//
//  Lightweight upgrade prompt for Pro-only Studio features.
//

import SwiftUI

struct StudioProUpsellSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @ObservedObject private var purchaseManager = StudioPurchaseManager.shared
    @ObservedObject private var settingsStore = SettingsStore.shared

    let feature: Feature

    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var proBillingPeriod: BuxMuseBillingPeriod = .monthly

    enum Feature: String, Identifiable {
        case pdfInvoices
        case fullTax
        case businessCardPro
        case scopeCreepRadar
        case agreementScratchpad
        case hustleUnlimited

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pdfInvoices: return "PDF invoices"
            case .fullTax: return "Full Tax Studio"
            case .businessCardPro: return "Pro business card"
            case .scopeCreepRadar: return "Anti-Scope Creep Radar"
            case .agreementScratchpad: return "Agreement Scratchpad"
            case .hustleUnlimited: return "Unlimited gig workspaces"
            }
        }

        var message: String {
            switch self {
            case .pdfInvoices:
                return "Export designed PDF invoices, share with clients, and keep a Pro invoice ledger."
            case .fullTax:
                return "Open Tax Studio for deductions, mileage, cashflow, and country-aware tax estimates."
            case .businessCardPro:
                return "Design multiple cards with templates, colors, QR codes, and print-ready PDF export."
            case .scopeCreepRadar:
                return "Track budgeted hours and revision limits per Studio project. Get alerts and scope-change email templates before work goes off-rails."
            case .agreementScratchpad:
                return "Draft lightweight client agreements, import your own PDF or photo to mark up and sign, and keep sign-off records on your device."
            case .hustleUnlimited:
                return "Simple Studio supports 3 active gig workspaces. Pro unlocks unlimited side-hustle ledgers with full filtering across Home, Expenses, and Studio."
            }
        }

        var icon: String {
            switch self {
            case .pdfInvoices: return "doc.richtext.fill"
            case .fullTax: return "percent"
            case .businessCardPro: return "person.crop.rectangle.fill"
            case .scopeCreepRadar: return "scope"
            case .agreementScratchpad: return "doc.text.fill"
            case .hustleUnlimited: return "briefcase.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: BuxTokens.block) {
                StudioTierWordmark(style: .hero)
                    .padding(.horizontal, BuxTokens.marginRegular)

                BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
                    VStack(alignment: .leading, spacing: BuxTokens.section) {
                        Label(feature.title, systemImage: feature.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                        Text(feature.message)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            proBullet("PDF invoice designer & export")
                            proBullet("Tax Studio, deductions, mileage")
                            proBullet("Pro Search across your whole studio")
                            proBullet("Business Card Studio with templates")
                        }
                    }
                }
                .padding(.horizontal, BuxTokens.marginRegular)

                VStack(spacing: BuxTokens.tight) {
                    BuxBillingPeriodToggle(
                        billingPeriod: $proBillingPeriod,
                        caption: "Pro Studio billing"
                    )
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .padding(.horizontal, BuxTokens.marginRegular)

                    BuxButton(
                        title: proPurchaseTitle,
                        systemImage: "sparkles",
                        role: .primary,
                        expands: true
                    ) {
                        Task { await purchasePro() }
                    }
                    .disabled(isPurchasing || purchaseManager.isPurchasing)

                    BuxButton(
                        title: "Not now",
                        role: .secondary,
                        expands: true
                    ) {
                        dismiss()
                    }

                    VStack(spacing: 12) {
                        BuxSubscriptionLegalLinks(layout: .horizontal)
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                        
                        BuxSubscriptionAutoRenewDisclosure()
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                    }
                    .padding(.top, BuxTokens.tight)
                }
                .padding(.horizontal, BuxTokens.marginRegular)

                Spacer(minLength: 0)
            }
            .padding(.top, BuxTokens.section)
            .background(themeManager.screenBackground(for: colorScheme))
            .buxCatalogNavigationTitle("Pro Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxStudioSheetContent()
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
        }
    }

    private var proPurchaseTitle: String {
        if let price = purchaseManager.displayPrice(for: proBillingPeriod.studioProProductID) {
            return BuxLocalizedString.format("Upgrade to Pro Studio — %@", locale: appSettingsManager.interfaceLocale, price)
        }
        return BuxCatalogLabel.string("Upgrade to Pro Studio", locale: appSettingsManager.interfaceLocale)
    }

    private func purchasePro() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await StudioPurchaseFlow.purchasePro(
                simpleStore: simpleStudioStore,
                studioStore: studioStore,
                settings: settingsStore,
                appSettingsManager: appSettingsManager,
                navigationCoordinator: nil,
                purchaseManager: purchaseManager,
                period: proBillingPeriod
            )
            dismiss()
        } catch StudioPurchaseError.userCancelled {
            return
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func proBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
    }
}
