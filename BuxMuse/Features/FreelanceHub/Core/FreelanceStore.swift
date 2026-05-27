//
//  FreelanceStore.swift
//  BuxMuse
//
//  Offline JSON repository managing Freelance Hub state & safe auto-save.
//

import Foundation
import SwiftUI
import Combine

@MainActor
public final class FreelanceStore: ObservableObject {
    public static let shared = FreelanceStore()

    @Published public var profile: FreelanceProfile = FreelanceProfile()
    @Published public var clients: [FreelanceClient] = []
    @Published public var invoices: [FreelanceInvoice] = []
    @Published public var projects: [FreelanceProject] = []
    @Published public var receipts: [FreelanceReceipt] = []
    @Published public var taxProfile: FreelanceTaxProfile = FreelanceTaxProfile()
    @Published public var invoiceSettings: FreelanceInvoiceSettings = FreelanceInvoiceSettings()

    private let saveQueue = DispatchQueue(label: "com.buxmuse.freelance.save", qos: .utility)
    private var isLoaded = false

    private init() {
        loadStore()
    }

    private static let storeFileName = "freelance_hub.json"
    private static let legacyStoreFileName = "freelance_hub_v1.json"

    private var storeDirectory: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let freelanceDir = appSupport.appendingPathComponent("FreelanceHub", isDirectory: true)
        if !fm.fileExists(atPath: freelanceDir.path) {
            try? fm.createDirectory(at: freelanceDir, withIntermediateDirectories: true, attributes: nil)
        }
        return freelanceDir
    }

    private var storeURL: URL {
        storeDirectory.appendingPathComponent(Self.storeFileName)
    }

    private var legacyStoreURL: URL {
        storeDirectory.appendingPathComponent(Self.legacyStoreFileName)
    }

    // MARK: - Saving & Loading

    public func loadStore() {
        guard !isLoaded else { return }

        let candidates = [storeURL, legacyStoreURL]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let snapshot = try JSONDecoder().decode(FreelanceSnapshot.self, from: data)
                apply(snapshot)
                isLoaded = true
                if url == legacyStoreURL {
                    save()
                }
                return
            } catch {
                print("FreelanceStore: decoding error at \(url.lastPathComponent): \(error)")
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
                    print("FreelanceStore: failed to write JSON payload: \(error)")
                }
            }
        } catch {
            print("FreelanceStore: failed to encode JSON payload: \(error)")
        }
    }

    public func currentSnapshot() -> FreelanceSnapshot {
        FreelanceSnapshot(
            profile: profile,
            clients: clients,
            invoices: invoices,
            projects: projects,
            receipts: receipts,
            taxProfile: taxProfile,
            invoiceSettings: invoiceSettings
        )
    }

    public func apply(_ snapshot: FreelanceSnapshot) {
        profile = snapshot.profile
        clients = snapshot.clients
        invoices = FreelanceInvoiceMaintenance.syncOverdueStatuses(invoices: snapshot.invoices)
        projects = snapshot.projects
        receipts = snapshot.receipts
        taxProfile = snapshot.taxProfile
        invoiceSettings = snapshot.invoiceSettings
    }

    // MARK: - CRUD: Clients

    public func addClient(_ client: FreelanceClient) {
        clients.append(client)
        save()
    }

    public func updateClient(_ client: FreelanceClient) {
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

    public func addInvoice(_ invoice: FreelanceInvoice) {
        invoices.append(invoice)
        save()
    }

    public func updateInvoice(_ invoice: FreelanceInvoice) {
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
        let prefix = "\(invoiceSettings.numberPrefix)-\(year)-"
        let existing = invoices
            .map(\.invoiceNumber)
            .filter { $0.hasPrefix(prefix) }
            .compactMap { Int($0.replacingOccurrences(of: prefix, with: "")) }
        let next = (existing.max() ?? 0) + 1
        return invoiceSettings.formatInvoiceNumber(sequence: next, year: year)
    }

    // MARK: - CRUD: Projects

    public func addProject(_ project: FreelanceProject) {
        projects.append(project)
        save()
    }

    public func updateProject(_ project: FreelanceProject) {
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

    public func addReceipt(_ receipt: FreelanceReceipt) {
        receipts.append(receipt)
        save()
    }

    public func updateReceipt(_ receipt: FreelanceReceipt) {
        guard let index = receipts.firstIndex(where: { $0.id == receipt.id }) else { return }
        receipts[index] = receipt
        save()
    }

    public func deleteReceipt(id: UUID) {
        receipts.removeAll { $0.id == id }
        save()
    }

    // MARK: - Profile & Tax

    public func updateProfile(_ updated: FreelanceProfile) {
        profile = updated
        save()
    }

    public func updateTaxProfile(_ updated: FreelanceTaxProfile) {
        taxProfile = updated
        save()
    }

    public func updateInvoiceSettings(_ updated: FreelanceInvoiceSettings) {
        invoiceSettings = updated
        save()
    }

    public func syncOverdueInvoicesIfNeeded() {
        let synced = FreelanceInvoiceMaintenance.syncOverdueStatuses(invoices: invoices)
        if synced != invoices {
            invoices = synced
            save()
        }
    }

    // MARK: - Empty defaults

    private func applyEmptyDefaults() {
        profile = FreelanceProfile(
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
        taxProfile = FreelanceTaxProfile(
            countryCode: "US",
            businessType: .freelancer,
            vatRegistered: false,
            incomeTaxRules: [],
            vatRules: [],
            deductionCategories: [],
            paymentSchedule: "annually"
        )
        invoiceSettings = FreelanceInvoiceSettings()
    }

    public func resetAllData() {
        applyEmptyDefaults()
        save()
    }
}
