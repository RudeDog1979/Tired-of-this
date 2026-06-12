//
//  SimpleStudioSearchView.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioSearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.buxPadStudioUsesSplitLayout) private var usesPadSplitLayout
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore

    @ObservedObject var store: SimpleStudioStore

    var initialQuery: String = ""
    var isProSearch: Bool = false

    @State private var query = ""
    @State private var detailDestination: SimpleStudioDetailDestination?

    private var suggestionQueries: [String] {
        isProSearch ? ProStudioSearchEngine.suggestionQueries : SimpleStudioSearchEngine.simpleSuggestionQueries
    }

    private var results: [SimpleStudioSearchEngine.Result] {
        SimpleStudioSearchEngine.search(
            query: query,
            snapshot: store.snapshot,
            format: appSettingsManager.format
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: BuxTokens.block) {
                if query.isEmpty {
                    suggestionsSection
                } else if results.isEmpty {
                    emptyResults
                } else {
                    resultsSection
                }
            }
            .padding(.horizontal, BuxTokens.marginRegular)
            .padding(.vertical, BuxTokens.section)
            .padding(.bottom, BuxTokens.sheetBottomClearance)
            .environment(\.studioEnhancedTint, true)
        }
        .background {
            if !usesPadSplitLayout {
                themeManager.screenBackground(for: colorScheme)
            }
        }
        .buxCatalogNavigationTitle(isProSearch ? "Pro Search" : "Search")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $query,
            prompt: Text(
                BuxCatalogLabel.string(
                    "Who owes me? Jobs for Maria…",
                    locale: appSettingsManager.interfaceLocale
                )
            )
        )
        .buxInterfaceLocale()
        .sheet(item: $detailDestination) { destination in
            switch destination {
            case .entry(let id):
                SimpleStudioEntryDetailView(store: store, entryId: id)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            case .invoice(let id):
                SimpleStudioInvoiceDetailView(store: store, invoiceId: id)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            case .person(let id):
                NavigationStack {
                    SimpleStudioPersonDetailView(store: store, customerId: id)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(studioStore)
                }
                .buxStudioSheetContent()
            }
        }
        .onAppear {
            if query.isEmpty, !initialQuery.isEmpty {
                query = initialQuery
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.section) {
            BuxCatalogDynamicText(key: "Try asking like this")
                .font(.system(size: 13, weight: .bold))
                .buxSectionLabelStyle(color: themeManager.labelSecondary(for: colorScheme))

            VStack(spacing: BuxTokens.tight) {
                ForEach(suggestionQueries, id: \.self) { suggestion in
                    Button {
                        query = suggestion
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isProSearch ? "sparkles" : "magnifyingglass")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            BuxCatalogDynamicText(key: suggestion)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, BuxTokens.section)
                        .padding(.vertical, 12)
                        .background(themeManager.cardFill(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BuxTokens.Radius.card, style: .continuous)
                                .stroke(themeManager.themedCardStroke(for: colorScheme), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            BuxCatalogDynamicText(
                key: isProSearch
                    ? "Pro Search understands plain questions — people, jobs, invoices, and who still owes you. Works offline."
                    : "Works offline — search people, jobs, invoices, and who still owes you."
            )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyResults: some View {
        VStack(spacing: BuxTokens.section) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
            BuxCatalogDynamicText(key: "No matches")
                .font(.system(size: 17, weight: .bold))
            BuxCatalogDynamicText(key: "Try a name, “waiting on payment”, or “jobs this month”.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, BuxTokens.block)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            Text(
                BuxLocalizedString.format(
                    results.count == 1 ? "%lld result" : "%lld results",
                    locale: appSettingsManager.interfaceLocale,
                    Int64(results.count)
                )
            )
                .font(.system(size: 12, weight: .bold))
                .buxLabelSecondary()

            BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        if index > 0 { Divider().padding(.leading, BuxTokens.section) }
                        resultRow(result)
                    }
                }
            }
        }
    }

    private func resultRow(_ result: SimpleStudioSearchEngine.Result) -> some View {
        Button {
            open(result)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(for: result.kind))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                    .frame(width: 28, height: 28)
                    .background(themeManager.accentWash(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                        .multilineTextAlignment(.leading)
                    Text(result.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    Text(result.localizedMatchReason(locale: appSettingsManager.interfaceLocale))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                }
                Spacer(minLength: 8)
                if let amount = result.amountFormatted {
                    Text(amount)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                }
            }
            .padding(.horizontal, BuxTokens.section)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func icon(for kind: SimpleStudioSearchEngine.ResultKind) -> String {
        switch kind {
        case .entry: return "banknote"
        case .invoice: return "doc.text"
        case .person: return "person.fill"
        }
    }

    private func open(_ result: SimpleStudioSearchEngine.Result) {
        switch result.kind {
        case .entry(let id):
            detailDestination = .entry(id)
        case .invoice(let id):
            detailDestination = .invoice(id)
        case .person(let id):
            detailDestination = .person(id)
        }
    }
}
