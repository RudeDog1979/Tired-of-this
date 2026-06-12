//
//  ProBusinessCardModelsTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class ProBusinessCardModelsTests: XCTestCase {

    func testLaunchTemplateCount() {
        XCTAssertEqual(ProBusinessCardTemplate.launchTemplates.count, 23)
    }

    func testStarterDesignsUseLogoFirstBusinessDefaults() {
        let designs = ProBusinessCardLibrary.starterDesigns(
            profileName: "Alex",
            businessName: "Alex Plumbing",
            tagline: "Repairs & installs"
        )
        XCTAssertEqual(designs.count, 3)
        XCTAssertTrue(designs.allSatisfy { $0.options.showsLogo })
        XCTAssertTrue(designs.allSatisfy { !$0.options.showsPhoto })
        XCTAssertTrue(designs.allSatisfy { $0.canvasDocument != nil })
    }

    func testImportFromSimpleCardPreservesContent() {
        let simple = SimpleBusinessCard(
            name: "Sam",
            tagline: "Electrician",
            phone: "+1 555 0100",
            email: "sam@example.com",
            skills: "Rewiring",
            photoPath: "scans/test.jpg"
        )
        let design = ProBusinessCardLibrary.importFromSimpleCard(simple)
        XCTAssertEqual(design.content.name, "Sam")
        XCTAssertEqual(design.template.renderTemplate, .logoMark)
        XCTAssertEqual(design.style.photoScale, .corner)
    }

    func testWatermarkLayerDefaults() {
        let style = ProBusinessCardStyle.businessDefault(businessName: "Acme Co")
        XCTAssertFalse(style.watermark.isEnabled)
        XCTAssertEqual(style.watermark.text, "Acme Co")
    }

    func testIdentityModeBusinessKeepsPhotoOff() {
        var style = ProBusinessCardStyle()
        style.applyIdentityMode(.business)
        XCTAssertEqual(style.logoScale, .hero)
        XCTAssertEqual(style.photoScale, .off)
    }

    func testAspectPrintSizes() {
        XCTAssertEqual(ProBusinessCardAspect.standardUS.printSize.width, 252, accuracy: 0.1)
        XCTAssertEqual(ProBusinessCardAspect.a8.printSize.height, 147, accuracy: 0.1)
        XCTAssertEqual(ProBusinessCardAspect.squareSocial.printSize.width, 360, accuracy: 0.1)
    }

    func testLegacyPhotoForwardMapsToLogoMark() {
        XCTAssertEqual(ProBusinessCardTemplate.photoForward.renderTemplate, .logoMark)
    }

    func testClearBackgroundPhotoResetsStyle() {
        var style = ProBusinessCardStyle(
            backgroundStyle: .photo,
            backgroundPhotoPath: "scans/bg.jpg",
            backgroundPhotoOpacity: 0.8
        )
        style.clearBackgroundPhoto()
        XCTAssertNil(style.backgroundPhotoPath)
        XCTAssertEqual(style.backgroundStyle, .solid)
        XCTAssertEqual(style.backgroundPhotoOpacity, 1.0)
    }
}
