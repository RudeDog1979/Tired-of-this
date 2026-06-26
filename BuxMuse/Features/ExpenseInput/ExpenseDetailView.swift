//
//  ExpenseDetailView.swift
//  BuxMuse
//
//  Full-screen expense detail — shell aligned with SubscriptionDetailView.
//

import SwiftUI

struct ExpenseDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.buxPadExpenseDetailEmbedded) private var isPadEmbedded
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var padNavigationBrain: BuxPadNavigationBrain
    @EnvironmentObject private var debtEngine: DebtEngine

    @StateObject private var viewModel: ExpenseDetailViewModel
    @State private var showCategorySheet = false
    @State private var showEditSheet = false
    @State private var showLinkPaycheckSheet = false
    @State private var showLinkDebtPaymentSheet = false
    /// Keeps mood visuals on screen while fading out after clear/save.
    @State private var presentedEmotionId: String?
    @State private var emotionTintOpacity: Double = 0
    @State private var emotionWatermarkOpacity: Double = 0
    @State private var showPadDeleteConfirmation = false

    let brain: BuxMuseBrain
    let onUpdated: () -> Void

    @ObservedObject private var settings = SettingsStore.shared

    private var categoryDisplayName: String {
        let records = (try? brain.fetchAllCategoryRecords()) ?? []
        let byId = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return viewModel.record.resolvedCategoryLabel(
            categoriesById: byId,
            locale: appSettingsManager.interfaceLocale
        )
    }

    init(record: ExpenseRecord, brain: BuxMuseBrain, settingsManager: AppSettingsManager, onUpdated: @escaping () -> Void) {
        self.brain = brain
        self.onUpdated = onUpdated
        _viewModel = StateObject(wrappedValue: ExpenseDetailViewModel(
            record: record,
            brain: brain,
            settingsManager: settingsManager
        ))
    }

    var body: some View {
        Group {
            if isPadEmbedded {
                padEmbeddedDetailBody
            } else {
                phoneDetailBody
            }
        }
        .sheet(isPresented: $showCategorySheet) {
            ExpenseCategorySheet(transaction: viewModel.record.toTransaction()) { category, categoryId in
                try? viewModel.changeCategory(category, categoryId: categoryId)
                onUpdated()
            }
            .environmentObject(themeManager)
            .environmentObject(brain)
            .buxThemedSheetContent()
        }
        .sheet(isPresented: $showEditSheet) {
            AddExpenseSheet(brain: brain, settingsManager: appSettingsManager, mode: .edit(viewModel.record.toTransaction()))
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
                .environment(\.expensesEnhancedTint, true)
                .onDisappear {
                    viewModel.reloadRecord()
                    onUpdated()
                }
        }
        .onAppear {
            syncEmotionPresentation(animated: false)
        }
        .onChange(of: viewModel.record.emotion) { _, _ in
            syncEmotionPresentation(animated: true)
        }
        .buxPadExpenseDeleteConfirmation(
            isPresented: $showPadDeleteConfirmation,
            locale: appSettingsManager.interfaceLocale,
            onConfirm: performDeleteExpense
        )
        .sheet(isPresented: $showLinkPaycheckSheet) {
            LinkPaycheckSheet(record: viewModel.record)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(brain)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .buxThemedSheetContent()
                .onDisappear {
                    viewModel.reloadRecord()
                    onUpdated()
                }
        }
        .sheet(isPresented: $showLinkDebtPaymentSheet) {
            LinkDebtPaymentSheet(record: viewModel.record, debtEngine: debtEngine)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(debtEngine)
                .environmentObject(brain)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .buxThemedSheetContent()
                .onDisappear {
                    viewModel.reloadRecord()
                    onUpdated()
                }
        }
    }

    private var linkedDebt: Debt? {
        debtEngine.linkedDebt(for: viewModel.record.id)
    }

    private var canLinkToDebt: Bool {
        settings.consumerDebtEnabled
            && viewModel.record.amountValue < 0
            && linkedDebt == nil
            && !debtEngine.activeDebts.isEmpty
    }

    private var canLinkPaycheck: Bool {
        viewModel.record.amountValue > 0 && !viewModel.record.isSalaryTagged
    }

    private func syncEmotionPresentation(animated: Bool) {
        let activeId = normalizedEmotionId(viewModel.record.emotion)

        if let activeId {
            presentedEmotionId = activeId
            if animated {
                emotionTintOpacity = 0
                emotionWatermarkOpacity = 0
                withAnimation(BuxMotion.emotionFadeIn) {
                    emotionTintOpacity = 1
                    emotionWatermarkOpacity = 1
                }
            } else {
                emotionTintOpacity = 1
                emotionWatermarkOpacity = 1
            }
            return
        }

        guard presentedEmotionId != nil || emotionTintOpacity > 0.01 else { return }

        if animated {
            withAnimation(BuxMotion.emotionFadeOut) {
                emotionTintOpacity = 0
                emotionWatermarkOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + BuxMotion.emotionFadeOutDuration) {
                guard normalizedEmotionId(viewModel.record.emotion) == nil else { return }
                presentedEmotionId = nil
            }
        } else {
            emotionTintOpacity = 0
            emotionWatermarkOpacity = 0
            presentedEmotionId = nil
        }
    }

    private func normalizedEmotionId(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Phone full-screen detail uses 20pt rails; iPad split sidebar matches Studio (~8pt).
    private var detailHorizontalInset: CGFloat {
        isPadEmbedded ? 8 : BuxLayout.marginHorizontal
    }

    private var overviewCardInnerPadding: CGFloat {
        isPadEmbedded ? 16 : 28
    }

    private var detailCardInnerPadding: CGFloat {
        isPadEmbedded ? 14 : 20
    }

    private var overviewCard: some View {
        let emotion = presentedEmotionId
        let emotionTag = emotion.flatMap { EmotionalTaggingEngine.tag(for: $0) }
        let moodAccent = EmotionalTagAppearance.accent(for: emotion, colorScheme: colorScheme)
        let brandAccent = themeManager.contrastAccentColor(for: colorScheme)
        let cornerRadius: CGFloat = 28
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let chrome = themeManager.cardChrome(for: .hero, colorScheme: colorScheme, branded: settings.brandThemesEnabled)

        return ZStack {
            BuxThemedCardPlateBackground(cornerRadius: cornerRadius)

            if emotion != nil {
                EmotionalTagAppearance.cardBackground(
                    tagId: emotion,
                    colorScheme: colorScheme,
                    base: themeManager.cardFill(for: colorScheme),
                    cornerRadius: cornerRadius,
                    tintOpacity: emotionTintOpacity
                )

                if let tag = emotionTag {
                    EmotionalTagAppearance.watermark(
                        tag: tag,
                        colorScheme: colorScheme,
                        locale: appSettingsManager.interfaceLocale,
                        scale: .detailCard,
                        opacity: emotionWatermarkOpacity,
                        includeLabel: true
                    )
                    .clipShape(shape)
                }
            }

            VStack(spacing: 16) {
                ExpenseLedgerAvatarView(record: viewModel.record, size: 56)
                    .environmentObject(brain)
                    .shadow(radius: 4)

                VStack(spacing: 4) {
                    Text(viewModel.formattedAmount())
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Text(categoryDisplayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(brandAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(brandAccent.opacity(0.12))
                            if let moodAccent {
                                Capsule()
                                    .fill(moodAccent.opacity(0.12))
                                    .opacity(emotionTintOpacity)
                            }
                        }
                        .animation(BuxMotion.emotionFadeOut, value: emotionTintOpacity)
                }

                Label(
                    BuxDisplayDate.dateAndTime(from: viewModel.record.date, locale: appSettingsManager.interfaceLocale),
                    systemImage: "calendar"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.labelSecondary(for: colorScheme))

                Button { showCategorySheet = true } label: {
                    BuxCatalogText.text("Change category")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buttonStyle(BuxMicroShrinkStyle())
            }
            .padding(overviewCardInnerPadding)
        }
        .compositingGroup()
        .clipShape(shape)
        .overlay {
            ZStack {
                if chrome.strokeWidth > 0 {
                    shape.stroke(chrome.stroke, lineWidth: chrome.strokeWidth)
                }
                if emotion != nil {
                    shape.stroke(
                        EmotionalTagAppearance.cardStroke(
                            for: emotion,
                            colorScheme: colorScheme,
                            fallback: DashboardThemeTint.themedCardStroke(
                                themeManager: themeManager,
                                colorScheme: colorScheme
                            )
                        ),
                        lineWidth: 1.5
                    )
                    .opacity(emotionTintOpacity)
                }
            }
        }
        .animation(BuxMotion.emotionFadeOut, value: emotionTintOpacity)
        .shadow(color: chrome.shadowColor, radius: chrome.shadowRadius, x: 0, y: chrome.shadowY)
        .padding(.horizontal, detailHorizontalInset)
    }

    @ViewBuilder
    private var intelligenceSections: some View {
        let warnings = insightItems.filter(\.isWarning)
        let standard = insightItems.filter { !$0.isWarning }

        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BuxCatalogText.text("Detected pattern warnings")
                    .buxSectionLabelStyle(color: .red.opacity(0.8))

                ForEach(warnings, id: \.title) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .foregroundColor(.red)
                        Text(item.body)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.12), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, detailHorizontalInset)
        }

        if !standard.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BuxCatalogText.text("Intelligence insights")
                    .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(standard, id: \.title) { item in
                        if item.title != standard.first?.title {
                            Divider().opacity(0.08)
                        }
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localizedInsightTitle(item.title))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                Text(item.body)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : Color(red: 40/255, green: 44/255, blue: 52/255))
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(detailCardInnerPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .expensesThemedCardChrome(cornerRadius: 20)
            }
            .padding(.horizontal, detailHorizontalInset)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BuxCatalogText.text("Notes")
                .buxSectionLabelStyle(color: themeManager.sectionHeaderColor(for: colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                if viewModel.record.financeKitTransactionId != nil,
                   WalletStatementIntelligence.isWalletImportNote(viewModel.notesDraft) {
                    Text(ExpenseDisplayL10n.note(viewModel.notesDraft, locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.labelSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField(BuxCatalogLabel.string("Add a note", locale: appSettingsManager.interfaceLocale), text: $viewModel.notesDraft, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                    Button(BuxCatalogLabel.string("Save note", locale: appSettingsManager.interfaceLocale)) {
                        try? viewModel.saveNotes()
                        onUpdated()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    .buttonStyle(BuxMicroShrinkStyle())
                }
            }
            .padding(detailCardInnerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .expensesThemedCardChrome(cornerRadius: 20)
        }
        .padding(.horizontal, detailHorizontalInset)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if canLinkPaycheck {
                primaryAction("Link as paycheck", icon: "briefcase.fill") {
                    showLinkPaycheckSheet = true
                }
            }

            if canLinkToDebt {
                primaryAction("Log as debt payment", icon: "creditcard.and.123") {
                    showLinkDebtPaymentSheet = true
                }
            }

            primaryAction("Edit transaction", icon: "pencil") {
                showEditSheet = true
            }

            if viewModel.record.amountValue < 0 {
                primaryAction(
                    viewModel.record.isExcludedFromSpending ? "Include in spending" : "Exclude from spending",
                    icon: viewModel.record.isExcludedFromSpending ? "chart.bar.fill" : "chart.bar.xaxis"
                ) {
                    try? viewModel.setExcludedFromSpending(!viewModel.record.isExcludedFromSpending)
                    onUpdated()
                }
            }

            primaryAction("Convert to subscription", icon: "arrow.triangle.2.circlepath") {
                try? viewModel.convertToSubscription()
                onUpdated()
            }
            primaryAction("Mark as recurring", icon: "calendar.badge.clock") {
                try? viewModel.markRecurring()
                onUpdated()
            }

            BuxButton(
                title: "Delete expense",
                systemImage: "trash.fill",
                role: .destructive,
                expands: true
            ) {
                showPadDeleteConfirmation = true
            }
        }
        .padding(.horizontal, detailHorizontalInset)
    }

    private func primaryAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                BuxCatalogText.text(title)
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

    private struct InsightItem {
        let title: String
        let body: String
        let icon: String
        let isWarning: Bool
    }

    private var insightItems: [InsightItem] {
        var items: [InsightItem] = []
        let intel = viewModel.intelligence
        let locale = appSettingsManager.interfaceLocale
        if let s = intel.duplicateSummary {
            items.append(.init(title: BuxCatalogLabel.string("Duplicate", locale: locale), body: s, icon: "exclamationmark.triangle.fill", isWarning: true))
        }
        if let s = intel.refundSummary {
            items.append(.init(title: BuxCatalogLabel.string("Refund", locale: locale), body: s, icon: "exclamationmark.triangle.fill", isWarning: true))
        }
        if let s = intel.recurrenceSummary {
            items.append(.init(title: BuxCatalogLabel.string("Recurrence", locale: locale), body: s, icon: "arrow.triangle.2.circlepath", isWarning: false))
        }
        if let s = intel.subscriptionSummary {
            items.append(.init(title: BuxCatalogLabel.string("Subscription", locale: locale), body: s, icon: "repeat.circle", isWarning: false))
        }
        if let s = intel.heatZoneSummary {
            items.append(.init(title: BuxCatalogLabel.string("Heat zone", locale: locale), body: s, icon: "flame", isWarning: false))
        }
        if let s = intel.futureImpactSummary {
            items.append(.init(title: BuxCatalogLabel.string("Future impact", locale: locale), body: s, icon: "calendar.badge.clock", isWarning: false))
        }
        if let s = intel.habitSignatureSummary {
            items.append(.init(title: BuxCatalogLabel.string("Habit signature", locale: locale), body: s, icon: "arrow.triangle.2.circlepath", isWarning: false))
        }
        if let s = intel.microCommitmentSummary {
            items.append(.init(title: BuxCatalogLabel.string("Micro commitment", locale: locale), body: s, icon: "target", isWarning: false))
        }
        if let s = intel.emotionalTagSummary {
            items.append(.init(title: BuxCatalogLabel.string("Emotional tag", locale: locale), body: s, icon: "face.smiling", isWarning: false))
        }
        if let s = intel.contextTagSummary {
            items.append(.init(title: BuxCatalogLabel.string("Context", locale: locale), body: s, icon: "tag", isWarning: false))
        }
        if let s = intel.categoryInsight {
            items.append(.init(title: BuxCatalogLabel.string("Category", locale: locale), body: s, icon: "chart.bar", isWarning: false))
        }
        if let s = intel.merchantInsight {
            items.append(.init(title: BuxCatalogLabel.string("Merchant", locale: locale), body: s, icon: "building.2", isWarning: false))
        }
        if let s = intel.goalsImpact {
            items.append(.init(title: BuxCatalogLabel.string("Goals", locale: locale), body: s, icon: "target", isWarning: false))
        }
        if let s = intel.subscriptionsImpact {
            items.append(.init(title: BuxCatalogLabel.string("Subscriptions", locale: locale), body: s, icon: "creditcard", isWarning: false))
        }
        return items
    }

    private func localizedInsightTitle(_ key: String) -> String {
        BuxCatalogLabel.string(key, locale: appSettingsManager.interfaceLocale)
    }

    private func closeDetail() {
        if isPadEmbedded {
            padNavigationBrain.clearExpenseSelection()
        } else {
            dismiss()
        }
    }

    private func performDeleteExpense() {
        try? viewModel.delete()
        onUpdated()
        closeDetail()
    }

    private var detailCardStack: some View {
        VStack(spacing: 24) {
            overviewCard
            intelligenceSections
            notesSection
            actionsSection
        }
        .padding(.bottom, 48)
    }

    private var detailScrollContent: some View {
        ScrollView(showsIndicators: false) {
            detailCardStack
                .buxScreenContentMargins()
        }
        .buxDetailScrollChrome()
    }

    /// iPad split left column — parent sidebar List scrolls; tight rails like Studio sidebar rows.
    private var padEmbeddedDetailBody: some View {
        detailCardStack
            .environment(\.expensesEnhancedTint, true)
            .buxInterfaceLocale()
            .onChange(of: appSettingsManager.selectedCountry.id) { _, _ in
                viewModel.reloadIntelligence()
            }
    }

    private var phoneDetailBody: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()
                detailScrollContent
            }
            .navigationTitle(
                ExpenseDisplayL10n.label(viewModel.record.name, locale: appSettingsManager.interfaceLocale)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    BuxToolbarBackButton { closeDetail() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(BuxCatalogLabel.string("Edit", locale: appSettingsManager.interfaceLocale)) { showEditSheet = true }
                        .buxToolbarTextActionStyle(accent: themeManager.contrastAccentColor(for: colorScheme))
                }
            }
            .buxDetailNavigationChrome()
            .environment(\.expensesEnhancedTint, true)
            .buxInterfaceLocale()
            .onChange(of: appSettingsManager.selectedCountry.id) { _, _ in
                viewModel.reloadIntelligence()
            }
        }
    }
}
