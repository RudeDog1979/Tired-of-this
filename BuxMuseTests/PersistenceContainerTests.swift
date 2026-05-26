//
//  PersistenceContainerTests.swift
//  BuxMuseTests
//
//  Ensures SwiftData container opens after schema changes.
//

import XCTest
@testable import BuxMuse

@MainActor
final class PersistenceContainerTests: XCTestCase {
    func testInMemoryContainerOpens() {
        let persistence = PersistenceController(inMemory: true)
        XCTAssertNotNil(persistence.container)
        XCTAssertNoThrow(try persistence.seedExpenseCatalogIfNeeded())
    }

    func testOnDiskContainerOpens() throws {
        let persistence = PersistenceController(inMemory: false)
        XCTAssertNotNil(persistence.container)
        try persistence.seedExpenseCatalogIfNeeded()
    }
}
