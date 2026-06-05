//
//  ExpenseMerchantListSheet.swift
//  BuxMuse
//
//  Large scrollable merchant hub — no nested slide-up cards.
//

import SwiftUI

struct ExpenseMerchantListSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    @State private var merchants: [ExpenseMerchantRecord] = []
    @State private var expenseRecords: [ExpenseRecord] = []
    @State private var expandedMerchantId: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.screenBackground(for: colorScheme).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(merchants) { merchant in
                            merchantCard(merchant)
                        }
                    }
                    .padding(.top, BuxLayout.tight)
                    .padding(.bottom, BuxOverlayMetrics.scrollBottomInset)
                    .buxScreenContentMargins()
                }
                .buxDetailScrollChrome()
            }
            .navigationTitle("Merchants")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(MerchantSheetSubtitleModifier())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    BuxToolbarDoneButton { dismiss() }
                }
            }
            .buxDetailNavigationChrome()
        }
        .buxMeshSheetPresentation()
        .onAppear {
            merchants = (try? brain.fetchAllMerchantRecords()) ?? []
            expenseRecords = (try? brain.fetchAllExpenseRecords()) ?? []
        }
    }

    @ViewBuilder
    private func merchantCard(_ merchant: ExpenseMerchantRecord) -> some View {
        let isOpen = expandedMerchantId == merchant.id
        let info = brain.merchantBrain.listDisplayInfo(for: merchant, expenseRecords: expenseRecords)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    expandedMerchantId = isOpen ? nil : merchant.id
                }
            } label: {
                HStack(spacing: 14) {
                    AsyncMerchantLogoView(merchantName: merchant.name, size: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(merchant.displayTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(themeManager.labelPrimary(for: colorScheme))

                        Text(merchantSummaryLine(info: info, merchant: merchant))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }

                    Spacer()

                    if merchant.isSubscriptionMerchant {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.current.accentColor)
                    }

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
                .padding(16)
            }
            .buttonStyle(BuxMicroShrinkStyle())

            if isOpen {
                MerchantInlineEditor(merchant: merchant) { updated in
                    if let index = merchants.firstIndex(where: { $0.id == updated.id }) {
                        merchants[index] = updated
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .expensesThemedCardChrome(cornerRadius: 18)
    }

    private func merchantSummaryLine(info: MerchantListDisplayInfo, merchant: ExpenseMerchantRecord) -> String {
        var parts: [String] = []
        if info.expenseCount > 0 {
            parts.append("\(info.expenseCount) expense\(info.expenseCount == 1 ? "" : "s")")
        }
        if info.variantCount > 1 {
            parts.append("\(info.variantCount) labels")
        }
        if let canonical = info.canonicalLabel, !canonical.isEmpty, canonical != merchant.name {
            parts.append(canonical)
        }
        return parts.isEmpty ? (merchant.cluster ?? "Merchant") : parts.joined(separator: " · ")
    }
}

private struct MerchantSheetSubtitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.navigationSubtitle("Tap a merchant to review details. Changes save automatically.")
        } else {
            content.safeAreaInset(edge: .top, spacing: 0) {
                BuxCatalogText.text("Tap a merchant to review details. Changes save automatically.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BuxLayout.loose)
                    .padding(.bottom, BuxLayout.tight)
            }
        }
    }
}

// MARK: - Inline editor (same sheet, no second popup)

private struct MerchantInlineEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain

    let merchant: ExpenseMerchantRecord
    let onSaved: (ExpenseMerchantRecord) -> Void

    @State private var working: ExpenseMerchantRecord
    @State private var disambiguatorText: String

    init(merchant: ExpenseMerchantRecord, onSaved: @escaping (ExpenseMerchantRecord) -> Void) {
        self.merchant = merchant
        self.onSaved = onSaved
        _working = State(initialValue: merchant)
        _disambiguatorText = State(initialValue: merchant.disambiguator)
    }

    private var needsDisambiguatorHint: Bool {
        brain.merchantBrain.needsDisambiguatorLabel(
            for: working.name,
            disambiguator: disambiguatorText.isEmpty ? nil : disambiguatorText
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().opacity(0.08)

            VStack(alignment: .leading, spacing: 6) {
                BuxCatalogText.text("Canonical name")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                Text(working.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField(BuxCatalogLabel.string("Label (e.g. Food, Clothes)", locale: appSettingsManager.interfaceLocale), text: $disambiguatorText)
                    .font(.system(size: 15, weight: .medium))
                    .textInputAutocapitalization(.words)
                    .onChange(of: disambiguatorText) { _, _ in
                        persist()
                    }

                if needsDisambiguatorHint {
                    BuxCatalogText.text("Another merchant shares this name — add a label to tell them apart.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                } else if !disambiguatorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(
                        BuxLocalizedString.format(
                            "Shown as %@ · %@",
                            locale: appSettingsManager.interfaceLocale,
                            working.name,
                            disambiguatorText.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            Toggle(BuxCatalogLabel.string("Subscription merchant", locale: appSettingsManager.interfaceLocale), isOn: subscriptionBinding)
                .font(.system(size: 15, weight: .semibold))
                .tint(themeManager.current.accentColor)

            if let risk = working.riskScore {
                Text(
                    BuxLocalizedString.format(
                        "Risk score: %.0f%%",
                        locale: appSettingsManager.interfaceLocale,
                        risk * 100
                    )
                )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .onChange(of: merchant) { _, updated in
            working = updated
            disambiguatorText = updated.disambiguator
        }
    }

    private var subscriptionBinding: Binding<Bool> {
        Binding(
            get: { working.isSubscriptionMerchant },
            set: { newValue in
                working.isSubscriptionMerchant = newValue
                persist()
            }
        )
    }

    private func persist() {
        var updated = working
        updated.disambiguator = disambiguatorText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (try? brain.updateMerchant(updated)) != nil else { return }
        working = updated
        onSaved(updated)
    }
}
