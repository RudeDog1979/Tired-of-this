//
//  FreelanceExpenseEditorView.swift
//  BuxMuse
//
//  Business expense editor — category, business use, deductible %, attachments.
//

import SwiftUI
import PhotosUI

struct FreelanceExpenseEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: FreelanceStore

    var receiptToEdit: FreelanceReceipt?

    @State private var merchant = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var category = BusinessExpenseCategory.software.rawValue
    @State private var businessUse: ExpenseBusinessUse = .business
    @State private var isDeductible = true
    @State private var deductiblePercentage: Double = 100
    @State private var notes = ""
    @State private var vatAmount = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var attachedImage: UIImage?

    private var categoryHint: (strength: DeductionStrength, note: String) {
        FreelanceDeductionMath.categoryHint(
            for: category,
            countryCode: appSettingsManager.selectedCountry.id
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                Form {
                    Section("Expense") {
                        TextField("Merchant / vendor", text: $merchant)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }

                    Section("Business classification") {
                        Picker("Category", selection: $category) {
                            ForEach(BusinessExpenseCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat.rawValue)
                            }
                        }

                        Picker("Use", selection: $businessUse) {
                            ForEach(ExpenseBusinessUse.allCases) { use in
                                Text(use.rawValue).tag(use)
                            }
                        }
                        .onChange(of: businessUse) { _, newValue in
                            switch newValue {
                            case .business:
                                deductiblePercentage = 100
                                isDeductible = true
                            case .personal:
                                deductiblePercentage = 0
                                isDeductible = false
                            case .mixed:
                                if let cat = BusinessExpenseCategory.allCases.first(where: { $0.rawValue == category }),
                                   let suggested = cat.suggestedPartialPercent {
                                    deductiblePercentage = suggested
                                } else {
                                    deductiblePercentage = 50
                                }
                                isDeductible = true
                            }
                        }

                        Toggle("Deductible", isOn: $isDeductible)
                            .disabled(businessUse == .personal)

                        if isDeductible && businessUse != .personal {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Deductible %")
                                    Spacer()
                                    Text("\(Int(deductiblePercentage))%")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                Slider(value: $deductiblePercentage, in: 0...100, step: 5)
                            }
                        }

                        HStack {
                            Text(categoryHint.strength.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(hintColor(categoryHint.strength))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(hintColor(categoryHint.strength).opacity(0.12))
                                .clipShape(Capsule())
                            Text(categoryHint.note)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }

                    Section("Tax details") {
                        TextField("Indirect tax paid (optional)", text: $vatAmount)
                            .keyboardType(.decimalPad)
                    }

                    Section("Attachment") {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(attachedImage == nil ? "Add receipt photo" : "Change photo", systemImage: "camera")
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    attachedImage = image
                                }
                            }
                        }
                    }

                    Section("Notes") {
                        TextField("Business purpose, project, etc.", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(receiptToEdit == nil ? "Log Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveReceipt()
                        dismiss()
                    }
                    .disabled(merchant.isEmpty || amount.isEmpty)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private func hydrate() {
        guard let r = receiptToEdit else { return }
        merchant = r.merchant
        amount = "\(r.amount)"
        date = r.date
        category = r.category
        businessUse = r.businessUse
        isDeductible = r.isDeductible
        deductiblePercentage = r.deductiblePercentage
        notes = r.notes
        if let vat = r.vatAmount { vatAmount = "\(vat)" }
    }

    private func saveReceipt() {
        let amt = Decimal(string: amount) ?? 0
        let vat = Decimal(string: vatAmount)
        var receipt = FreelanceReceipt(
            id: receiptToEdit?.id ?? UUID(),
            date: date,
            amount: amt,
            currencyCode: appSettingsManager.selectedCurrency.id,
            merchant: merchant,
            category: category,
            vatAmount: vat,
            isDeductible: isDeductible,
            deductionStrength: categoryHint.strength,
            localImagePath: receiptToEdit?.localImagePath,
            notes: notes,
            isBusiness: businessUse != .personal,
            deductiblePercentage: deductiblePercentage,
            businessUse: businessUse
        )

        if let image = attachedImage,
           let path = persistReceiptImage(image, id: receipt.id) {
            receipt.localImagePath = path
        }

        if store.receipts.contains(where: { $0.id == receipt.id }) {
            store.updateReceipt(receipt)
        } else {
            store.addReceipt(receipt)
        }
    }

    private func persistReceiptImage(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FreelanceHub/Receipts", isDirectory: true) else { return nil }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(id.uuidString).jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return nil
        }
    }

    private func hintColor(_ strength: DeductionStrength) -> Color {
        switch strength {
        case .strong: return .green
        case .medium: return .blue
        case .weak: return .orange
        case .risky: return .red
        }
    }
}
