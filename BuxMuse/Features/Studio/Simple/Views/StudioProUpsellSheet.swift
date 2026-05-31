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
    @ObservedObject private var settingsStore = SettingsStore.shared

    let feature: Feature

    enum Feature: String, Identifiable {
        case pdfInvoices
        case fullTax
        case businessCardPro

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pdfInvoices: return "PDF invoices"
            case .fullTax: return "Full Tax Studio"
            case .businessCardPro: return "Pro business card"
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
            }
        }

        var icon: String {
            switch self {
            case .pdfInvoices: return "doc.richtext.fill"
            case .fullTax: return "percent"
            case .businessCardPro: return "person.crop.rectangle.fill"
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
                    BuxButton(
                        title: "Upgrade to Pro Studio",
                        systemImage: "sparkles",
                        role: .primary,
                        expands: true
                    ) {
                        _ = SimpleStudioUpgradeCoordinator.upgradeToPro(
                            simpleStore: simpleStudioStore,
                            studioStore: studioStore,
                            settings: settingsStore,
                            currencyCode: appSettingsManager.selectedCurrency.id
                        )
                        dismiss()
                    }

                    BuxButton(
                        title: "Not now",
                        role: .secondary,
                        expands: true
                    ) {
                        dismiss()
                    }
                }
                .padding(.horizontal, BuxTokens.marginRegular)

                Spacer(minLength: 0)
            }
            .padding(.top, BuxTokens.section)
            .background(themeManager.screenBackground(for: colorScheme))
            .navigationTitle("Pro Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
            }
            .buxStudioSheetContent()
        }
    }

    private func proBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(themeManager.current.accentColor)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
        }
    }
}
