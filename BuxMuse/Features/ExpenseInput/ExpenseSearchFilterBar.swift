//
//  ExpenseSearchFilterBar.swift
//  BuxMuse
//
//  Advanced filter sheet — native Form presentation (Tasks-style).
//

import SwiftUI

struct ExpenseFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var filters: ExpenseFilterState
    let categories: [ExpenseCategoryRecord]
    let merchants: [ExpenseMerchantRecord]
    let heatZones: [String]

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
                    Section("Merchant") {
                        Picker("Merchant", selection: merchantSelection) {
                            Text("Any").tag(UUID?.none)
                            ForEach(merchants.prefix(24)) { merchant in
                                Text(merchant.name).tag(UUID?.some(merchant.id))
                            }
                        }
                    }
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
                        }
                    }
                }
            }
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

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: { filters.categoryId },
            set: { filters.categoryId = $0 }
        )
    }

    private var merchantSelection: Binding<UUID?> {
        Binding(
            get: { filters.merchantId },
            set: { filters.merchantId = $0 }
        )
    }

    private var heatZoneSelection: Binding<String?> {
        Binding(
            get: { filters.heatZoneBucket },
            set: { filters.heatZoneBucket = $0 }
        )
    }
}
