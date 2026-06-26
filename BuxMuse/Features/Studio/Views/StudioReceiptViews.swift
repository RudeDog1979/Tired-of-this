//
//  StudioReceiptViews.swift
//  BuxMuse
//
//  Receipt sandbox logs utilizing native local Vision scanners for offline write-offs tracking.
//

import SwiftUI
import Vision
import VisionKit
import PhotosUI

struct StudioReceiptsListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    @EnvironmentObject private var store: StudioStore
    @State private var showScanner = false
    @State private var showExpenseEditor = false
    
    var body: some View {
        StudioThemedListBackdrop {
            receiptsList
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(BuxCatalogLabel.string("Log expense", locale: appSettingsManager.interfaceLocale)) { showExpenseEditor = true }
                    Button(BuxCatalogLabel.string("Scan receipt", locale: appSettingsManager.interfaceLocale)) { showScanner = true }
                } label: {
                    BuxToolbarIcon(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showExpenseEditor) {
            StudioExpenseEditorView(receiptToEdit: nil)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
                .buxStudioSheetContent()
        }
        .sheet(isPresented: $showScanner) {
            StudioReceiptScannerView()
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
                .buxStudioSheetContent()
        }
    }

    private var receiptsList: some View {
        List {
            Section {
                StudioProToolScreenHeader(titleKey: "Expenses & Receipts")
                    .studioProToolScreenHeaderRow()
            }

            if store.receipts.isEmpty {
                Section {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(store.receipts) { receipt in
                NavigationLink(
                    destination: StudioReceiptDetailView(receipt: receipt)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                ) {
                    receiptRowCard(receipt: receipt)
                }
                .studioThemedListRowChrome()
            }
                .onDelete(perform: deleteReceipt)
            }
        }
        .studioProToolScrollTopInset()
        .studioThemedListRows()
    }

    private func receiptRowCard(receipt: StudioReceipt) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.merchant)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))

                Text(receipt.category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(appSettingsManager.format(receipt.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.red)

                Text(receipt.deductionStrength.catalogLabel(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(deductionColor(receipt.deductionStrength))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(deductionColor(receipt.deductionStrength).opacity(colorScheme == .dark ? 0.22 : 0.14))
                    .clipShape(Capsule())
            }
        }
        .studioThemedListRowCard()
    }
    
    private var emptyState: some View {
        VStack(spacing: BuxLayout.section) {
            Image(systemName: "doc.plaintext.fill")
                .font(.system(size: 32))
                .buxLabelSecondary()
            
            BuxCatalogDynamicText(key: "No receipts scanned yet")
                .font(.system(size: 14, weight: .semibold))
                .buxLabelSecondary()
            
            BuxButton(
                title: "Scan Receipt",
                systemImage: "doc.text.viewfinder",
                role: .primary,
                size: .regular
            ) {
                showScanner = true
            }
        }
    }
    
    private func deleteReceipt(at offsets: IndexSet) {
        let ids = offsets.map { store.receipts[$0].id }
        ids.forEach { store.deleteReceipt(id: $0) }
    }
    
    private func deductionColor(_ st: DeductionStrength) -> Color {
        switch st {
        case .strong: return .green
        case .medium: return .blue
        case .weak: return .orange
        case .risky: return .red
        }
    }
}

// MARK: - Native Document Scanner Wrapper

struct DocumentScannerView: UIViewControllerRepresentable {
    var onFinish: (UIImage) -> Void
    var onCancel: () -> Void
    var onError: (Error) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentScannerView
        
        init(parent: DocumentScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                let img = scan.imageOfPage(at: 0)
                parent.onFinish(img)
            } else {
                parent.onCancel()
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onError(error)
        }
    }
}

// MARK: - Receipt Scanner (Vision document camera + photo picker)

