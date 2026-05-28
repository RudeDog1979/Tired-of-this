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
    @EnvironmentObject private var brain: BuxMuseBrain

    @Binding var filters: ExpenseFilterState
    let categories: [ExpenseCategoryRecord]
    let merchants: [ExpenseMerchantRecord]
    let heatZones: [String]

    @State private var merchantSearchQuery = ""

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
            Form {
                Section("Type") {
                    Toggle("Recurring only", isOn: $filters.recurringOnly)
                    Toggle("Subscription-like", isOn: $filters.subscriptionLikeOnly)
                    Toggle("Refunds only", isOn: $filters.refundsOnly)
                }

                if !categories.isEmpty {
                    Section("Category") {
                        Picker("Category", selection: categorySelection) {
                            Text("Any").tag(UUID?.none)
                            ForEach(categories) { category in
                                Text(category.name).tag(UUID?.some(category.id))
                            }
                        }
                    }
                }

                if !merchants.isEmpty {
                    merchantFilterSection
                }

                if !heatZones.isEmpty {
                    Section("Heat zone") {
                        Picker("Heat zone", selection: heatZoneSelection) {
                            Text("Any").tag(String?.none)
                            ForEach(heatZones, id: \.self) { zone in
                                Text(zone.replacingOccurrences(of: "_", with: " "))
                                    .tag(String?.some(zone))
                            }
                        }
                    }
                }

                if filters.isActive {
                    Section {
                        Button("Clear all filters", role: .destructive) {
                            filters = ExpenseFilterState()
                            merchantSearchQuery = ""
                        }
                    }
                }
            }
            .buxScrollDismissesKeyboard()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(themeManager.current.accentColor)
    }

    @ViewBuilder
    private var merchantFilterSection: some View {
        Section("Merchant") {
            if let selected = selectedMerchant {
                HStack(spacing: 10) {
                    AsyncMerchantLogoView(merchantName: selected.name, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.displayTitle)
                            .font(.system(size: 15, weight: .semibold))
                        Text("Selected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button("Clear") {
                        filters.merchantId = nil
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
            }

            TextField("Search merchants", text: $merchantSearchQuery)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            if filters.merchantId == nil {
                filterMerchantRow(label: "Any merchant", subtitle: nil, merchantId: nil)
            }

            ForEach(filteredMerchants.prefix(32)) { merchant in
                filterMerchantRow(
                    label: merchant.displayTitle,
                    subtitle: merchant.cluster,
                    merchantId: merchant.id
                )
            }

            if filteredMerchants.isEmpty, !merchantSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No merchants match your search.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
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
                        .foregroundColor(themeManager.current.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
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
