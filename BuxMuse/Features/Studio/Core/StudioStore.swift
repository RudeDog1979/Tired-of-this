//
//  StudioStore.swift
//  BuxMuse
//
//  Offline JSON repository managing Freelance Hub state & safe auto-save.
//

import Foundation
import SwiftUI
import Combine

@MainActor
public final class StudioStore: ObservableObject {
    public static let shared = StudioStore()

    @Published public var profile: StudioProfile = StudioProfile()
    @Published public var clients: [StudioClient] = []
    @Published public var invoices: [StudioInvoice] = []
    @Published public var projects: [StudioProject] = []
    @Published public var receipts: [StudioReceipt] = []
    @Published public var taxProfile: StudioTaxProfile = StudioTaxProfile()
    @Published public var invoiceSettings: StudioInvoiceSettings = StudioInvoiceSettings()
    @Published public var mileageEntries: [MileageEntry] = []
    @Published public var businessCardLibrary: ProBusinessCardLibrary = ProBusinessCardLibrary()

    private let saveQueue = DispatchQueue(label: "com.buxmuse.freelance.save", qos: .utility)
    private var isLoaded = false

    private init() {
        loadStore()
    }

    private static let storeFileName = "studio_hub.json"
    private static let legacyStoreFileName = "studio_hub_v1.json"
    private static let preRenameStoreFileName = "freelance_hub.json"
    private static let preRenameLegacyStoreFileName = "freelance_hub_v1.json"

    private var appSupportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    private var storeDirectory: URL {
        let fm = FileManager.default
        let studioDir = appSupportURL.appendingPathComponent("Studio", isDirectory: true)
        if !fm.fileExists(atPath: studioDir.path) {
            try? fm.createDirectory(at: studioDir, withIntermediateDirectories: true, attributes: nil)
        }
        return studioDir
    }

    private var storeURL: URL {
        storeDirectory.appendingPathComponent(Self.storeFileName)
    }

    private var legacyStoreURL: URL {
        storeDirectory.appendingPathComponent(Self.legacyStoreFileName)
    }

    private var allLoadCandidateURLs: [URL] {
        let fm = FileManager.default
        let legacyHubDir = appSupportURL.appendingPathComponent("FreelanceHub", isDirectory: true)
        let candidates = [
            storeURL,
            legacyStoreURL,
            storeDirectory.appendingPathComponent(Self.preRenameStoreFileName),
            storeDirectory.appendingPathComponent(Self.preRenameLegacyStoreFileName),
            legacyHubDir.appendingPathComponent(Self.preRenameStoreFileName),
            legacyHubDir.appendingPathComponent(Self.preRenameLegacyStoreFileName),
            legacyHubDir.appendingPathComponent(Self.storeFileName)
        ]
        return candidates.filter { fm.fileExists(atPath: $0.path) }
    }

    // MARK: - Saving & Loading

    public func loadStore() {
        guard !isLoaded else { return }

        for url in allLoadCandidateURLs {
            do {
                let data = try Data(contentsOf: url)
                let snapshot = try JSONDecoder().decode(StudioSnapshot.self, from: data)
                apply(snapshot)
                isLoaded = true
                if url != storeURL {
                    save()
                }
                return
            } catch {
                print("StudioStore: decoding error at \(url.lastPathComponent): \(error)")
            }
        }

        applyEmptyDefaults()
        isLoaded = true
    }

