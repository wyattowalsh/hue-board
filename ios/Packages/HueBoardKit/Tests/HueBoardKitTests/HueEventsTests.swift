import XCTest
@testable import HueBoardKit

final class HueEventsTests: XCTestCase {
    func testParserIgnoresSSEMetadataAndDecodesLightUpdate() throws {
        var parser = HueEventStreamParser()
        XCTAssertNil(try parser.ingest(": heartbeat"))
        XCTAssertNil(try parser.ingest("id: event-1"))
        XCTAssertNil(try parser.ingest("event: update"))
        XCTAssertNil(
            try parser.ingest(
                "data: [{\"creationtime\":\"2026-11-08T12:00:00Z\",\"id\":\"event-1\",\"type\":\"update\",\"data\":[{\"id\":\"light-1\",\"type\":\"light\",\"on\":{\"on\":false},\"dimming\":{\"brightness\":22.5},\"color_temperature\":{\"mirek\":null,\"mirek_valid\":false},\"dynamics\":{\"status\":\"dynamic_palette\"},\"mode\":\"streaming\"}]}]"
            )
        )
        let batch = try XCTUnwrap(parser.ingest(""))
        XCTAssertEqual(batch.containers.count, 1)
        XCTAssertEqual(batch.resources.count, 1)
        XCTAssertFalse(batch.requiresInventoryRefresh)

        let base = HueLight(
            id: .init(rawValue: "light-1"),
            ownerID: .init(rawValue: "device-1"),
            name: "Floor lamp",
            isOn: true,
            brightness: 67,
            color: .init(x: 0.3, y: 0.3),
            colorTemperatureMirek: 250,
            dynamicStatus: "none",
            gamut: nil,
            capabilities: .init(
                power: true,
                dimming: true,
                color: true,
                colorTemperature: true,
                dynamicPalette: true
            )
        )
        let updated = base.applying(try XCTUnwrap(batch.resources.first))
        XCTAssertFalse(updated.isOn)
        XCTAssertEqual(updated.brightness, 22.5)
        XCTAssertNil(updated.colorTemperatureMirek)
        XCTAssertEqual(updated.dynamicStatus, "dynamic_palette")
        XCTAssertTrue(updated.capabilities.streaming)
        XCTAssertEqual(updated.name, base.name)
        XCTAssertEqual(updated.outputLimit, base.outputLimit)
    }

    func testParserSupportsMultilineDataAndStructuralRefresh() throws {
        var parser = HueEventStreamParser()
        XCTAssertNil(try parser.ingest("data: [{\"id\":\"event-2\",\"type\":\"add\","))
        XCTAssertNil(try parser.ingest("data: \"data\":[{\"id\":\"room-2\",\"type\":\"room\"}]}]"))
        let batch = try XCTUnwrap(parser.ingest("\r"))
        XCTAssertTrue(batch.requiresInventoryRefresh)
        XCTAssertEqual(batch.resources.first?.type, "room")
    }

    func testParserRejectsOversizedEventAndResets() throws {
        var parser = HueEventStreamParser()
        let oversized = "data: " + String(
            repeating: "x",
            count: HueEventStreamParser.maximumEventBytes + 1
        )
        XCTAssertThrowsError(try parser.ingest(oversized))

        XCTAssertNil(
            try parser.ingest(
                "data: [{\"id\":\"event-3\",\"type\":\"update\",\"data\":[]}]"
            )
        )
        XCTAssertNotNil(try parser.finish())
    }
}
