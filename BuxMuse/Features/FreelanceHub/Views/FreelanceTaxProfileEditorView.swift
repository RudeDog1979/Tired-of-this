//
//  FreelanceTaxProfileEditorView.swift
//  BuxMuse
//
//  On-device tax profile configuration for Freelance Hub estimates.
//

import SwiftUI

struct FreelanceTaxProfileEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var store: FreelanceStore

    @State private var paymentSchedule = "annually"
    @State private var bracketInputs: [BracketInput] = []
    @State private var deductionInputs: [DeductionInput] = []

    private struct BracketInput: Identifiable {
        let id = UUID()
        var lower: String
        var upper: String
        var ratePercent: String
    }

    private struct DeductionInput: Identifiable {
        let id = UUID()
        var categoryId: String
        var name: String
        var type: DeductibilityType
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
            Form {
                Section("Payment schedule") {
                    Picker("Schedule", selection: $paymentSchedule) {
                        Text("Annually").tag("annually")
                        Text("Quarterly").tag("quarterly")
                        Text("Monthly").tag("monthly")
                    }
                }

                Section("Income tax brackets") {
                    if bracketInputs.isEmpty {
                        Text("No brackets configured. Estimates will show zero tax until you add at least one bracket.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    ForEach($bracketInputs) { $row in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Lower bound", text: $row.lower)
                                .keyboardType(.decimalPad)
                            TextField("Upper bound (optional)", text: $row.upper)
                                .keyboardType(.decimalPad)
                            TextField("Rate % (e.g. 22)", text: $row.ratePercent)
                                .keyboardType(.decimalPad)
                        }
                    }
                    .onDelete { indexSet in
                        bracketInputs.remove(atOffsets: indexSet)
                    }

                    Button("Add bracket") {
                        bracketInputs.append(BracketInput(lower: "0", upper: "", ratePercent: "10"))
                    }
                }

                Section("Deduction categories") {
                    ForEach($deductionInputs) { $row in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Category ID", text: $row.categoryId)
                            TextField("Name", text: $row.name)
                            Picker("Deductibility", selection: $row.type) {
                                ForEach([DeductibilityType.full, .partial, .limited], id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deductionInputs.remove(atOffsets: indexSet)
                    }

                    Button("Add category") {
                        deductionInputs.append(DeductionInput(categoryId: "office", name: "Office Expenses", type: .full))
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Tax Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveProfile() }
            }
        }
        .onAppear { loadFromStore() }
    }

    private func loadFromStore() {
        paymentSchedule = store.taxProfile.paymentSchedule
        bracketInputs = store.taxProfile.incomeTaxRules.map {
            BracketInput(
                lower: "\($0.lowerBound)",
                upper: $0.upperBound.map { "\($0)" } ?? "",
                ratePercent: String(format: "%.2f", Double(truncating: ($0.rate * 100) as NSDecimalNumber))
            )
        }
        deductionInputs = store.taxProfile.deductionCategories.map {
            DeductionInput(categoryId: $0.categoryId, name: $0.name, type: $0.deductibilityType)
        }
    }

    private func saveProfile() {
        var profile = store.taxProfile
        profile.paymentSchedule = paymentSchedule
        profile.incomeTaxRules = bracketInputs.compactMap { row in
            guard let lower = Decimal(string: row.lower),
                  let ratePct = Double(row.ratePercent) else { return nil }
            let upper = row.upper.isEmpty ? nil : Decimal(string: row.upper)
            return TaxBracketRule(lowerBound: lower, upperBound: upper, rate: Decimal(ratePct / 100.0))
        }
        profile.deductionCategories = deductionInputs.map {
            DeductionCategoryRule(categoryId: $0.categoryId, name: $0.name, deductibilityType: $0.type)
        }
        profile.countryCode = store.profile.countryCode
        profile.businessType = store.profile.businessType
        profile.vatRegistered = store.profile.vatRegistered
        store.updateTaxProfile(profile)
        dismiss()
    }
}