    public func save() {
        let snapshot = currentSnapshot()
        do {
            let data = try JSONEncoder().encode(snapshot)
            let url = storeURL
            saveQueue.async {
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    print("StudioStore: failed to write JSON payload: \(error)")
                }
            }
        } catch {
            print("StudioStore: failed to encode JSON payload: \(error)")
        }
    }

    public func currentSnapshot() -> StudioSnapshot {
        StudioSnapshot(
            profile: profile,
            clients: clients,
            invoices: invoices,
            projects: projects,
            receipts: receipts,
            taxProfile: taxProfile,
            invoiceSettings: invoiceSettings,
            mileageEntries: mileageEntries,
            businessCardLibrary: businessCardLibrary
        )
    }

    public func apply(_ snapshot: StudioSnapshot) {
        profile = snapshot.profile
        clients = snapshot.clients
        invoices = StudioInvoiceMaintenance.syncOverdueStatuses(invoices: snapshot.invoices)
        projects = snapshot.projects
        receipts = snapshot.receipts
        taxProfile = snapshot.taxProfile
        invoiceSettings = snapshot.invoiceSettings
        mileageEntries = snapshot.mileageEntries
        businessCardLibrary = snapshot.businessCardLibrary
    }

    // MARK: - CRUD: Mileage

    public func addMileageEntry(_ entry: MileageEntry) {
        mileageEntries.append(entry)
        save()
    }

    public func updateMileageEntry(_ entry: MileageEntry) {
        guard let index = mileageEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        mileageEntries[index] = entry
        save()
    }

    public func deleteMileageEntry(id: UUID) {
        mileageEntries.removeAll { $0.id == id }
        save()
    }

    // MARK: - CRUD: Clients

    public func addClient(_ client: StudioClient) {
        clients.append(client)
        save()
    }

    public func updateClient(_ client: StudioClient) {
        guard let index = clients.firstIndex(where: { $0.id == client.id }) else { return }
        clients[index] = client
        save()
    }

    public func deleteClient(id: UUID) {
        clients.removeAll { $0.id == id }
        invoices.removeAll { $0.clientId == id }
        receipts = receipts.map { receipt in
            var copy = receipt
            if copy.linkedClientId == id { copy.linkedClientId = nil }
            return copy
        }
        save()
    }

    // MARK: - CRUD: Invoices

    public func addInvoice(_ invoice: StudioInvoice) {
        invoices.append(invoice)
        save()
    }

    public func updateInvoice(_ invoice: StudioInvoice) {
        guard let index = invoices.firstIndex(where: { $0.id == invoice.id }) else { return }
        invoices[index] = invoice
        save()
    }

    public func deleteInvoice(id: UUID) {
        invoices.removeAll { $0.id == id }
        save()
    }

    public func nextInvoiceNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let existing = Set(invoices.map(\.invoiceNumber))
        var seq = 1
        while seq < 100_000 {
            let candidate = invoiceSettings.formatInvoiceNumber(sequence: seq, year: year)
            if !existing.contains(candidate) {
                return candidate
            }
            seq += 1
        }
        return invoiceSettings.formatInvoiceNumber(sequence: seq, year: year)
    }

    // MARK: - CRUD: Projects

    public func addProject(_ project: StudioProject) {
        projects.append(project)
        save()
    }

    public func updateProject(_ project: StudioProject) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index] = project
        save()
    }

    public func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
        receipts = receipts.map { receipt in
            var copy = receipt
            if copy.linkedProjectId == id { copy.linkedProjectId = nil }
            return copy
        }
        save()
    }

    // MARK: - CRUD: Receipts

    public func addReceipt(_ receipt: StudioReceipt) {
        receipts.append(receipt)
        save()
    }

    public func updateReceipt(_ receipt: StudioReceipt) {
        guard let index = receipts.firstIndex(where: { $0.id == receipt.id }) else { return }
        receipts[index] = receipt
        save()
    }

    public func deleteReceipt(id: UUID) {
        receipts.removeAll { $0.id == id }
        save()
    }

    // MARK: - Profile & Tax

    public func updateProfile(_ updated: StudioProfile) {
        profile = updated
        save()
    }

    public func updateTaxProfile(_ updated: StudioTaxProfile) {
        taxProfile = updated
        save()
    }

    public func updateInvoiceSettings(_ updated: StudioInvoiceSettings) {
        invoiceSettings = updated
        save()
    }

    // MARK: - Business Card Studio

    public func ensureBusinessCardLibrary(simpleCard: SimpleBusinessCard?) {
        guard businessCardLibrary.designs.isEmpty else { return }

        var designs: [ProBusinessCardDesign] = []
        if let simpleCard, !simpleCard.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            designs.append(ProBusinessCardLibrary.importFromSimpleCard(simpleCard))
        }

        let starters = ProBusinessCardLibrary.starterDesigns(
            profileName: profile.displayName,
            businessName: profile.businessName,
            tagline: profile.businessType.rawValue,
            accentHex: profile.logoData == nil
                ? ProBusinessCardPalette.defaultPreset.accentHex
                : ProBusinessCardPalette.defaultPreset.accentHex
        )
        for starter in starters where !designs.contains(where: { $0.title == starter.title }) {
            designs.append(starter)
        }

        businessCardLibrary = ProBusinessCardLibrary(
            designs: designs,
            selectedDesignID: designs.first?.id
        )
        save()
    }

    @discardableResult
    public func addBusinessCardDesign(
        title: String,
        template: ProBusinessCardTemplate
    ) -> ProBusinessCardDesign {
        let base = businessCardLibrary.selectedDesign
        let businessName = profile.businessName.isEmpty ? profile.displayName : profile.businessName
        let content = base?.content ?? ProBusinessCardContent(
            name: businessName,
            tagline: profile.businessType.rawValue
        )
        var design = ProBusinessCardDesign(
            title: title,
            template: template,
            options: .businessDefault,
            style: ProBusinessCardStyle.businessDefault(businessName: businessName),
            content: content,
            isDraft: true
        )
        design.applyTemplateDefaults()
        businessCardLibrary.designs.append(design)
        businessCardLibrary.selectedDesignID = design.id
        save()
        return design
    }

    public func updateBusinessCardDesign(_ design: ProBusinessCardDesign) {
        guard let index = businessCardLibrary.designs.firstIndex(where: { $0.id == design.id }) else { return }
        businessCardLibrary.designs[index] = design
        businessCardLibrary.selectedDesignID = design.id
        save()
    }

    public func duplicateBusinessCardDesign(id: UUID) {
        guard let source = businessCardLibrary.designs.first(where: { $0.id == id }) else { return }
        var copy = source
        copy.id = UUID()
        copy.title = "\(source.title) copy"
        copy.updatedAt = Date()
        businessCardLibrary.designs.append(copy)
        save()
    }

    public func deleteBusinessCardDesign(id: UUID) {
        deleteBusinessCardDesigns(ids: [id])
    }

    public func deleteBusinessCardDesigns<S: Sequence>(ids: S) where S.Element == UUID {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }
        businessCardLibrary.designs.removeAll { idSet.contains($0.id) }
        if let selectedID = businessCardLibrary.selectedDesignID, idSet.contains(selectedID) {
            businessCardLibrary.selectedDesignID = businessCardLibrary.savedDesigns.first?.id
        }
        if let primaryID = businessCardLibrary.primaryBrandDesignID, idSet.contains(primaryID) {
            businessCardLibrary.primaryBrandDesignID = businessCardLibrary.savedDesigns.first?.id
            syncInvoiceBrandFromPrimaryCard(force: false)
        }
        save()
    }

    public func setPrimaryBrandDesign(id: UUID) {
        guard businessCardLibrary.savedDesigns.contains(where: { $0.id == id }) else { return }
        businessCardLibrary.primaryBrandDesignID = id
        syncInvoiceBrandFromPrimaryCard(force: false)
        save()
    }

    public func syncInvoiceBrandFromPrimaryCard(force: Bool = true) {
        _ = ProBrandSyncEngine.syncInvoiceDefaults(
            invoiceSettings: &invoiceSettings,
            library: businessCardLibrary,
            logoPosition: invoiceSettings.logoPosition,
            force: force
        )
        save()
    }

    public func unlinkInvoiceBrandFromCard() {
        guard invoiceSettings.brandSyncFromPrimaryCard else { return }
        invoiceSettings.brandSyncFromPrimaryCard = false
        save()
    }

    /// Removes abandoned editor sessions that were never saved to Your designs.
    public func purgeEphemeralBusinessCardDesigns() {
        let before = businessCardLibrary.designs.count
        businessCardLibrary.designs.removeAll { $0.isDraft }
        guard businessCardLibrary.designs.count != before else { return }
        if let selectedID = businessCardLibrary.selectedDesignID,
           !businessCardLibrary.designs.contains(where: { $0.id == selectedID }) {
            businessCardLibrary.selectedDesignID = businessCardLibrary.savedDesigns.first?.id
        }
        save()
    }

    public func syncOverdueInvoicesIfNeeded() {
        let synced = StudioInvoiceMaintenance.syncOverdueStatuses(invoices: invoices)
        if synced != invoices {
            invoices = synced
            save()
        }
    }

    // MARK: - Empty defaults

    private func applyEmptyDefaults() {
        profile = StudioProfile(
            displayName: "",
            businessName: "",
            countryCode: "US",
            currencyCode: "USD",
            businessType: .freelancer,
            vatRegistered: false,
            defaultInvoicePaymentTerms: 30,
            defaultHourlyRate: nil
        )
        clients = []
        projects = []
        invoices = []
        receipts = []
        taxProfile = StudioTaxProfile(
            countryCode: "US",
            businessType: .freelancer,
            vatRegistered: false,
            incomeTaxRules: [],
            vatRules: [],
            deductionCategories: [],
            paymentSchedule: "annually"
        )
        invoiceSettings = StudioInvoiceSettings()
        businessCardLibrary = ProBusinessCardLibrary()
    }

    public func resetAllData() {
        applyEmptyDefaults()
        save()
    }
}
