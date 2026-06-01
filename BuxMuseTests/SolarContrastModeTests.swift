//
//  SolarContrastModeTests.swift
//  BuxMuseTests
//

import XCTest
import SwiftUI
@testable import BuxMuse

@MainActor
final class SolarContrastModeTests: XCTestCase {
    var settings: SettingsStore!

    override func setUp() {
        super.setUp()
        settings = SettingsStore.shared
        settings.resetAllData()
    }

    override func tearDown() {
        settings.resetAllData()
        settings = nil
        super.setUp()
    }

    func testSolarContrastModeColors() {
        // Given Solar Contrast Mode is disabled
        settings.solarContrastModeEnabled = false
        
        let standardScheme = BuxMaterialScheme.generate(
            theme: .buxDefault,
            colorScheme: .light,
            branded: true
        )
        
        // Background should NOT be pure white in standard branded mode
        XCTAssertNotEqual(standardScheme.surface, Color.white)
        XCTAssertNotEqual(standardScheme.outlineVariant, Color.black)

        // When Solar Contrast Mode is enabled
        settings.solarContrastModeEnabled = true
        
        let solarScheme = BuxMaterialScheme.generate(
            theme: .buxDefault,
            colorScheme: .light,
            branded: true
        )
        
        // Then background MUST be pure white
        XCTAssertEqual(solarScheme.surface, Color.white)
        XCTAssertEqual(solarScheme.surfaceContainerLow, Color.white)
        XCTAssertEqual(solarScheme.surfaceContainerLowest, Color.white)
        XCTAssertEqual(solarScheme.surfaceContainerHigh, Color.white)
        XCTAssertEqual(solarScheme.surfaceContainerHighest, Color.white)

        // Then outlines and primary accents MUST be pure black
        XCTAssertEqual(solarScheme.outline, Color.black)
        XCTAssertEqual(solarScheme.outlineVariant, Color.black)
        XCTAssertEqual(solarScheme.primary, Color.black)
        XCTAssertEqual(solarScheme.onSurface, Color.black)
        XCTAssertEqual(solarScheme.onSurfaceVariant, Color.black)
    }
}
