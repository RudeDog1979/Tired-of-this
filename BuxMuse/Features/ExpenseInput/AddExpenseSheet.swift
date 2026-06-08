//
//  AddExpenseSheet.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Premium bottom sheet for entering expenses with predictive smart suggestions.
//

import SwiftUI
import Vision
import VisionKit

struct AddExpenseSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var appSettingsManager: AppSettingsManager
    @EnvironmentObject var brain: BuxMuseBrain

    @StateObject private var viewModel: AddExpenseViewModel
    /// Holds mood id for overlay color (kept briefly while fading out).
    @State private var moodBackdropTag: String = ""
    @State private var moodBackdropOpacity: Double = 0
    @State private var moodCrossfadeTask: Task<Void, Never>?
    @State private var actionNoticeDismissTask: Task<Void, Never>?
    @State private var showOptionalPaymentSection = false
    @State private var showOptionalIncomeStore = false
    @State private var paymentSourceQuery = ""
    @State private var showScanner = false
    @State private var isScanning = false

    @ObservedObject private var settingsStore = SettingsStore.shared

    let mode: ExpenseSheetMode

    init(brain: BuxMuseBrain, settingsManager: AppSettingsManager, mode: ExpenseSheetMode) {
        self.mode = mode
        let editing: Transaction? = {
            if case .edit(let tx) = mode { return tx }
            return nil
        }()
        let preset: TransactionCategory? = {
            switch mode {
            case .addIncome: return .income
            default: return nil
            }
        }()
        let autoScan = (mode == .addWithAutoScan)
        _viewModel = StateObject(wrappedValue: AddExpenseViewModel(
            brain: brain,
            settingsManager: settingsManager,
            editing: editing,
            presetCategory: preset,
            autoScan: autoScan
        ))
    }

    private var isIncomeMode: Bool {
        mode == .addIncome || viewModel.isIncomeEntry
    }

    private var sheetTitleKey: String {
        if viewModel.isEditing {
            return isIncomeMode ? "Edit income" : "Edit expense"
        }
        return isIncomeMode ? "Log income" : "Add expense"
    }

    private var incomeAccent: Color { .mint }

    private var locale: Locale { appSettingsManager.interfaceLocale }

    private func loc(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: locale)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                if isIncomeMode {
                    incomeBackdropWash
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if !isIncomeMode, !moodBackdropTag.isEmpty || moodBackdropOpacity > 0.01 {
                    expenseSheetMoodWash(for: moodBackdropTag)
                        .ignoresSafeArea()
                        .opacity(moodBackdropOpacity)
                        .animation(ExpenseMoodMotion.fadeIn, value: moodBackdropTag)
                        .animation(ExpenseMoodMotion.fadeIn, value: moodBackdropOpacity)
                        .allowsHitTesting(false)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxLayout.section) {
                        if isIncomeMode {
                            incomeIntroCard
                            incomeAvatarPreview
                        }

                        if !isIncomeMode, !viewModel.isEditing {
                            Button(action: {
                                if VNDocumentCameraViewController.isSupported {
                                    showScanner = true
                                } else {
                                    simulateOcrScan()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.text.viewfinder")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        BuxCatalogText.text("Scan paper receipt")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                        BuxCatalogText.text("Fills merchant, amount, date & notes automatically")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                                }
                                .padding(BuxLayout.section)
                                .expensesThemedCardChrome(cornerRadius: 18)
                            }
                            .buttonStyle(BuxMicroShrinkStyle())
                        }

                        amountCard

                        if isIncomeMode {
                            incomeSourceCard
                            incomeCategoryCard
                            incomeOptionalStoreCard
                        } else {
                            merchantCard
                            categoryCard
                        }

                        if settingsStore.sideHustleMatrixEnabled {
                            workspaceCard
                            if !viewModel.isEditing {
                                synergyBridgeCard
                            }
                        }

                        if !isIncomeMode, showOperationalPaymentCard {
                            operationalPaymentCard
                        }

                        if !isIncomeMode, !viewModel.isSubscription, settingsStore.paymentSourceTrackingEnabled {
                            optionalPaymentSourceCard
                        }

                        if !isIncomeMode, viewModel.isBarterExchange {
                            barterDetailsCard
                        }

                        if viewModel.isEditing, !isIncomeMode {
                            editActionsSection
                        }

                        if !isIncomeMode {
                            subscriptionCard
                        }

                        if !isIncomeMode, !viewModel.isEditing {
                            recurringCard
                        }

                        dateCard
                        notesCard

                        if !isIncomeMode {
                            emotionalCard
                        }

                        if !isIncomeMode, let hint = viewModel.smartHint {
                            Text(hint)
                                .font(.system(size: 13, weight: .medium))
                                .buxLabelSecondary()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(BuxLayout.section)
                                .expensesThemedCardChrome(cornerRadius: 20)
                        }

                        if !isIncomeMode, let warning = viewModel.envelopeWarning {
                            Text(warning)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(BuxLayout.section)
                                .expensesThemedCardChrome(cornerRadius: 20)
                        }

                        if let error = viewModel.saveError {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(BuxLayout.section)
                                .expensesThemedCardChrome(cornerRadius: 20)
                        }
                    }
                    .buxScreenContentMargins()
                    .padding(.top, BuxLayout.tight)
                    .padding(.bottom, 48)
                }
                .buxDetailScrollChrome()
                .scrollDismissesKeyboard(.interactively)
            }
            .buxCatalogNavigationTitle(sheetTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .buxInterfaceLocale()
            .buxThemedPresentation()
            .buxDetailNavigationChrome()
            .onAppear {
                if !isIncomeMode {
                    syncMoodBackdrop(to: viewModel.emotionTag, animated: false)
                }
                if viewModel.shouldAutoTriggerScanner {
                    viewModel.shouldAutoTriggerScanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if VNDocumentCameraViewController.isSupported {
                            showScanner = true
                        } else {
                            simulateOcrScan()
                        }
                    }
                }
            }
            .onChange(of: viewModel.emotionTag) { _, newTag in
                guard !isIncomeMode else { return }
                syncMoodBackdrop(to: newTag, animated: true)
            }
            .onChange(of: viewModel.selectedCategory) { _, _ in
                guard !isIncomeMode else { return }
                viewModel.categorySelectionDidChange()
            }
            .onChange(of: viewModel.date) { _, _ in
                guard !isIncomeMode else { return }
                viewModel.expenseDateDidChange()
            }
            .onDisappear {
                moodCrossfadeTask?.cancel()
                actionNoticeDismissTask?.cancel()
            }
            .onChange(of: viewModel.actionNotice) { _, notice in
                guard notice != nil else { return }
                actionNoticeDismissTask?.cancel()
                actionNoticeDismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    viewModel.actionNotice = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { dismiss() }
                }
                if !isIncomeMode, !viewModel.isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            if VNDocumentCameraViewController.isSupported {
                                showScanner = true
                            } else {
                                simulateOcrScan()
                            }
                        }) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: viewModel.isEditing
                            ? "Update"
                            : (isIncomeMode ? "Save income" : "Save"),
                        isEnabled: !viewModel.amountString.isEmpty
                            && !viewModel.merchantName.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        if viewModel.saveTransaction() {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showMerchantPickSheet) {
                merchantPickSheet
                    .buxThemedSheetContent()
            }
            .sheet(isPresented: $viewModel.showIncomeStorePickSheet) {
                incomeStorePickSheet
                    .buxThemedSheetContent()
            }
            .onChange(of: viewModel.optionalStoreName) { _, _ in
                guard isIncomeMode else { return }
                viewModel.refreshOptionalStoreSuggestions(resetSelection: false)
            }
            .overlay(alignment: .bottom) {
                if let notice = viewModel.actionNotice {
                    Text(notice)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(themeManager.cardFill(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 10, y: 3)
                        .padding(.horizontal, BuxLayout.marginHorizontal)
                        .padding(.bottom, 16)
                        .allowsHitTesting(false)
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView(
                    onFinish: { img in
                        showScanner = false
                        processCapturedImage(img)
                    },
                    onCancel: {
                        showScanner = false
                    },
                    onError: { err in
                        showScanner = false
                        print("OCR camera scan error: \(err)")
                        simulateOcrScan()
                    }
                )
                .presentationDragIndicator(.hidden)
            }
            .overlay {
                if isScanning {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .controlSize(.large)
                                    .tint(.white)
                                Text("Parsing receipt details...")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.easeInOut, value: isScanning)
            .tint(isIncomeMode ? incomeAccent : themeManager.contrastAccentColor(for: colorScheme))
        }
    }

    private func processCapturedImage(_ img: UIImage) {
        isScanning = true
        
        StudioReceiptEngine.parseReceipt(image: img, currencySymbol: appSettingsManager.selectedCurrency.symbol) { result in
            DispatchQueue.main.async {
                isScanning = false
                
                switch result {
                case .success(let data):
                    viewModel.prefillFromScan(
                        merchant: data.merchant,
                        amount: data.amount,
                        date: data.date,
                        details: data.details
                    )
                case .failure(let error):
                    print("OCR receipt parse failed: \(error)")
                    viewModel.saveError = loc("Failed to parse receipt. Please enter details manually.")
                }
            }
        }
    }

    private func simulateOcrScan() {
        isScanning = true
        let sym = appSettingsManager.selectedCurrency.symbol
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isScanning = false
            viewModel.prefillFromScan(
                merchant: "Apple Store Fifth Ave",
                amount: 2999.00,
                date: Date(),
                details: "• Apple MacBook Pro 16\" (\(sym)2699.00)\n• USB-C Multiport Adapter (\(sym)30.00)\n• AppleCare+ Protection Plan (\(sym)270.00)"
            )
        }
    }

    private var incomeBackdropWash: some View {
        LinearGradient(
            colors: [
                incomeAccent.opacity(colorScheme == .dark ? 0.22 : 0.14),
                incomeAccent.opacity(colorScheme == .dark ? 0.06 : 0.04),
                .clear
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    private var incomeIntroCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(incomeAccent)

            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogText.text("Money in")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
                BuxCatalogText.text("Salary, refund, gift, cash — type anything. No shop linking required.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(BuxLayout.section)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(incomeAccent.opacity(colorScheme == .dark ? 0.14 : 0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(incomeAccent.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private func deleteWithUndo() {
        guard let snapshot = viewModel.expenseSnapshotForUndo() else { return }
        do {
            try viewModel.deleteExpense()
            brain.offerExpenseUndo(snapshot)
            dismiss()
        } catch {
            viewModel.saveError = loc("Could not delete expense.")
        }
    }

    private var editActionsSection: some View {
        VStack(spacing: 12) {
            editPrimaryAction(
                viewModel.isSubscription ? loc("Remove subscription") : loc("Convert to subscription"),
                icon: viewModel.isSubscription ? "xmark.circle" : "arrow.triangle.2.circlepath"
            ) {
                viewModel.convertToSubscription()
            }
            editPrimaryAction(
                viewModel.isRecurring ? loc("Remove recurring") : loc("Mark as recurring"),
                icon: viewModel.isRecurring ? "xmark.circle" : "calendar.badge.clock"
            ) {
                viewModel.markRecurring()
            }

            BuxButton(
                title: "Delete expense",
                systemImage: "trash.fill",
                role: .destructive,
                expands: true
            ) {
                deleteWithUndo()
            }
        }
        .transaction { $0.animation = nil }
    }

    private func editPrimaryAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            .padding(16)
            .expensesThemedCardChrome(cornerRadius: 18)
        }
        .buttonStyle(BuxMicroShrinkStyle())
    }

    // MARK: - Form sections

    private var amountCard: some View {
        AmountField(
            amountString: $viewModel.amountString,
            kind: isIncomeMode ? .income : .expense
        )
        .environmentObject(themeManager)
        .environmentObject(appSettingsManager)
    }

    private var incomeAvatarPreview: some View {
        HStack(spacing: 14) {
            IncomeLedgerAvatarPreview(
                label: viewModel.merchantName,
                linkedStoreName: viewModel.optionalStoreName,
                merchantId: viewModel.selectedMerchantId,
                categoryId: viewModel.selectedCategoryId,
                categoryRaw: viewModel.selectedCategory.rawValue,
                size: 52
            )
            .environmentObject(brain)

            VStack(alignment: .leading, spacing: 4) {
                BuxCatalogText.text("List icon")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                BuxCatalogDynamicText(
                    key: viewModel.selectedMerchantId == nil
                        ? "Category icon (or store logo if linked)"
                        : "Store logo when linked"
                )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.labelPrimary(for: colorScheme))
            }
            Spacer()
        }
        .padding(BuxLayout.section)
        .background(incomeFieldChrome)
    }

    private var incomeSourceCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("What was this?")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            BuxCatalogText.text("Your own words — salary, refund, gift, sold something, etc.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(incomeAccent)
                    TextField(
                        BuxCatalogLabel.string("What was this?", locale: appSettingsManager.interfaceLocale),
                        text: $viewModel.merchantName,
                        prompt: Text(BuxCatalogLabel.string("e.g. Salary, Amazon refund, gift", locale: appSettingsManager.interfaceLocale))
                    )
                        .autocapitalization(.sentences)
                        .disableAutocorrection(true)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(IncomeSourceQuickPick.allCases) { pick in
                            incomeQuickPickChip(pick)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(BuxLayout.section)
            .background(incomeFieldChrome)
        }
    }

    private var incomeOptionalStoreCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    showOptionalIncomeStore.toggle()
                }
            } label: {
                HStack {
                    BuxCatalogText.text("Link store (optional)")
                        .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                    Spacer()
                    if viewModel.selectedMerchantId != nil {
                        BuxCatalogText.text("Linked")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(incomeAccent)
                    }
                    Image(systemName: showOptionalIncomeStore ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
            }
            .buttonStyle(.plain)

            BuxCatalogText.text("Only if you want a shop logo — e.g. Amazon for a refund. Otherwise the category icon shows in your list.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            if showOptionalIncomeStore {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "storefront.fill")
                            .foregroundStyle(incomeAccent)
                        TextField(
                            BuxCatalogLabel.string("Link store (optional)", locale: appSettingsManager.interfaceLocale),
                            text: $viewModel.optionalStoreName,
                            prompt: Text(BuxCatalogLabel.string("Search store (Amazon, employer portal…)", locale: appSettingsManager.interfaceLocale))
                        )
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }

                    if !viewModel.incomeStoreCandidates.isEmpty {
                        MerchantAutocompleteView(candidates: viewModel.incomeStoreCandidates) { candidate in
                            viewModel.selectOptionalStoreCandidate(candidate)
                        }
                        .environmentObject(themeManager)
                    }

                    if viewModel.selectedMerchantId != nil {
                        Button {
                            viewModel.clearOptionalStoreLink()
                        } label: {
                            BuxCatalogDynamicText(key: "Clear store link")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(BuxLayout.section)
        .background(incomeFieldChrome)
    }

    private func incomeQuickPickChip(_ pick: IncomeSourceQuickPick) -> some View {
        let isSelected = IncomeSourceQuickPick.matchingStoredLabel(
            viewModel.merchantName,
            locale: appSettingsManager.interfaceLocale
        ) == pick
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                viewModel.merchantName = pick.catalogKey
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: pick.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(pick.localizedLabel(locale: appSettingsManager.interfaceLocale))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : incomeAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? incomeAccent : incomeAccent.opacity(0.12))
            }
        }
        .buttonStyle(.plain)
    }

    private var incomeCategoryCard: some View {
        ExpenseCategoryPickerView(
            selectedCategoryId: $viewModel.selectedCategoryId,
            selectedCategory: $viewModel.selectedCategory,
            includesIncome: true,
            incomeOnly: true
        )
        .environmentObject(brain)
    }

    private var incomeFieldChrome: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(themeManager.cardFill(for: colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(incomeAccent.opacity(0.22), lineWidth: 1)
            }
    }

    private var merchantCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Merchant")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            VStack(alignment: .leading, spacing: BuxLayout.tight) {
                if viewModel.isMerchantFieldExpanded {
                    merchantEditorContent
                } else {
                    merchantCollapsedRow
                }
            }
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var merchantCollapsedRow: some View {
        Button {
            viewModel.expandMerchantFieldForEditing()
        } label: {
            HStack(spacing: 10) {
                if !viewModel.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AsyncMerchantLogoView(merchantName: viewModel.merchantName, size: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.merchantName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .lineLimit(1)
                    BuxCatalogText.text("Tap to change merchant")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.labelSecondary(for: colorScheme))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var merchantEditorContent: some View {
        HStack(spacing: 10) {
            if !viewModel.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AsyncMerchantLogoView(merchantName: viewModel.merchantName, size: 28)
            }
            TextField(loc("Merchant name"), text: $viewModel.merchantName)
                .autocapitalization(.words)
                .disableAutocorrection(true)
        }

        if let hint = viewModel.mergeHintCandidate,
           viewModel.selectedCandidateId == nil,
           viewModel.candidates.filter({ $0.matchKind != .newMerchant && $0.matchKind != .aliasVariant }).count <= 1 {
            Button(action: { viewModel.applyMergeHint() }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text(
                        BuxLocalizedString.format(
                            "Use %@?",
                            locale: appSettingsManager.interfaceLocale,
                            hint.displayName
                        )
                    )
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
            }
            .buttonStyle(.plain)
        }

        if viewModel.needsDisambiguatorLabel {
            TextField(loc("Label (e.g. Food, Clothes)"), text: $viewModel.merchantDisambiguator)
                .font(.system(size: 14, weight: .medium))
        }

        if viewModel.isMerchantFieldExpanded, !viewModel.candidates.isEmpty {
            MerchantAutocompleteView(candidates: viewModel.candidates) { candidate in
                viewModel.selectCandidate(candidate)
            }
            .environmentObject(themeManager)
            .transition(.buxScaleReveal)
        }
    }

    private var recurringCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Recurring")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            Toggle(isOn: $viewModel.isRecurring) {
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogText.text("Repeats regularly")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    BuxCatalogText.text("Rent, utilities, subscriptions you pay outside the subscription toggle.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(themeManager.contrastAccentColor(for: colorScheme))
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var categoryCard: some View {
        ExpenseCategoryPickerView(
            selectedCategoryId: $viewModel.selectedCategoryId,
            selectedCategory: $viewModel.selectedCategory,
            emphasizeOnAppear: mode == .addWithCategoryFocus,
            includesIncome: false
        )
        .environmentObject(brain)
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Subscription")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            ExpenseSubscriptionFieldsView(
                isSubscription: $viewModel.isSubscription,
                isTrial: $viewModel.isTrial,
                subscriptionStartDate: $viewModel.subscriptionStartDate,
                trialEndDate: $viewModel.trialEndDate,
                renewalReminderDays: $viewModel.renewalReminderDays,
                categoryImpliesSubscription: viewModel.isSubscriptionsCategorySelected
            )
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Date")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                .labelsHidden()
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var showOperationalPaymentCard: Bool {
        settingsStore.studioEnabled
            && (settingsStore.dualCashDrawerEnabled || settingsStore.barterLoggerEnabled)
    }

    private var workspaceCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Workspace")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))

                Picker(loc("Workspace"), selection: workspaceSelection) {
                    BuxCatalogText.text("No specific workspace").tag(Optional<UUID>.none)
                    ForEach(HustleManager.shared.hustles.filter { $0.isActive }) { hustle in
                        Text(hustle.name).tag(Optional(hustle.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(themeManager.labelPrimary(for: colorScheme))

                Spacer()
            }
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)

            if let preview = viewModel.workspaceAutoRoutePreviewName {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    Text(
                        BuxLocalizedString.format(
                            "Will auto-route to %@ on save",
                            locale: appSettingsManager.interfaceLocale,
                            preview
                        )
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var synergyBridgeCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Nexus bridge")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                Picker(loc("Nexus bridge"), selection: $viewModel.bridgeEntryMode) {
                    BuxCatalogText.text("Standard entry").tag(SynergyBridgeEntryMode.standard)
                    if !isIncomeMode {
                        BuxCatalogText.text("Split across workspaces").tag(SynergyBridgeEntryMode.split)
                    }
                    BuxCatalogText.text("Owner transfer").tag(SynergyBridgeEntryMode.dividendTransfer)
                }
                .pickerStyle(.segmented)

                if viewModel.bridgeEntryMode == .split {
                    Picker(loc("Secondary workspace"), selection: bridgeSecondarySelection) {
                        BuxCatalogText.text("Choose workspace").tag(Optional<UUID>.none)
                        ForEach(HustleManager.shared.hustles.filter { $0.isActive }) { hustle in
                            Text(hustle.name).tag(Optional(hustle.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.labelPrimary(for: colorScheme))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(
                            BuxLocalizedString.format(
                                "Secondary share: %lld%%",
                                locale: appSettingsManager.interfaceLocale,
                                Int(viewModel.bridgeSplitSharePercent.rounded())
                            )
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))
                        Slider(value: $viewModel.bridgeSplitSharePercent, in: 1...99, step: 1)
                            .tint(themeManager.contrastAccentColor(for: colorScheme))
                    }
                }

                if viewModel.bridgeEntryMode == .dividendTransfer {
                    BuxCatalogText.text("Source workspace uses the picker above.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(themeManager.labelSecondary(for: colorScheme))

                    Picker(loc("Target workspace"), selection: bridgeSecondarySelection) {
                        BuxCatalogText.text("Choose workspace").tag(Optional<UUID>.none)
                        ForEach(HustleManager.shared.hustles.filter { $0.isActive }) { hustle in
                            Text(hustle.name).tag(Optional(hustle.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.labelPrimary(for: colorScheme))
                }
            }
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var bridgeSecondarySelection: Binding<UUID?> {
        Binding(
            get: { viewModel.bridgeSecondaryHustleId },
            set: { viewModel.bridgeSecondaryHustleId = $0 }
        )
    }

    private var workspaceSelection: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedHustleId },
            set: { viewModel.selectedHustleId = $0 }
        )
    }

    private var operationalPaymentCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("Cash & barter")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            HStack {
                Image(systemName: viewModel.isBarterExchange ? "arrow.left.arrow.right" : "banknote.fill")
                    .foregroundColor(viewModel.isBarterExchange ? .orange : themeManager.contrastAccentColor(for: colorScheme))

                Picker(loc("Cash & barter"), selection: operationalPaymentSelection) {
                    BuxCatalogText.text("Not cash or barter").tag("")
                    if settingsStore.dualCashDrawerEnabled {
                        Text(
                            BuxLocalizedString.format(
                                "Cash (%@)",
                                locale: appSettingsManager.interfaceLocale,
                                settingsStore.primaryLocalCurrency
                            )
                        )
                        .tag("Cash (\(settingsStore.primaryLocalCurrency))")
                        Text(
                            BuxLocalizedString.format(
                                "Cash (%@)",
                                locale: appSettingsManager.interfaceLocale,
                                settingsStore.secondaryTradingCurrency
                            )
                        )
                        .tag("Cash (\(settingsStore.secondaryTradingCurrency))")
                    }
                    if settingsStore.barterLoggerEnabled {
                        BuxCatalogText.text("Barter / exchange").tag("Barter")
                    }
                }
                .pickerStyle(.menu)
                .tint(themeManager.labelPrimary(for: colorScheme))
                .onChange(of: viewModel.paymentMethod) { _, newValue in
                    viewModel.isBarterExchange = (newValue == "Barter")
                }

                Spacer()
            }
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var operationalPaymentSelection: Binding<String> {
        Binding(
            get: {
                guard let method = viewModel.paymentMethod else { return "" }
                if method == "Barter" || method.hasPrefix("Cash (") { return method }
                return ""
            },
            set: { newValue in
                if newValue.isEmpty {
                    if viewModel.isBarterExchange {
                        viewModel.paymentMethod = nil
                        viewModel.isBarterExchange = false
                    } else if viewModel.paymentMethod?.hasPrefix("Cash (") == true || viewModel.paymentMethod == "Barter" {
                        viewModel.paymentMethod = nil
                    }
                } else {
                    viewModel.paymentMethod = newValue
                    viewModel.isBarterExchange = (newValue == "Barter")
                }
            }
        )
    }

    private var optionalPaymentSourceCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showOptionalPaymentSection.toggle()
                }
            } label: {
                HStack {
                    BuxCatalogText.text("How did you pay? (optional)")
                        .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                    Spacer()
                    if let method = viewModel.paymentMethod,
                       !method.isEmpty,
                       method != "Barter",
                       !method.hasPrefix("Cash (") {
                        Text(method)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    }
                    Image(systemName: showOptionalPaymentSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)

            if showOptionalPaymentSection {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(loc("Search Visa, PayPal, Klarna…"), text: $paymentSourceQuery)
                        .font(.system(size: 14, weight: .medium))
                        .textFieldStyle(.roundedBorder)

                    let options = PaymentSourceCatalog.search(paymentSourceQuery).prefix(8)
                    ForEach(Array(options)) { option in
                        Button {
                            viewModel.paymentMethod = option.label
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: option.systemImage)
                                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                    .frame(width: 20)
                                Text(option.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                Spacer()
                                if viewModel.paymentMethod == option.label {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.paymentMethod != nil,
                       viewModel.paymentMethod != "Barter",
                       !(viewModel.paymentMethod?.hasPrefix("Cash (") ?? false) {
                        Button(loc("Clear payment source")) {
                            viewModel.paymentMethod = nil
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(BuxLayout.section)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private var barterDetailsCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .foregroundColor(.orange)
                BuxCatalogText.text("Barter details")
                    .buxSectionLabelStyle(color: .orange)
            }

            VStack(spacing: BuxLayout.tight) {
                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogText.text("Goods / services given")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    TextField(loc("What did you give? (e.g. web design)"), text: $viewModel.barterGoodsGiven, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }

                Divider().opacity(0.12)

                VStack(alignment: .leading, spacing: 4) {
                    BuxCatalogText.text("Goods / services received")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    TextField(loc("What did you receive? (e.g. boat repairs)"), text: $viewModel.barterGoodsReceived, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }

                Divider().opacity(0.12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        BuxLocalizedString.format(
                            "Estimated value (%@)",
                            locale: appSettingsManager.interfaceLocale,
                            appSettingsManager.selectedCurrency.id
                        )
                    )
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                    TextField(loc("Estimated monetary value"), text: $viewModel.barterEstimatedValue)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            TextField(loc("Notes (optional)"), text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...5)
        }
        .padding(BuxLayout.section)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private var emotionalCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            BuxCatalogText.text("How did this feel?")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            EmotionalTagPickerView(selection: $viewModel.emotionTag)
                .environmentObject(themeManager)
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var merchantPickSheet: some View {
        merchantPickSheetContent(
            candidates: viewModel.candidates,
            title: "Choose merchant",
            onSelect: { viewModel.selectCandidate($0); viewModel.showMerchantPickSheet = false },
            onCancel: { viewModel.showMerchantPickSheet = false }
        )
    }

    private var incomeStorePickSheet: some View {
        merchantPickSheetContent(
            candidates: viewModel.incomeStoreCandidates,
            title: "Choose store",
            onSelect: { viewModel.selectOptionalStoreCandidate($0) },
            onCancel: { viewModel.showIncomeStorePickSheet = false }
        )
    }

    private func merchantPickSheetContent(
        candidates: [MerchantCandidate],
        title: String,
        onSelect: @escaping (MerchantCandidate) -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            List {
                ForEach(candidates.filter { $0.matchKind != .newMerchant }) { candidate in
                    Button {
                        onSelect(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.displayName)
                                .font(.system(size: 16, weight: .semibold))
                            Text(candidate.subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .buxLabelSecondary()
                        }
                    }
                }
            }
            .buxCatalogNavigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .buxInterfaceLocale()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { onCancel() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func syncMoodBackdrop(to tag: String, animated: Bool) {
        moodCrossfadeTask?.cancel()
        moodCrossfadeTask = nil

        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            let switchingMood = moodBackdropOpacity > 0.01
                && !moodBackdropTag.isEmpty
                && moodBackdropTag != trimmed

            if animated && switchingMood {
                performMoodCrossfade(to: trimmed)
                return
            }

            moodBackdropTag = trimmed
            if animated {
                withAnimation(ExpenseMoodMotion.fadeIn) {
                    moodBackdropOpacity = 1
                }
            } else {
                moodBackdropOpacity = 1
            }
            return
        }

        guard !moodBackdropTag.isEmpty || moodBackdropOpacity > 0.01 else { return }

        if animated {
            withAnimation(ExpenseMoodMotion.fadeOut) {
                moodBackdropOpacity = 0
            }
            moodCrossfadeTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(ExpenseMoodMotion.fadeOutDuration))
                guard !Task.isCancelled else { return }
                if viewModel.emotionTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    moodBackdropTag = ""
                }
                moodCrossfadeTask = nil
            }
        } else {
            moodBackdropOpacity = 0
            moodBackdropTag = ""
        }
    }

    private func performMoodCrossfade(to newTag: String) {
        withAnimation(ExpenseMoodMotion.fadeOut) {
            moodBackdropOpacity = 0
        }

        moodCrossfadeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(ExpenseMoodMotion.crossfadeSwapDelay))
            guard !Task.isCancelled else { return }
            guard viewModel.emotionTag.trimmingCharacters(in: .whitespacesAndNewlines) == newTag else { return }

            moodBackdropTag = newTag
            withAnimation(ExpenseMoodMotion.fadeIn) {
                moodBackdropOpacity = 1
            }
            moodCrossfadeTask = nil
        }
    }

    /// Top-to-bottom mood wash — vertical fade only (no diagonal sweep).
    @ViewBuilder
    private func expenseSheetMoodWash(for tagId: String) -> some View {
        if let palette = EmotionalTagAppearance.palette(for: tagId, colorScheme: colorScheme) {
            let dark = colorScheme == .dark
            ZStack {
                LinearGradient(
                    colors: [
                        palette.gradientTop.opacity(dark ? 0.72 : 0.55),
                        palette.gradientMid.opacity(dark ? 0.38 : 0.28),
                        palette.gradientBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        palette.glow.opacity(dark ? 0.35 : 0.22),
                        palette.glow.opacity(0.08),
                        .clear
                    ],
                    center: .top,
                    startRadius: 24,
                    endRadius: 420
                )
            }
        }
    }
}

private enum ExpenseMoodMotion {
    static var fadeIn: Animation {
        BuxMotion.reducedMotion ? .easeInOut(duration: 0.28) : .easeInOut(duration: 1.05)
    }

    static var fadeOut: Animation {
        BuxMotion.reducedMotion ? .easeInOut(duration: 0.28) : .easeInOut(duration: 0.95)
    }

    static var fadeOutDuration: TimeInterval {
        BuxMotion.reducedMotion ? 0.28 : 0.95
    }

    static var crossfadeSwapDelay: TimeInterval {
        BuxMotion.reducedMotion ? 0.18 : 0.34
    }
}