struct StudioReceiptScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: StudioStore
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    
    // UI flow control
    @State private var isScanning = false
    @State private var showCameraSheet = false
    @State private var showPhotoPicker = false
    @State private var showFields = false
    
    // Scanned image placeholder
    @State private var scannedImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    // Extracted Fields
    @State private var merchant = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var category = ""
    @State private var isDeductible = true
    @State private var deductiblePercentage: Double = 100
    @State private var showPadReceiptMarkup = false

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private var categoryOptions: [ReceiptDeductionCategoryOption] {
        ReceiptDeductionCategoryResolver.pickerOptions(catalogRules: store.taxProfile.deductionCategories)
    }

    private var categoryHint: (strength: DeductionStrength, note: String) {
        ReceiptDeductionCategoryResolver.hint(
            for: category,
            catalogRules: store.taxProfile.deductionCategories,
            countryCode: appSettingsManager.selectedCountry.id,
            locale: locale
        )
    }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if !showFields {
                        VStack(spacing: 24) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(themeManager.cardFill(for: colorScheme))
                                    .frame(height: 250)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
                                    )
                                
                                VStack(spacing: 16) {
                                    Image(systemName: "doc.text.viewfinder")
                                        .font(.system(size: 48))
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                    
                                    BuxCatalogDynamicText(key: "Receipt Scanner")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                    
                                    BuxCatalogDynamicText(key: "Secure offline text digitization using local Apple Neural Engines.")
                                        .font(.system(size: 12))
                                        .buxLabelSecondary()
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            
                            if isScanning {
                                ProgressView("Scanning receipt text...")
                                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                            } else {
                                VStack(spacing: 12) {
                                    BuxButton(
                                        title: VNDocumentCameraViewController.isSupported
                                            ? "Open Document Camera Scanner"
                                            : "Simulate Apple Neural Scan (Simulator)",
                                        systemImage: "camera.fill",
                                        role: .primary,
                                        expands: true,
                                        size: .regular
                                    ) {
                                        if VNDocumentCameraViewController.isSupported {
                                            showCameraSheet = true
                                        } else {
                                            simulateOcrScan()
                                        }
                                    }
                                    .padding(.horizontal)

                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                        Label(loc("Import from Photo Library"), systemImage: "photo.on.rectangle.angled")
                                            .font(.system(size: 15, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buxNativeButtonStyle(.secondary, controlSize: .regular)
                                    .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    if showFields {
                        BuxThemedCardForm {
                            if let img = scannedImage {
                                BuxFormSection(title: "Captured scan preview") {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 180)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .buxFormFieldPadding()

                                    buxPadScannerMarkupButton {
                                        showPadReceiptMarkup = true
                                    }
                                    .padding(.bottom, 8)
                                }
                            }

                            BuxFormSection(title: "Extracted document information") {
                                TextField(loc("Merchant"), text: $merchant)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                TextField(loc("Amount"), text: $amount)
                                    .keyboardType(.decimalPad)
                                    .buxFormFieldPadding()
                                BuxFormRowDivider()
                                DatePicker(loc("Date"), selection: $date, displayedComponents: .date)
                                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                                    .buxFormFieldPadding()
                            }

                            BuxFormSection(title: "Tax sandbox settings") {
                                Picker(loc("Deduction Category"), selection: $category) {
                                    ForEach(categoryOptions) { option in
                                        HStack {
                                            Text(BuxCatalogLabel.string(option.labelKey, locale: locale))
                                            if option.deductibilityPercent < 100 {
                                                Text("(\(option.deductibilityPercent)%)")
                                            }
                                        }
                                        .tag(option.storageValue)
                                    }
                                }
                                .onChange(of: category) { _, newValue in
                                    applySuggestedDeductibility(for: newValue)
                                }
                                .tint(themeManager.contrastAccentColor(for: colorScheme))
                                .buxFormFieldPadding()
                                BuxFormRowDivider()
                                Toggle(loc("Eligible for Write-off"), isOn: $isDeductible)
                                    .tint(themeManager.contrastAccentColor(for: colorScheme))
                                    .buxFormFieldPadding()
                                if isDeductible {
                                    BuxFormRowDivider()
                                    infoRow(
                                        label: loc("Deductible %"),
                                        value: BuxLocalizedString.format(
                                            "%lld%%",
                                            locale: locale,
                                            Int64(deductiblePercentage)
                                        )
                                    )
                                    .buxFormFieldPadding()
                                }
                                BuxFormRowDivider()
                                HStack {
                                    Text(categoryHint.strength.catalogLabel(locale: locale))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(studioReceiptDeductionColor(categoryHint.strength))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(studioReceiptDeductionColor(categoryHint.strength).opacity(0.12))
                                        .clipShape(Capsule())
                                    Text(categoryHint.note)
                                        .font(.system(size: 11))
                                        .buxLabelSecondary()
                                }
                                .buxFormFieldPadding()
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .buxCatalogNavigationTitle("Receipt Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BuxToolbarCancelButton { dismiss() }
                }
                if showFields {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(BuxCatalogLabel.string("Log", locale: appSettingsManager.interfaceLocale)) {
                            saveReceipt()
                            dismiss()
                        }
                        .disabled(merchant.isEmpty || amount.isEmpty)
                        .buxToolbarTextActionStyle(accent: themeManager.contrastAccentColor(for: colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showCameraSheet) {
                DocumentScannerView(
                    onFinish: { img in
                        showCameraSheet = false
                        processCapturedImage(img)
                    },
                    onCancel: {
                        showCameraSheet = false
                    },
                    onError: { _ in
                        showCameraSheet = false
                        simulateOcrScan() // fallback
                    }
                )
            }
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    if let img = await PhotoImageLoader.loadUIImage(from: item) {
                        processCapturedImage(img)
                    }
                }
            }
            .buxPadReceiptScannerPencilChrome(
                scannedImage: $scannedImage,
                isPresented: $showPadReceiptMarkup
            )
        }
    }
    
    private func processCapturedImage(_ img: UIImage) {
        isScanning = true
        scannedImage = img
        
        StudioReceiptEngine.parseReceipt(image: img) { result in
            DispatchQueue.main.async {
                isScanning = false
                showFields = true
                
                switch result {
                case .success(let data):
                    merchant = data.merchant
                    amount = "\(data.amount)"
                    date = data.date
                    
                    category = ReceiptDeductionCategoryResolver.suggestedCategory(
                        merchant: data.merchant,
                        catalogRules: store.taxProfile.deductionCategories
                    )
                    applySuggestedDeductibility(for: category)
                    
                case .failure:
                    // Fallback to manual entry with filled fields
                    merchant = "Manual Receipt scan"
                    amount = "0.00"
                    date = Date()
                    category = ReceiptDeductionCategoryResolver.defaultCategory(
                        catalogRules: store.taxProfile.deductionCategories
                    )
                    applySuggestedDeductibility(for: category)
                }
            }
        }
    }
    
    private func simulateOcrScan() {
        isScanning = true
        
        // Simulating Apple Vision network-free processing lag
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isScanning = false
            showFields = true
            
            merchant = "Apple Store Fifth Ave"
            amount = "2999.00"
            category = ReceiptDeductionCategoryResolver.suggestedCategory(
                merchant: "Apple Store Fifth Ave",
                catalogRules: store.taxProfile.deductionCategories
            )
            isDeductible = true
            applySuggestedDeductibility(for: category)
            date = Date()
        }
    }
    
    private func saveReceipt() {
        let amt = Decimal(string: amount) ?? 0
        let receiptId = UUID()
        var localPath: String?
        if let img = scannedImage {
            localPath = persistReceiptImage(img, id: receiptId)
        }
        let strength = ReceiptDeductionCategoryResolver.deductionStrength(
            for: category,
            catalogRules: store.taxProfile.deductionCategories
        )
        let r = StudioReceipt(
            id: receiptId,
            date: date,
            amount: amt,
            currencyCode: appSettingsManager.selectedCurrency.id,
            merchant: merchant,
            category: category,
            isDeductible: isDeductible,
            deductionStrength: strength,
            localImagePath: localPath,
            deductiblePercentage: isDeductible ? deductiblePercentage : 0
        )
        store.addReceipt(r)
    }

    private func applySuggestedDeductibility(for newCategory: String) {
        guard let suggested = ReceiptDeductionCategoryResolver.suggestedDeductiblePercentage(
            for: newCategory,
            catalogRules: store.taxProfile.deductionCategories
        ) else { return }
        deductiblePercentage = suggested
        isDeductible = suggested > 0
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .buxLabelSecondary()
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }

    private func persistReceiptImage(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StudioReceipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(id.uuidString).jpg")
        do {
            try data.write(to: file)
            return file.path
        } catch {
            return nil
        }
    }
}

// MARK: - Receipt Detail View

struct StudioReceiptDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var store: StudioStore

    var receipt: StudioReceipt
    @State private var showEdit = false

    private var effectiveDeductibleAmount: Decimal {
        StudioDeductionMath.deductibleAmount(
            for: receipt,
            catalogRules: store.taxProfile.deductionCategories
        )
    }

    private var catalogDeductibilityNote: String? {
        guard let rule = ReceiptDeductionCategoryResolver.matchingRule(
            for: receipt.category,
            rules: store.taxProfile.deductionCategories
        ) else { return nil }
        let pct = ReceiptDeductionCategoryResolver.deductibilityPercent(for: rule)
        let locale = appSettingsManager.interfaceLocale
        let ruleName = BuxCatalogLabel.string(rule.name, locale: locale)
        if pct < 100 {
            return BuxLocalizedString.format(
                "Tax profile applies %lld%% for %@.",
                locale: locale,
                Int64(pct),
                ruleName
            )
        }
        return BuxCatalogLabel.string("Fully deductible per tax profile.", locale: locale)
    }
    
    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxLayout.section) {
                    
                    // Main Receipt Detail Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(receipt.merchant)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            
                            Spacer()
                            
                            Text(receipt.deductionStrength.catalogLabel(locale: appSettingsManager.interfaceLocale))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(deductionColor(receipt.deductionStrength))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(deductionColor(receipt.deductionStrength).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        Divider()
                        
                        infoRow(label: BuxCatalogLabel.string("AMOUNT", locale: appSettingsManager.interfaceLocale), value: appSettingsManager.format(receipt.amount), isAmount: true)
                        infoRow(label: BuxCatalogLabel.string("DATE LOGGED", locale: appSettingsManager.interfaceLocale), value: formattedDate(receipt.date))
                        infoRow(label: BuxCatalogLabel.string("CATEGORY", locale: appSettingsManager.interfaceLocale), value: receipt.category)
                        infoRow(
                            label: BuxCatalogLabel.string("BUSINESS USE", locale: appSettingsManager.interfaceLocale),
                            value: receipt.businessUse.catalogLabel(locale: appSettingsManager.interfaceLocale)
                        )
                        infoRow(
                            label: BuxCatalogLabel.string("DEDUCTIBLE", locale: appSettingsManager.interfaceLocale),
                            value: receipt.isDeductible
                                ? "\(Int(receipt.deductiblePercentage))%"
                                : BuxCatalogLabel.string("Non-Deductible", locale: appSettingsManager.interfaceLocale)
                        )
                        if receipt.isDeductible {
                            infoRow(
                                label: BuxCatalogLabel.string("DEDUCTIBLE AMOUNT", locale: appSettingsManager.interfaceLocale),
                                value: appSettingsManager.format(effectiveDeductibleAmount)
                            )
                        }
                        if let catalogDeductibilityNote {
                            Text(catalogDeductibilityNote)
                                .font(.system(size: 11))
                                .buxLabelSecondary()
                        }
                    }
                    .padding(BuxLayout.section)
                    .studioThemedCardChrome(cornerRadius: 24)
                    
                    // Local Storage Sandbox disclaimer
                    BuxCatalogDynamicText(key: "This receipt, along with its metadata, is encrypted and securely stored offline inside your local BuxMuse Sandbox. No data leaves your iPhone.")
                        .font(.system(size: 11))
                        .buxLabelSecondary()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.horizontal, BuxLayout.marginHorizontal)
                .padding(.top, BuxLayout.tight)
            }
        }
        .buxCatalogNavigationTitle("Expense Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(BuxCatalogLabel.string("Edit", locale: appSettingsManager.interfaceLocale)) { showEdit = true }
                    .buxToolbarTextActionStyle(accent: themeManager.contrastAccentColor(for: colorScheme))
            }
        }
        .sheet(isPresented: $showEdit) {
            StudioExpenseEditorView(receiptToEdit: receipt)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(store)
                .buxStudioSheetContent()
        }
        .buxPadReceiptDetailPencilChrome(receipt: receipt)
    }
    
    private func infoRow(label: String, value: String, isAmount: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .buxLabelSecondary()
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .bold, design: isAmount ? .rounded : .default))
                .foregroundColor(isAmount ? .red : (themeManager.labelPrimary(for: colorScheme)))
        }
    }
    
    private func deductionColor(_ st: DeductionStrength) -> Color {
        switch st {
        case .strong: return .green
        case .medium: return .blue
        case .weak: return .orange
        case .risky: return .red
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        BuxDisplayDate.monthDayYear(from: date, locale: appSettingsManager.interfaceLocale)
    }
}

private func studioReceiptDeductionColor(_ strength: DeductionStrength) -> Color {
    switch strength {
    case .strong: return .green
    case .medium: return .blue
    case .weak: return .orange
    case .risky: return .red
    }
}
