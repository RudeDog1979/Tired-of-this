//
//  AddExpenseSheet.swift
//  BuxMuse
//  Features/ExpenseInput/
//
//  Premium bottom sheet for entering expenses with predictive smart suggestions.
//

import SwiftUI

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
    @State private var paymentSourceQuery = ""

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
        _viewModel = StateObject(wrappedValue: AddExpenseViewModel(
            brain: brain,
            settingsManager: settingsManager,
            editing: editing,
            presetCategory: preset
        ))
    }

    private var sheetTitle: String {
        if viewModel.isEditing { return "Edit Expense" }
        return mode == .addIncome ? "Log Income" : "Add Expense"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                if !moodBackdropTag.isEmpty || moodBackdropOpacity > 0.01 {
                    expenseSheetMoodWash(for: moodBackdropTag)
                        .ignoresSafeArea()
                        .opacity(moodBackdropOpacity)
                        .animation(ExpenseMoodMotion.fadeIn, value: moodBackdropTag)
                        .animation(ExpenseMoodMotion.fadeIn, value: moodBackdropOpacity)
                        .allowsHitTesting(false)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: BuxLayout.section) {
                        amountCard
                        merchantCard
                        categoryCard

                        if settingsStore.sideHustleMatrixEnabled {
                            workspaceCard
                        }

                        if showOperationalPaymentCard {
                            operationalPaymentCard
                        }

                        if !viewModel.isSubscription, settingsStore.paymentSourceTrackingEnabled {
                            optionalPaymentSourceCard
                        }

                        if viewModel.isBarterExchange {
                            barterDetailsCard
                        }

                        if viewModel.isEditing {
                            editActionsSection
                        }

                        subscriptionCard
                        dateCard
                        notesCard
                        emotionalCard

                        if let hint = viewModel.smartHint {
                            Text(hint)
                                .font(.system(size: 13, weight: .medium))
                                .buxLabelSecondary()
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
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .buxThemedPresentation()
            .buxDetailNavigationChrome()
            .onAppear {
                syncMoodBackdrop(to: viewModel.emotionTag, animated: false)
            }
            .onChange(of: viewModel.emotionTag) { _, newTag in
                syncMoodBackdrop(to: newTag, animated: true)
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
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarConfirmButton(
                        accessibilityLabel: viewModel.isEditing ? "Update" : "Save",
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
        }
    }

    private func deleteWithUndo() {
        guard let snapshot = viewModel.expenseSnapshotForUndo() else { return }
        do {
            try viewModel.deleteExpense()
            brain.offerExpenseUndo(snapshot)
            dismiss()
        } catch {
            viewModel.saveError = "Could not delete expense."
        }
    }

    private var editActionsSection: some View {
        VStack(spacing: 12) {
            editPrimaryAction(
                viewModel.isSubscription ? "Remove subscription" : "Convert to subscription",
                icon: viewModel.isSubscription ? "xmark.circle" : "arrow.triangle.2.circlepath"
            ) {
                viewModel.convertToSubscription()
            }
            editPrimaryAction(
                viewModel.isRecurring ? "Remove recurring" : "Mark as recurring",
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
        AmountField(amountString: $viewModel.amountString)
            .environmentObject(themeManager)
            .environmentObject(appSettingsManager)
    }

    private var merchantCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("Merchant")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            VStack(alignment: .leading, spacing: BuxLayout.tight) {
                HStack(spacing: 10) {
                    if !viewModel.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        AsyncMerchantLogoView(merchantName: viewModel.merchantName, size: 28)
                    }
                    TextField("Merchant name", text: $viewModel.merchantName)
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
                            Text("Use \(hint.displayName)?")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(themeManager.current.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.needsDisambiguatorLabel {
                    TextField("Label (e.g. Food, Clothes)", text: $viewModel.merchantDisambiguator)
                        .font(.system(size: 14, weight: .medium))
                }

                if !viewModel.candidates.isEmpty {
                    MerchantAutocompleteView(candidates: viewModel.candidates) { candidate in
                        viewModel.selectCandidate(candidate)
                    }
                    .environmentObject(themeManager)
                    .transition(.buxScaleReveal)
                }
            }
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var categoryCard: some View {
        ExpenseCategoryPickerView(
            selectedCategoryId: $viewModel.selectedCategoryId,
            selectedCategory: $viewModel.selectedCategory,
            emphasizeOnAppear: mode == .addWithCategoryFocus,
            includesIncome: mode == .addIncome
        )
        .environmentObject(brain)
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("Subscription")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            ExpenseSubscriptionFieldsView(
                isSubscription: $viewModel.isSubscription,
                isTrial: $viewModel.isTrial,
                subscriptionStartDate: $viewModel.subscriptionStartDate,
                trialEndDate: $viewModel.trialEndDate,
                renewalReminderDays: $viewModel.renewalReminderDays
            )
            .padding(BuxLayout.section)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("Date")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            DatePicker("", selection: $viewModel.date, displayedComponents: .date)
                .labelsHidden()
                .tint(themeManager.current.accentColor)
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
            Text("Workspace")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            HStack {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(themeManager.current.accentColor)

                Picker("Workspace", selection: workspaceSelection) {
                    Text("No specific workspace").tag(Optional<UUID>.none)
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
        }
    }

    private var workspaceSelection: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedHustleId },
            set: { viewModel.selectedHustleId = $0 }
        )
    }

    private var operationalPaymentCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("Cash & Barter")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            HStack {
                Image(systemName: viewModel.isBarterExchange ? "arrow.left.arrow.right" : "banknote.fill")
                    .foregroundColor(viewModel.isBarterExchange ? .orange : themeManager.current.accentColor)

                Picker("Cash & Barter", selection: operationalPaymentSelection) {
                    Text("Not cash or barter").tag("")
                    if settingsStore.dualCashDrawerEnabled {
                        Text("Cash (\(settingsStore.primaryLocalCurrency))").tag("Cash (\(settingsStore.primaryLocalCurrency))")
                        Text("Cash (\(settingsStore.secondaryTradingCurrency))").tag("Cash (\(settingsStore.secondaryTradingCurrency))")
                    }
                    if settingsStore.barterLoggerEnabled {
                        Text("Barter / Exchange").tag("Barter")
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
                    Text("How did you pay? (optional)")
                        .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))
                    Spacer()
                    if let method = viewModel.paymentMethod,
                       !method.isEmpty,
                       method != "Barter",
                       !method.hasPrefix("Cash (") {
                        Text(method)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.current.accentColor)
                    }
                    Image(systemName: showOptionalPaymentSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)

            if showOptionalPaymentSection {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Search Visa, PayPal, Klarna…", text: $paymentSourceQuery)
                        .font(.system(size: 14, weight: .medium))
                        .textFieldStyle(.roundedBorder)

                    let options = PaymentSourceCatalog.search(paymentSourceQuery).prefix(8)
                    ForEach(Array(options)) { option in
                        Button {
                            viewModel.paymentMethod = option.label
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: option.systemImage)
                                    .foregroundColor(themeManager.current.accentColor)
                                    .frame(width: 20)
                                Text(option.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                                Spacer()
                                if viewModel.paymentMethod == option.label {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(themeManager.current.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.paymentMethod != nil,
                       viewModel.paymentMethod != "Barter",
                       !(viewModel.paymentMethod?.hasPrefix("Cash (") ?? false) {
                        Button("Clear payment source") {
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
                Text("Barter Details")
                    .buxSectionLabelStyle(color: .orange)
            }

            VStack(spacing: BuxLayout.tight) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GOODS / SERVICES GIVEN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .kerning(0.5)
                    TextField("What did you give? (e.g. web design)", text: $viewModel.barterGoodsGiven, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }

                Divider().opacity(0.12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("GOODS / SERVICES RECEIVED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .kerning(0.5)
                    TextField("What did you receive? (e.g. boat repairs)", text: $viewModel.barterGoodsReceived, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }

                Divider().opacity(0.12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTIMATED VALUE (\(appSettingsManager.selectedCurrency.id))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .kerning(0.5)
                    TextField("Estimated monetary value", text: $viewModel.barterEstimatedValue)
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
            TextField("Notes (optional)", text: $viewModel.notes, axis: .vertical)
                .lineLimit(2...5)
        }
        .padding(BuxLayout.section)
        .expensesThemedCardChrome(cornerRadius: 20)
    }

    private var emotionalCard: some View {
        VStack(alignment: .leading, spacing: BuxLayout.tight) {
            Text("How did this feel?")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            EmotionalTagPickerView(selection: $viewModel.emotionTag)
                .environmentObject(themeManager)
                .padding(BuxLayout.section)
                .expensesThemedCardChrome(cornerRadius: 20)
        }
    }

    private var merchantPickSheet: some View {
        NavigationStack {
            List {
                ForEach(viewModel.candidates.filter { $0.matchKind != .newMerchant }) { candidate in
                    Button {
                        viewModel.selectCandidate(candidate)
                        viewModel.showMerchantPickSheet = false
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
            .navigationTitle("Choose merchant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BuxToolbarCancelButton { viewModel.showMerchantPickSheet = false }
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
