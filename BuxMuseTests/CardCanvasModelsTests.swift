
//
//  CardCanvasModelsTests.swift
//  BuxMuseTests
//

import XCTest
@testable import BuxMuse

final class CardCanvasModelsTests: XCTestCase {

    func testMigratorProducesLayersForStarterDesign() {
        let designs = ProBusinessCardLibrary.starterDesigns(
            profileName: "Alex",
            businessName: "Alex Plumbing",
            tagline: "Repairs"
        )
        let doc = CardCanvasMigrator.migrate(from: designs[0])
        XCTAssertFalse(doc.layers.isEmpty)
        XCTAssertTrue(doc.layers.contains { $0.kind == .text })
    }

    func testCanvasDocumentRoundTripEncoding() throws {
        var design = ProBusinessCardDesign(title: "Test", content: ProBusinessCardContent(name: "Sam"))
        design.canvasDocument = CardCanvasMigrator.migrate(from: design)
        let data = try JSONEncoder().encode(design)
        let decoded = try JSONDecoder().decode(ProBusinessCardDesign.self, from: data)
        XCTAssertNotNil(decoded.canvasDocument)
        XCTAssertEqual(decoded.canvasDocument?.layers.count, design.canvasDocument?.layers.count)
    }

    func testHitTestReturnsTopmostLayer() {
        var doc = CardCanvasDocument(canvasWidth: 340, canvasHeight: 200, layers: [
            CardCanvasLayer(
                name: "Back",
                kind: .shape,
                transform: CardLayerTransform(centerX: 0.5, centerY: 0.5, width: 0.8, height: 0.8),
                payload: .shape(CardShapePayload(shapeType: .rectangle, fillHex: "#000000"))
            ),
            CardCanvasLayer(
                name: "Front",
                kind: .text,
                transform: CardLayerTransform(centerX: 0.5, centerY: 0.5, width: 0.4, height: 0.2),
                payload: .text(CardTextPayload(text: "Hi", style: CardTextStyle()))
            ),
        ])
        let hit = CardCanvasHitTester.hitTest(point: CGPoint(x: 0.5, y: 0.5), in: doc)
        XCTAssertEqual(hit, doc.layers.last?.id)
        _ = doc
    }

    func testContentBindingSyncUpdatesName() {
        var design = ProBusinessCardDesign(title: "Test", content: ProBusinessCardContent(name: "Old"))
        design.canvasDocument = CardCanvasMigrator.migrate(from: design)
        design.content.name = "New Name"
        CardCanvasSync.applyContentBindings(to: &design)
        let nameLayer = design.canvasDocument?.layers.first { layer in
            if case .text(let p) = layer.payload { return p.binding == .name }
            return false
        }
        if case .text(let p) = nameLayer?.payload {
            XCTAssertEqual(p.text, "New Name")
        } else {
            XCTFail("Expected name layer")
        }
    }
}
