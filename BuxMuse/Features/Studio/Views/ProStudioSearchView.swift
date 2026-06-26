//
//  ProStudioSearchView.swift
//  BuxMuse
//
//  Pro Studio — rich offline search across clients, invoices, projects, receipts, and ledger.
//

import SwiftUI

struct ProStudioSearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var studioStore: StudioStore
    @EnvironmentObject private var simpleStudioStore: SimpleStudioStore
    @EnvironmentObject private var studioBrain: StudioBrain

    @State private var query = ""
    @State private var simpleDetail: SimpleStudioDetailDestination?
    @State private var clientRouteID: UUID?
    @State private var projectRouteID: UUID?
    @State private var receiptRouteID: UUID?
    @State private var invoiceToEdit: StudioInvoice?
    @State private var mileageRouteID: UUID?

    private var results: [ProStudioSearchEngine.Result] {
        ProStudioSearchEngine.search(
            query: query,
            studio: studioStore.currentSnapshot(),
            simple: simpleStudioStore.snapshot,
            format: appSettingsManager.format,
            locale: appSettingsManager.interfaceLocale
        )
    }

    private var groupedResults: [(section: ProStudioSearchEngine.Section, items: [ProStudioSearchEngine.Result])] {
        ProStudioSearchEngine.groupedResults(results)
    }

    var body: some View {
        StudioThemedListBackdrop {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: BuxTokens.block) {
                    StudioProToolScreenHeader(titleKey: "Pro Search")
                        .studioProToolScrollPlacement()

                    Group {
                        heroCard

                        if query.isEmpty {
                            quickFiltersSection
                            suggestionsSection
                        } else if results.isEmpty {
                            emptyResults
                        } else {
                            resultsSection
                        }
                    }
                    .buxPadStudioSectionInset()
                }
                .padding(.bottom, BuxTokens.sheetBottomClearance)
            }
            .studioProToolScrollTopInset()
            .buxSoftScrollChrome()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .buxRootNavigationChrome()
        .searchable(
            text: $query,
            prompt: Text(
                BuxCatalogLabel.string(
                    "Overdue invoices, clients, receipts…",
                    locale: appSettingsManager.interfaceLocale
                )
            )
        )
        .buxInterfaceLocale()
        .navigationDestination(item: $clientRouteID) { clientID in
            if let client = studioStore.clients.first(where: { $0.id == clientID }) {
                StudioClientDetailView(client: client)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            }
        }
        .navigationDestination(item: $projectRouteID) { projectID in
            if let project = studioStore.projects.first(where: { $0.id == projectID }) {
                StudioProjectDetailView(projectId: project.id)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
                    .environmentObject(simpleStudioStore)
            }
        }
        .navigationDestination(item: $receiptRouteID) { receiptID in
            if let receipt = studioStore.receipts.first(where: { $0.id == receiptID }) {
                StudioReceiptDetailView(receipt: receipt)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            }
        }
        .navigationDestination(item: $mileageRouteID) { entryID in
            StudioMileageLogView(highlightEntryID: entryID)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(studioStore)
                .environmentObject(studioBrain)
        }
        .fullScreenCover(item: $invoiceToEdit) { invoice in
            StudioInvoiceEditorView(invoiceToEdit: invoice)
                .environmentObject(themeManager)
                .environmentObject(appSettingsManager)
                .environmentObject(studioStore)
        }
        .sheet(item: $simpleDetail) { destination in
            switch destination {
            case .entry(let id):
                SimpleStudioEntryDetailView(store: simpleStudioStore, entryId: id)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            case .invoice(let id):
                SimpleStudioInvoiceDetailView(store: simpleStudioStore, invoiceId: id)
                    .environmentObject(themeManager)
                    .environmentObject(appSettingsManager)
                    .environmentObject(studioStore)
            case .person(let id):
                NavigationStack {
                    SimpleStudioPersonDetailView(store: simpleStudioStore, customerId: id)
                        .environmentObject(themeManager)
                        .environmentObject(appSettingsManager)
                        .environmentObject(studioStore)
                }
                .buxStudioSheetContent()
            }
        }
    }

    private var heroCard: some View {
        BuxCard(elevation: .hero, cornerRadius: BuxTokens.Radius.hero, padding: BuxTokens.section) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.current.accentColor, themeManager.current.accentColor.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 6) {
                    BuxCatalogDynamicText(key: "Ask your studio anything")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    BuxCatalogDynamicText(key: "Clients, invoices, projects, receipts, mileage, tax deductions, and your Simple ledger — all offline.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.tight) {
            BuxCatalogDynamicText(key: "Quick filters")
                .font(.system(size: 13, weight: .bold))
                .buxSectionLabelStyle(color: themeManager.labelSecondary(for: colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BuxTokens.tight) {
                    ForEach(ProStudioSearchEngine.quickFilters) { filter in
                        Button {
                            query = filter.query
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 11, weight: .bold))
                                BuxCatalogText.text(filter.label)
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(themeManager.accentWash(for: colorScheme))
                            .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.section) {
            BuxCatalogDynamicText(key: "Try asking like this")
                .font(.system(size: 13, weight: .bold))
                .buxSectionLabelStyle(color: themeManager.labelSecondary(for: colorScheme))

            VStack(spacing: BuxTokens.tight) {
                ForEach(ProStudioSearchEngine.suggestionQueries, id: \.self) { suggestion in
                    suggestionRow(suggestion)
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: String) -> some View {
        Button {
            query = suggestion
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(themeManager.contrastAccentColor(for: colorScheme))
                Text(suggestion)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.labelPrimary(for: colorScheme))
                    .multilineTextAlignment(.leading)
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

    private var emptyResults: some View {
        VStack(spacing: BuxTokens.section) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            BuxCatalogDynamicText(key: "No matches")
                .font(.system(size: 17, weight: .bold))
            BuxCatalogDynamicText(key: "Try “overdue invoices”, a client name, or “receipts this week”.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, BuxTokens.block)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: BuxTokens.block) {
            Text(
                BuxLocalizedString.format(
                    results.count == 1 ? "%lld result" : "%lld results",
                    locale: appSettingsManager.interfaceLocale,
                    Int64(results.count)
                )
            )
                .font(.system(size: 12, weight: .bold))
                .buxLabelSecondary()

            ForEach(groupedResults, id: \.section) { group in
                VStack(alignment: .leading, spacing: BuxTokens.tight) {
                    BuxSectionHeader(title: group.section.catalogLabel(locale: appSettingsManager.interfaceLocale))

                    BuxCard(elevation: .card, cornerRadius: BuxTokens.Radius.card, padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, result in
                                if index > 0 { Divider().padding(.leading, BuxTokens.section) }
                                resultRow(result)
                            }
                        }
                    }
                }
            }
        }
    }

    private func resultRow(_ result: ProStudioSearchEngine.Result) -> some View {
        Button {
            open(result)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(for: result))
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
                    if !result.subtitle.isEmpty {
                        Text(
                            BuxCatalogLabel.string(
                                result.subtitle,
                                locale: appSettingsManager.interfaceLocale
                            )
                        )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Text(
                        BuxCatalogLabel.string(
                            result.matchReason,
                            locale: appSettingsManager.interfaceLocale
                        )
                    )
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

    private func icon(for result: ProStudioSearchEngine.Result) -> String {
        switch result.kind {
        case .client: return "person.2.fill"
        case .invoice: return "doc.text.fill"
        case .project: return "folder.fill"
        case .receipt: return "receipt.fill"
        case .mileage: return "car.fill"
        case .timeEntry: return "clock.fill"
        case .ledgerEntry: return "banknote.fill"
        case .ledgerInvoice: return "doc.plaintext.fill"
        case .ledgerPerson: return "person.fill"
        }
    }

    private func open(_ result: ProStudioSearchEngine.Result) {
        switch result.kind {
        case .client(let id):
            clientRouteID = id
        case .invoice(let id):
            invoiceToEdit = studioStore.invoices.first { $0.id == id }
        case .project(let id):
            projectRouteID = id
        case .receipt(let id):
            receiptRouteID = id
        case .timeEntry(let projectId, _):
            projectRouteID = projectId
        case .mileage(let id):
            mileageRouteID = id
        case .ledgerEntry(let id):
            simpleDetail = .entry(id)
        case .ledgerInvoice(let id):
            simpleDetail = .invoice(id)
        case .ledgerPerson(let id):
            simpleDetail = .person(id)
        }
    }
}
