//
//  ProBrandIdentityMapperTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class ProBrandIdentityMapperTests: XCTestCase {

    func testBoldTradeMapsToModernTemplate() {
        var design = ProBusinessCardDesign(title: "T", template: .boldTrade)
        design.applyTemplateDefaults()
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.style, .modern)
        XCTAssertEqual(config.primaryColorHex.uppercased(), design.palette.accentHex.uppercased())
        XCTAssertEqual(config.backgroundColorHex.uppercased(), design.palette.backgroundHex.uppercased())
        XCTAssertEqual(config.headerMotif, .topGradientBand)
    }

    func testMinimalMonoMapsToMinimalist() {
        var design = ProBusinessCardDesign(title: "T", template: .minimalMono)
        design.applyTemplateDefaults()
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.style, .minimalist)
        XCTAssertEqual(config.density, .compact)
    }

    func testClassicMapsToExecutive() {
        var design = ProBusinessCardDesign(title: "T", template: .classic)
        design.applyTemplateDefaults()
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.style, .executive)
        XCTAssertEqual(config.headerMotif, .sideAccentBar)
        XCTAssertEqual(config.sourceCardTemplate, ProBusinessCardTemplate.classic.rawValue)
    }

    func testClassicFontPairingMapsToSerif() {
        var design = ProBusinessCardDesign(title: "T", template: .classic)
        design.applyTemplateDefaults()
        design.style.typography.fontID = ProBusinessCardFontID.classicSerif.rawValue
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.typography, .systemSerif)
    }

    func testBoldFontPairingMapsToSans() {
        var design = ProBusinessCardDesign(title: "T", template: .boldTrade)
        design.applyTemplateDefaults()
        design.style.typography.fontID = ProBusinessCardFontID.boldHeavy.rawValue
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.typography, .systemSans)
    }

    func testBusinessCardLibraryDecodesWithoutPrimaryBrandID() throws {
        let json = #"{"designs":[],"selectedDesignID":null}"#
        let library = try JSONDecoder().decode(ProBusinessCardLibrary.self, from: Data(json.utf8))
        XCTAssertNil(library.primaryBrandDesignID)
        XCTAssertNil(library.primaryBrandDesign)
    }

    func testPrimaryBrandDesignFallsBackToFirstSaved() {
        var main = ProBusinessCardDesign(title: "Main", template: .classic)
        main.applyTemplateDefaults()
        var other = ProBusinessCardDesign(title: "Other", template: .minimalMono)
        other.applyTemplateDefaults()
        let library = ProBusinessCardLibrary(designs: [main, other])
        XCTAssertEqual(library.primaryBrandDesign?.id, main.id)
    }

    func testDiagonalBandsMapsMotif() {
        var design = ProBusinessCardDesign(title: "T", template: .diagonalBands)
        design.applyTemplateDefaults()
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.headerMotif, .diagonalBands)
        XCTAssertEqual(config.secondaryColorHex.uppercased(), design.palette.foregroundHex.uppercased())
    }

    func testGradientBackgroundStyleMapsFromCard() {
        var design = ProBusinessCardDesign(title: "T", template: .gradientPro)
        design.applyTemplateDefaults()
        design.style.backgroundStyle = .gradient
        let config = ProBrandIdentityMapper.templateConfig(from: design, logoPosition: .topLeft)
        XCTAssertEqual(config.backgroundStyle, .gradient)
    }

    func testSyncWritesDefaultTemplateConfigWhenEnabled() {
        var settings = StudioInvoiceSettings()
        settings.brandSyncFromPrimaryCard = true
        var design = ProBusinessCardDesign(title: "Main", template: .classic)
        design.applyTemplateDefaults()
        let library = ProBusinessCardLibrary(
            designs: [design],
            selectedDesignID: design.id,
            primaryBrandDesignID: design.id
        )

        let changed = ProBrandSyncEngine.syncInvoiceDefaults(
            invoiceSettings: &settings,
            library: library,
            logoPosition: .topLeft,
            force: false
        )
        XCTAssertTrue(changed)
        XCTAssertEqual(settings.brandSyncSourceDesignID, design.id)
        XCTAssertNotNil(settings.defaultTemplateConfig)
        XCTAssertEqual(settings.defaultTemplateConfig?.style, .executive)
    }

    func testSyncSkippedWhenUnlinked() {
        var settings = StudioInvoiceSettings()
        settings.brandSyncFromPrimaryCard = false
        var design = ProBusinessCardDesign(title: "Main", template: .classic)
        design.applyTemplateDefaults()
        let library = ProBusinessCardLibrary(
            designs: [design],
            primaryBrandDesignID: design.id
        )

        let changed = ProBrandSyncEngine.syncInvoiceDefaults(
            invoiceSettings: &settings,
            library: library,
            logoPosition: .topLeft,
            force: false
        )
        XCTAssertFalse(changed)
    }

    func testSyncForceReEnablesBrandLink() {
        var settings = StudioInvoiceSettings()
        settings.brandSyncFromPrimaryCard = false
        var design = ProBusinessCardDesign(title: "Main", template: .classic)
        design.applyTemplateDefaults()
        let library = ProBusinessCardLibrary(
            designs: [design],
            primaryBrandDesignID: design.id
        )

        let changed = ProBrandSyncEngine.syncInvoiceDefaults(
            invoiceSettings: &settings,
            library: library,
            logoPosition: .topLeft,
            force: true
        )
        XCTAssertTrue(changed)
        XCTAssertTrue(settings.brandSyncFromPrimaryCard)
    }

    func testStaleDetectionWhenCardUpdatedAfterSync() {
        var settings = StudioInvoiceSettings()
        var design = ProBusinessCardDesign(title: "Main", template: .classic)
        design.applyTemplateDefaults()
        settings.brandSyncSourceDesignID = design.id
        settings.brandSyncSourceUpdatedAt = design.updatedAt

        XCTAssertFalse(ProBrandSyncEngine.isStale(invoiceSettings: settings, design: design))

        design.updatedAt = Date().addingTimeInterval(60)
        XCTAssertTrue(ProBrandSyncEngine.isStale(invoiceSettings: settings, design: design))
    }
}
