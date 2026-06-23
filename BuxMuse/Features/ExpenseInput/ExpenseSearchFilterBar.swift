//
//  ExpenseSearchFilterBar.swift
//  BuxMuse
//
//  Advanced filter sheet — native Form presentation (Tasks-style).
//

import SwiftUI

struct ExpenseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    @Binding var filters: ExpenseFilterState
    let categories: [ExpenseCategoryRecord]
    let merchants: [ExpenseMerchantRecord]
    let heatZones: [String]

    @State private var merchantSearchQuery = ""

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var filteredMerchants: [ExpenseMerchantRecord] {
        let trimmed = merchantSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return merchants.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
        let normQuery = brain.merchantBrain.normalized(trimmed)
        return merchants.filter { merchant in
            merchant.name.localizedCaseInsensitiveContains(trimmed)
                || merchant.displayTitle.localizedCaseInsensitiveContains(trimmed)
                || brain.merchantBrain.normalized(merchant.name).contains(normQuery)
        }
        .sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var selectedMerchant: ExpenseMerchantRecord? {
        guard let id = filters.merchantId else { return nil }
        return merchants.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                BuxThemedCardForm {
                BuxFormSection(title: "Type") {
                    Toggle(isOn: $filters.recurringOnly) {
                        BuxCatalogText.text("Recurring only")
                    }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Toggle(isOn: $filters.subscriptionLikeOnly) {
                        BuxCatalogText.text("Subscription-like")
                    }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    BuxFormRowDivider()
                    Toggle(isOn: $filters.refundsOnly) {
                        BuxCatalogText.text("Refunds only")
                    }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                }

                if !categories.isEmpty {
                    BuxFormSection(title: "Category") {
                        Picker(
                            BuxCatalogLabel.string("Category", locale: locale),
                            selection: categorySelection
                        ) {
                            BuxCatalogText.text("Any").tag(UUID?.none)
                            ForEach(categories) { category in
                                Text(category.localizedDisplayName(locale: locale))
                                    .tag(UUID?.some(category.id))
                            }
                        }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    }
                }

                if !merchants.isEmpty {
                    merchantFilterSection
                }

                if !heatZones.isEmpty {
                    BuxFormSection(title: "Heat zone") {
                        Picker(
                            BuxCatalogLabel.string("Heat zone", locale: locale),
                            selection: heatZoneSelection
                        ) {
                            BuxCatalogText.text("Any").tag(String?.none)
                            ForEach(heatZones, id: \.self) { zone in
                                Text(BuxHeatZoneCopy.displayName(for: zone, locale: locale))
                                    .tag(String?.some(zone))
                            }
                        }
                        .tint(themeManager.contrastAccentColor(for: colorScheme))
                        .buxFormFieldPadding()
                    }
                }

                if filters.isActive {
                    BuxFormSection {
                        Button(role: .destructive) {
                            filters = ExpenseFilterState()
                            merchantSearchQuery = ""
                        } label: {
                            BuxCatalogText.text("Clear all filters")
                        }
                        .buxFormFieldPadding()
                    }
                }
            }
            }
            .buxScrollDismissesKeyboard()
            .buxCatalogNavigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedSheetContent()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarDoneButton { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(themeManager.contrastAccentColor(for: colorScheme))
        .buxInterfaceLocale()
    }

    @ViewBuilder
    private var merchantFilterSection: some View {
        BuxFormSection(title: "Merchant") {
            if let selected = selectedMerchant {
                HStack(spacing: 10) {
                    AsyncMerchantLogoView(merchantName: selected.name, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.displayTitle)
                            .font(.system(size: 15, weight: .semibold))
                        BuxCatalogText.text("Selected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button {
                        filters.merchantId = nil
                    } label: {
                        BuxCatalogText.text("Clear")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .buxFormFieldPadding()
                BuxFormRowDivider()
            }

            TextField(
                BuxCatalogLabel.string("Search merchants", locale: locale),
                text: $merchantSearchQuery
            )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .buxFormFieldPadding()

            if filters.merchantId == nil {
                BuxFormRowDivider()
                filterMerchantRow(
                    label: BuxCatalogLabel.string("Any merchant", locale: locale),
                    subtitle: nil,
                    merchantId: nil
                )
            }

            ForEach(filteredMerchants.prefix(32)) { merchant in
                BuxFormRowDivider()
                filterMerchantRow(
                    label: merchant.displayTitle,
                    subtitle: merchant.cluster,
                    merchantId: merchant.id
                )
            }

            if filteredMerchants.isEmpty, !merchantSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                BuxFormRowDivider()
                BuxCatalogText.text("No merchants match your search.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .buxFormFieldPadding()
            }
        }
    }

    private func filterMerchantRow(label: String, subtitle: String?, merchantId: UUID?) -> some View {
        let isSelected = filters.merchantId == merchantId
        return Button {
            filters.merchantId = merchantId
        } label: {
            HStack(spacing: 10) {
                if let merchantId, let merchant = merchants.first(where: { $0.id == merchantId }) {
                    AsyncMerchantLogoView(merchantName: merchant.name, size: 28)
                } else {
                    Image(systemName: "building.2")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
            }
        }
        .buttonStyle(.plain)
        .buxFormFieldPadding()
    }

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: { filters.categoryId },
            set: { filters.categoryId = $0 }
        )
    }

    private var heatZoneSelection: Binding<String?> {
        Binding(
            get: { filters.heatZoneBucket },
            set: { filters.heatZoneBucket = $0 }
        )
    }
}
