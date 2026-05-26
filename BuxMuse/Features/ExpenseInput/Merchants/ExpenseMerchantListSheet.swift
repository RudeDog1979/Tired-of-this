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
    @EnvironmentObject private var brain: BuxMuseBrain

    @State private var merchants: [ExpenseMerchantRecord] = []
    @State private var expandedMerchantId: UUID?

    private var cardColor: Color {
        themeManager.cardFill(for: colorScheme)
    }

    var body: some View {
        ZStack {
            themeManager.screenBackground(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(merchants) { merchant in
                            merchantCard(merchant)
                        }
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }

                doneBar
            }
        }
        .onAppear {
            merchants = (try? brain.fetchAllMerchantRecords()) ?? []
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Merchants")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))

            Text("Tap a merchant to review details. Changes save automatically.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BuxLayout.loose)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var doneBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.08)
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.current.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(BuxMicroShrinkStyle())
            .padding(.horizontal, BuxLayout.marginHorizontal)
            .padding(.vertical, 16)
            .background(themeManager.screenBackground(for: colorScheme))
        }
    }

    @ViewBuilder
    private func merchantCard(_ merchant: ExpenseMerchantRecord) -> some View {
        let isOpen = expandedMerchantId == merchant.id

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    expandedMerchantId = isOpen ? nil : merchant.id
                }
            } label: {
                HStack(spacing: 14) {
                    AsyncMerchantLogoView(merchantName: merchant.name, size: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(merchant.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))

                        if let cluster = merchant.cluster, !cluster.isEmpty {
                            Text(cluster)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
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
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(themeManager.subtleCardStroke(for: colorScheme), lineWidth: 1)
        )
    }
}

// MARK: - Inline editor (same sheet, no second popup)

private struct MerchantInlineEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var brain: BuxMuseBrain

    let merchant: ExpenseMerchantRecord
    let onSaved: (ExpenseMerchantRecord) -> Void

    @State private var isSubscriptionMerchant: Bool

    init(merchant: ExpenseMerchantRecord, onSaved: @escaping (ExpenseMerchantRecord) -> Void) {
        self.merchant = merchant
        self.onSaved = onSaved
        _isSubscriptionMerchant = State(initialValue: merchant.isSubscriptionMerchant)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().opacity(0.08)

            Toggle("Subscription merchant", isOn: $isSubscriptionMerchant)
                .font(.system(size: 15, weight: .semibold))
                .tint(themeManager.current.accentColor)
                .onChange(of: isSubscriptionMerchant) { _, _ in
                    persist()
                }

            if let risk = merchant.riskScore {
                Text(String(format: "Risk score: %.0f%%", risk * 100))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }

    private func persist() {
        var updated = merchant
        updated.isSubscriptionMerchant = isSubscriptionMerchant
        try? brain.updateMerchant(updated)
        onSaved(updated)
    }
}
