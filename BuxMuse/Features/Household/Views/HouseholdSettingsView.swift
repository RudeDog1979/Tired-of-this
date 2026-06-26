//
//  HouseholdSettingsView.swift
//  BuxMuse
//  Features/Household/Views/
//
//  Create/join household, invite members, sync status, shared envelope profile.
//

import SwiftUI
import CloudKit

struct HouseholdSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var brain: BuxMuseBrain
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var syncEngine = HouseholdSyncEngine.shared

    @State private var householdNameDraft = ""
    @State private var actionError: String?
    @State private var isWorking = false

    private var accent: Color {
        themeManager.contrastAccentColor(for: colorScheme)
    }

    private var locale: Locale { appSettingsManager.interfaceLocale }

    var body: some View {
        BuxThemedCardForm {
            statusSection

            if syncEngine.isHouseholdActive {
                activeHouseholdSection
            } else {
                createHouseholdSection
            }
        }
        .buxCatalogNavigationTitle("Household")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            syncEngine.attach(brain: brain)
            _ = await syncEngine.checkAccountStatus()
            if householdNameDraft.isEmpty {
                householdNameDraft = store.householdDisplayName ?? store.resolvedDisplayName + "'s Household"
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        BuxFormSection(title: "iCloud sync") {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.system(size: 15, weight: .semibold))
                    Text(statusSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if syncEngine.isHouseholdActive {
                    Button {
                        Task { await syncEngine.syncNow() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isWorking)
                }
            }
            .buxFormFieldPadding()

            if let actionError {
                BuxFormRowDivider()
                Text(actionError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                    .buxFormFieldPadding()
            }
        }
    }

    @ViewBuilder
    private var createHouseholdSection: some View {
        BuxFormSection(title: "Start a household") {
            TextField(
                BuxCatalogLabel.string("Household name", locale: locale),
                text: $householdNameDraft
            )
            .buxFormFieldPadding()

            BuxFormRowDivider()

            BuxButton(
                title: "Create household",
                systemImage: "person.2.fill",
                role: .primary,
                expands: true
            ) {
                Task { await createHousehold() }
            }
            .disabled(isWorking || householdNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buxFormFieldPadding()
        }

        BuxFormSection {
            BuxCatalogDynamicText(key: "Shared expenses sync through Apple's iCloud. BuxMuse cannot read this data. Only people you invite can see it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .buxFormFieldPadding()
        }
    }

    @ViewBuilder
    private var activeHouseholdSection: some View {
        BuxFormSection(title: "Your household") {
            HStack {
                BuxCatalogText.text("Name")
                Spacer()
                Text(
                    store.householdDisplayName
                        ?? BuxCatalogLabel.string("Household", locale: appSettingsManager.interfaceLocale)
                )
                    .foregroundStyle(.secondary)
            }
            .buxFormFieldPadding()

            if let url = syncEngine.inviteShareURL {
                BuxFormRowDivider()
                ShareLink(item: url) {
                    HStack {
                        BuxCatalogText.text("Invite member")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .buxFormFieldPadding()
            }

            BuxFormRowDivider()
            BuxButton(
                title: "Leave household",
                systemImage: "rectangle.portrait.and.arrow.right",
                role: .destructive,
                expands: true
            ) {
                Task {
                    isWorking = true
                    await syncEngine.leaveHousehold()
                    isWorking = false
                }
            }
            .buxFormFieldPadding()
        }

        if !store.customBudgetProfiles.isEmpty {
            BuxFormSection(title: "Shared envelope profile") {
                Picker(
                    BuxCatalogLabel.string("Envelope profile", locale: locale),
                    selection: Binding(
                        get: { store.sharedEnvelopeProfileId },
                        set: { newValue in
                            store.sharedEnvelopeProfileId = newValue
                            store.save()
                            Task { await syncEngine.pushSharedEnvelopeProfile() }
                        }
                    )
                ) {
                    BuxCatalogText.text("None").tag(Optional<UUID>.none)
                    ForEach(store.customBudgetProfiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                .buxFormFieldPadding()

                BuxCatalogDynamicText(key: "Pick which envelope budget profile syncs with your household.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .buxFormFieldPadding()
            }
        }
    }

    private var statusIcon: String {
        switch syncEngine.syncStatus {
        case .syncing: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.icloud"
        case .noAccount: return "icloud.slash"
        case .notConfigured: return "icloud"
        case .idle, .lastSynced: return "checkmark.icloud"
        }
    }

    private var statusTitle: String {
        switch syncEngine.syncStatus {
        case .notConfigured:
            return BuxCatalogLabel.string("Not set up", locale: locale)
        case .noAccount:
            return BuxCatalogLabel.string("Sign in to iCloud", locale: locale)
        case .idle:
            return BuxCatalogLabel.string("Ready", locale: locale)
        case .syncing:
            return BuxCatalogLabel.string("Syncing…", locale: locale)
        case .lastSynced(let date):
            return BuxCatalogLabel.string("Synced", locale: locale) + " · " + BuxDisplayDate.dateAndTime(from: date, locale: locale)
        case .error:
            return BuxCatalogLabel.string("Sync issue", locale: locale)
        }
    }

    private var statusSubtitle: String {
        switch syncEngine.syncStatus {
        case .notConfigured:
            return BuxCatalogLabel.string("Create a household to share expenses.", locale: locale)
        case .noAccount:
            return BuxCatalogLabel.string("Enable iCloud in Settings to use household sync.", locale: locale)
        case .idle, .lastSynced:
            return BuxCatalogLabel.string("Shared expenses update automatically.", locale: locale)
        case .syncing:
            return BuxCatalogLabel.string("Pushing and pulling household changes.", locale: locale)
        case .error(let message):
            return message
        }
    }

    private func createHousehold() async {
        isWorking = true
        actionError = nil
        defer { isWorking = false }
        do {
            _ = try await syncEngine.createHousehold(displayName: householdNameDraft)
        } catch {
            actionError = error.localizedDescription
        }
    }
}
