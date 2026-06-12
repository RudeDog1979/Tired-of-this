//
//  ProBrandSyncEngine.swift
//  BuxMuse
//
//  Writes primary business card branding into invoice default settings.
//

import Foundation

enum ProBrandSyncEngine {

    @discardableResult
    static func syncInvoiceDefaults(
        invoiceSettings: inout StudioInvoiceSettings,
        library: ProBusinessCardLibrary,
        logoPosition: InvoiceLogoPosition,
        force: Bool
    ) -> Bool {
        guard force || invoiceSettings.brandSyncFromPrimaryCard else { return false }
        guard let design = library.primaryBrandDesign else { return false }

        invoiceSettings.defaultTemplateConfig = ProBrandIdentityMapper.templateConfig(
            from: design,
            logoPosition: logoPosition
        )
        invoiceSettings.brandSyncSourceDesignID = design.id
        invoiceSettings.brandSyncSourceUpdatedAt = design.updatedAt
        if force {
            invoiceSettings.brandSyncFromPrimaryCard = true
        }
        return true
    }

    static func isStale(invoiceSettings: StudioInvoiceSettings, design: ProBusinessCardDesign) -> Bool {
        guard invoiceSettings.brandSyncSourceDesignID == design.id,
              let syncedAt = invoiceSettings.brandSyncSourceUpdatedAt else {
            return true
        }
        return design.updatedAt > syncedAt
    }
}
