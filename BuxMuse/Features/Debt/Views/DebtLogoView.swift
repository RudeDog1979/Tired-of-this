//
//  DebtLogoView.swift
//  BuxMuse
//
//  Bank logo only for known institutions; category icons for everyone else.
//

import SwiftUI

struct DebtLogoView: View {
    let debt: Debt
    var size: CGFloat = 40

    var body: some View {
        if debt.shouldFetchInstitutionLogo, let name = debt.institutionLogoName {
            DebtInstitutionLogoView(institutionName: name, size: size)
        } else {
            DebtSourceIconView(
                lenderSource: debt.lenderSource,
                debtType: debt.type,
                displayName: debt.logoMerchantName,
                size: size
            )
        }
    }
}

struct DebtSourceIconView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let lenderSource: DebtLenderSource
    let debtType: DebtType
    let displayName: String
    var size: CGFloat = 40

    private var symbol: String {
        switch lenderSource {
        case .other:
            return debtType.systemImage
        default:
            return lenderSource.systemImage
        }
    }

    private var background: Color {
        let hash = abs(displayName.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: colorScheme == .dark ? 0.45 : 0.52, brightness: colorScheme == .dark ? 0.55 : 0.72)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [background, background.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if lenderSource == .privateIndividual || lenderSource == .friendOrFamily,
               !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(monogramInitials)
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25), lineWidth: 1)
        )
        .accessibilityLabel(displayName)
    }

    private var monogramInitials: String {
        let words = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        if words.count >= 2 {
            return String((words[0].first ?? Character("?")).uppercased() + (words[1].first ?? Character("?")).uppercased())
        }
        if let first = words.first {
            return String(first.prefix(2).uppercased())
        }
        return "?"
    }
}

struct DebtInstitutionLogoView: View {
    let institutionName: String
    var size: CGFloat = 40

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image, !loadFailed {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                DebtSourceIconView(
                    lenderSource: .bank,
                    debtType: .creditCard,
                    displayName: institutionName,
                    size: size
                )
            }
        }
        .frame(width: size, height: size)
        .task(id: institutionName) {
            await loadLogo()
        }
    }

    private func loadLogo() async {
        image = nil
        loadFailed = false
        guard let domain = FinancialInstitutionCatalog.domain(for: institutionName),
              let plan = MerchantLogoEngine.fetchPlanForKnownDomain(domain) else {
            loadFailed = true
            return
        }

        if let cached = LightweightLogoCache.shared.getImage(forKey: plan.cacheKey) {
            image = cached
            return
        }

        let shouldFetch = await MainActor.run { ConnectivityBrain.shared.shouldFetchMerchantIcons }
        guard shouldFetch else {
            loadFailed = true
            return
        }

        guard let fetched = await MerchantLogoFetchCoordinator.shared.image(for: plan, shouldFetch: shouldFetch) else {
            loadFailed = true
            return
        }
        image = fetched
    }
}

struct DebtCurrencyAmountField: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @Environment(\.colorScheme) private var colorScheme

    let placeholderKey: String
    @Binding var amountText: String

    var body: some View {
        HStack(spacing: 6) {
            Text(appSettingsManager.selectedCurrency.symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(themeManager.contrastAccentColor(for: colorScheme))
            TextField(
                BuxCatalogLabel.string(placeholderKey, locale: appSettingsManager.interfaceLocale),
                text: $amountText
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .onChange(of: amountText) { _, newValue in
                formatAmountWhileTyping(newValue)
            }
        }
    }

    private func formatAmountWhileTyping(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let decimalSeparator = appSettingsManager.decimalInputFormatter.decimalSeparator ?? "."
        if trimmed.hasSuffix(decimalSeparator) { return }
        if trimmed.hasSuffix("\(decimalSeparator)0") || trimmed.hasSuffix("\(decimalSeparator)00") {
            return
        }

        guard let decimal = appSettingsManager.parseAmountInput(trimmed) else { return }
        let formatted = appSettingsManager.formatAmountInput(decimal)
        guard formatted != raw else { return }
        amountText = formatted
    }
}
