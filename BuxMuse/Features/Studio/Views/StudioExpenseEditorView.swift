//
//  StudioExpenseEditorView.swift
//  BuxMuse
//
//  Business expense editor — category, business use, deductible %, attachments.
//

import SwiftUI
import PhotosUI

struct StudioExpenseEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    var receiptToEdit: StudioReceipt?

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
    @State private var lastSavedDraft: ExpenseEditorDraft?

    private var categoryHint: (strength: DeductionStrength, note: String) {
        StudioDeductionMath.categoryHint(
            for: category,
            countryCode: appSettingsManager.selectedCountry.id
        )
    }

    private var canSubmit: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentDraft: ExpenseEditorDraft {
        ExpenseEditorDraft(
            merchant: merchant,
            amount: amount,
            date: date,
            category: category,
            businessUse: businessUse,
            isDeductible: isDeductible,
            deductiblePercentage: deductiblePercentage,
            notes: notes,
            vatAmount: vatAmount,
            hasAttachment: attachedImage != nil
        )
    }

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    private var hasUnsavedChanges: Bool {
        if receiptToEdit == nil {
            return canSubmit
        }
        guard let lastSavedDraft else { return true }
        return lastSavedDraft != currentDraft
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                BuxThemedCardForm {
                    BuxFormSection(title: "Expense") {
                        TextField(loc("Merchant / vendor"), text: $merchant)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        TextField(loc("Amount"), text: $amount)
                            .keyboardType(.decimalPad)
                            .buxFormFieldPadding()
                        BuxFormRowDivider()
                        DatePicker(loc("Date"), selection: $date, displayedComponents: .date)
                            .tint(themeManager.current.accentColor)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Business classification") {
                        Picker(loc("Category"), selection: $category) {
                            ForEach(BusinessExpenseCategory.allCases) { cat in
                                Text(cat.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(cat.rawValue)
                            }
                        }
                        .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Picker(loc("Use"), selection: $businessUse) {
                            ForEach(ExpenseBusinessUse.allCases) { use in
                                Text(use.catalogLabel(locale: appSettingsManager.interfaceLocale)).tag(use)
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
                        .buxFormFieldPadding()
                        BuxFormRowDivider()
                        Toggle(loc("Deductible"), isOn: $isDeductible)
                            .tint(themeManager.current.accentColor)
                            .disabled(businessUse == .personal)
                            .buxFormFieldPadding()

                        if isDeductible && businessUse != .personal {
                            BuxFormRowDivider()
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    BuxCatalogDynamicText(key: "Deductible %")
                                    Spacer()
                                    Text(
                                        BuxLocalizedString.format(
                                            "%lld%%",
                                            locale: appSettingsManager.interfaceLocale,
                                            Int64(deductiblePercentage)
                                        )
                                    )
                                        .font(.system(size: 13, weight: .bold))
                                }
                                Slider(value: $deductiblePercentage, in: 0...100, step: 5)
                                    .tint(themeManager.current.accentColor)
                            }
                            .buxFormFieldPadding()
                        }

                        BuxFormRowDivider()
                        HStack {
                            Text(categoryHint.strength.catalogLabel(locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(hintColor(categoryHint.strength))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(hintColor(categoryHint.strength).opacity(0.12))
                                .clipShape(Capsule())
                            Text(categoryHint.note)
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                        }
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Tax details") {
                        TextField(loc("Indirect tax paid (optional)"), text: $vatAmount)
                            .keyboardType(.decimalPad)
                            .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Attachment") {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(
                                attachedImage == nil ? loc("Add receipt photo") : loc("Change photo"),
                                systemImage: "camera"
                            )
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    attachedImage = image
                                }
                            }
                        }
                        .buxFormFieldPadding()
                    }

                    BuxFormSection(title: "Notes") {
                        TextField(loc("Business purpose, project, etc."), text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .buxFormFieldPadding()
                    }
                }
            }
            .buxCatalogNavigationTitle(receiptToEdit == nil ? "Log Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    BuxToolbarSaveButton(isDirty: hasUnsavedChanges) {
                        saveReceipt()
                        BuxSaveFeedback.success()
                        dismiss()
                    }
                }
            }
            .onAppear { hydrate() }
            .buxStudioSheetContent()
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
        lastSavedDraft = currentDraft
    }

    private func saveReceipt() {
        let amt = Decimal(string: amount) ?? 0
        let vat = Decimal(string: vatAmount)
        var receipt = StudioReceipt(
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
            .appendingPathComponent("Studio/Receipts", isDirectory: true) else { return nil }
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

private struct ExpenseEditorDraft: Equatable {
    var merchant: String
    var amount: String
    var date: Date
    var category: String
    var businessUse: ExpenseBusinessUse
    var isDeductible: Bool
    var deductiblePercentage: Double
    var notes: String
    var vatAmount: String
    var hasAttachment: Bool
}
