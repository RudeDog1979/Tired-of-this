//
//  SimpleStudioPeopleView.swift
//  BuxMuse
//

import SwiftUI

struct SimpleStudioPeopleView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager

    @ObservedObject var store: SimpleStudioStore

    @State private var nameFilter = ""

    private var filteredCustomers: [SimpleCustomerMemory] {
        let sorted = store.customers.sorted { $0.lastSeen > $1.lastSeen }
        let trimmed = nameFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || ($0.phone?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || ($0.lastJobLabel?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        List {
            if store.customers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    BuxCatalogDynamicText(key: "No people yet")
                        .font(.system(size: 16, weight: .bold))
                    BuxCatalogDynamicText(key: "They appear automatically when you log jobs or send invoices.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BuxTokens.block)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if filteredCustomers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    BuxCatalogDynamicText(key: "No people match")
                        .font(.system(size: 16, weight: .bold))
                    BuxCatalogDynamicText(key: "Try another name or phone number.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BuxTokens.block)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredCustomers) { person in
                    NavigationLink {
                        SimpleStudioPersonDetailView(store: store, customerId: person.id)
                            .environmentObject(themeManager)
                            .environmentObject(appSettingsManager)
                            .environmentObject(StudioStore.shared)
                    } label: {
                        personRow(person)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.screenBackground(for: colorScheme))
        .buxCatalogNavigationTitle("People")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $nameFilter, prompt: "Find by name or phone")
    }

    private func personRow(_ person: SimpleCustomerMemory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(person.name)
                    .font(.system(size: 16, weight: .bold))
                Spacer(minLength: 0)
                if person.phone != nil {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if let job = person.lastJobLabel {
                Text(
                    BuxLocalizedString.format(
                        "Last: %@",
                        locale: appSettingsManager.interfaceLocale,
                        job
                    )
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            HStack {
                if person.outstandingBalance > 0 {
                    Text(
                        BuxLocalizedString.format(
                            "Waiting: %@",
                            locale: appSettingsManager.interfaceLocale,
                            appSettingsManager.format(person.outstandingBalance)
                        )
                    )
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.orange)
                }
                if person.totalEarned > 0 {
                    Text(
                        BuxLocalizedString.format(
                            "Total: %@",
                            locale: appSettingsManager.interfaceLocale,
                            appSettingsManager.format(person.totalEarned)
                        )
                    )
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
