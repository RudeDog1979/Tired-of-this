//
//  WorkspaceDetailEditorSheet.swift
//  BuxMuse
//
//  Virtual-desktop identity + auto-routing rules for a single workspace.
//

import SwiftUI

struct WorkspaceDetailEditorSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @State private var draft: Hustle
    @State private var newPaymentKeyword = ""
    @State private var newMerchantKeyword = ""
    @State private var budgetLimitText = ""

    let onSave: (Hustle) -> Void

    private let premiumColors = [
        "#9C27B0", "#00E5FF", "#30D158", "#FF5E5B", "#FF9F0A", "#5A55F5"
    ]

    init(hustle: Hustle, onSave: @escaping (Hustle) -> Void) {
        _draft = State(initialValue: hustle)
        if let limit = hustle.budgetLimit {
            _budgetLimitText = State(initialValue: String(format: "%.2f", NSDecimalNumber(decimal: limit).doubleValue))
        }
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                BuxThemedCardForm {
                    identitySection
                    themeSection
                    currencySection
                    budgetSection
                    paymentRulesSection
                    merchantRulesSection
                    statusSection
                }
                .padding(.vertical, BuxLayout.tight)
            }
            .buxRootNavigationChrome()
            .buxMeshSheetPresentation()
            .buxCatalogNavigationTitle("Workspace details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BuxCatalogLabel.string("Cancel", locale: appSettingsManager.interfaceLocale)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(BuxCatalogLabel.string("Save", locale: appSettingsManager.interfaceLocale)) {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .environment(\.isSettingsContext, true)
    }

    private var identitySection: some View {
        BuxFormSection(title: "Identity") {
            VStack(alignment: .leading, spacing: 14) {
                TextField(
                    BuxCatalogLabel.string("Workspace name", locale: appSettingsManager.interfaceLocale),
                    text: $draft.name
                )
                .font(.system(size: 15, weight: .semibold))
                .tint(themeManager.contrastAccentColor(for: colorScheme))
                .textFieldStyle(.plain)

                Divider().opacity(0.1)

                VStack(alignment: .leading, spacing: 8) {
                    BuxCatalogDynamicText(key: "Brand color")
                        .font(.system(size: 12, weight: .bold))
                        .buxLabelSecondary()

                    HStack(spacing: 12) {
                        ForEach(premiumColors, id: \.self) { colorHex in
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                    draft.colorHex = colorHex
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 28, height: 28)
                                    if draft.colorHex == colorHex {
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .buxFormFieldPadding()
        }
    }

    private var themeSection: some View {
        BuxFormSection(title: "Visual theme") {
            VStack(alignment: .leading, spacing: 12) {
                BuxCatalogDynamicText(key: "Optional theme for this virtual desktop. Leave on app default to inherit global Appearance.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    draft.themeName = nil
                } label: {
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                        BuxCatalogDynamicText(key: "Use app default")
                        Spacer()
                        if draft.themeName == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(AppTheme.all) { theme in
                            ThemeSwatchCard(
                                theme: theme,
                                isSelected: draft.themeName == theme.id,
                                layout: .carousel
                            ) {
                                draft.themeName = theme.id
                            }
                            .frame(width: 168)
                        }
                    }
                    .padding(.vertical, 14)
                }
                .scrollTargetLayout()
                .modifier(BuxHorizontalSnapScrollModifier())
                .modifier(BuxCarouselScrollClipModifier())
            }
            .buxFormFieldPadding()
        }
    }

    private var currencySection: some View {
        BuxFormSection(title: "Display currency") {
            VStack(alignment: .leading, spacing: 10) {
                BuxCatalogDynamicText(key: "Formatting for summaries while this workspace is selected. Does not change your global region setting.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                Picker(
                    BuxCatalogLabel.string("Display currency", locale: appSettingsManager.interfaceLocale),
                    selection: currencySelection
                ) {
                    BuxCatalogText.text("Use app default").tag(Optional<String>.none)
                    ForEach(AppSettingsManager.availableCurrencies) { currency in
                        Text(currency.name).tag(Optional(currency.id))
                    }
                }
                .pickerStyle(.menu)
            }
            .buxFormFieldPadding()
        }
    }

    private var budgetSection: some View {
        BuxFormSection(title: "Workspace budget") {
            VStack(alignment: .leading, spacing: 10) {
                BuxCatalogDynamicText(key: "Optional monthly spend cap while this workspace is selected. Uses your global budget cycle.")
                    .font(.system(size: 12, weight: .medium))
                    .buxLabelSecondary()
                    .fixedSize(horizontal: false, vertical: true)

                TextField(
                    BuxCatalogLabel.string("Budget limit (optional)", locale: appSettingsManager.interfaceLocale),
                    text: $budgetLimitText
                )
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .semibold))
                .textFieldStyle(.plain)
            }
            .buxFormFieldPadding()
        }
    }

    private var paymentRulesSection: some View {
        BuxFormSection(title: "Payment method keywords") {
            ruleEditor(
                rules: paymentRulesBinding,
                newText: $newPaymentKeyword,
                placeholderKey: "e.g. visa, paypal",
                emptyHintKey: "Match substrings in the payment method field (case-insensitive)."
            )
        }
    }

    private var merchantRulesSection: some View {
        BuxFormSection(title: "Merchant keywords") {
            ruleEditor(
                rules: merchantRulesBinding,
                newText: $newMerchantKeyword,
                placeholderKey: "e.g. aws, adobe",
                emptyHintKey: "Match merchant name or notes. First workspace rule wins."
            )
        }
    }

    private var statusSection: some View {
        BuxFormSection(title: "Status") {
            Toggle(isOn: $draft.isActive) {
                BuxCatalogDynamicText(key: "Active workspace")
                    .font(.system(size: 15, weight: .semibold))
            }
            .tint(themeManager.contrastAccentColor(for: colorScheme))
            .buxFormFieldPadding()
        }
    }

    private var currencySelection: Binding<String?> {
        Binding(
            get: { draft.currencyCode },
            set: { draft.currencyCode = $0 }
        )
    }

    private var paymentRulesBinding: Binding<[String]> {
        Binding(
            get: { draft.cardRules ?? [] },
            set: { draft.cardRules = $0.isEmpty ? nil : $0 }
        )
    }

    private var merchantRulesBinding: Binding<[String]> {
        Binding(
            get: { draft.merchantRules ?? [] },
            set: { draft.merchantRules = $0.isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder
    private func ruleEditor(
        rules: Binding<[String]>,
        newText: Binding<String>,
        placeholderKey: String,
        emptyHintKey: String
    ) -> some View {
        let locale = appSettingsManager.interfaceLocale
        VStack(alignment: .leading, spacing: 12) {
            Text(BuxCatalogLabel.string(emptyHintKey, locale: locale))
                .font(.system(size: 12, weight: .medium))
                .buxLabelSecondary()
                .fixedSize(horizontal: false, vertical: true)

            if !rules.wrappedValue.isEmpty {
                ForEach(Array(rules.wrappedValue.enumerated()), id: \.offset) { index, rule in
                    HStack {
                        Text(rule)
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Button(role: .destructive) {
                            var updated = rules.wrappedValue
                            updated.remove(at: index)
                            rules.wrappedValue = updated
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                    if index < rules.wrappedValue.count - 1 {
                        BuxFormRowDivider()
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(BuxCatalogLabel.string(placeholderKey, locale: locale), text: newText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))

                Button {
                    appendRule(newText: newText, to: rules)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                .buttonStyle(.plain)
                .disabled(newText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .buxFormFieldPadding()
    }

    private func appendRule(newText: Binding<String>, to rules: Binding<[String]>) {
        let trimmed = newText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = rules.wrappedValue
        guard !updated.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            newText.wrappedValue = ""
            return
        }
        updated.append(trimmed)
        rules.wrappedValue = updated
        newText.wrappedValue = ""
    }

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBudget = budgetLimitText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBudget.isEmpty {
            draft.budgetLimit = nil
        } else {
            let normalized = trimmedBudget.replacingOccurrences(of: ",", with: ".")
            draft.budgetLimit = Decimal(string: normalized)
        }
        onSave(draft)
        dismiss()
    }
}
