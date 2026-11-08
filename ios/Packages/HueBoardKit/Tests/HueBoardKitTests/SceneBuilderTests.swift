import XCTest
@testable import HueBoardKit

final class SceneBuilderTests: XCTestCase {
    func light(
        _ id: String,
        dynamic: Bool = true,
        streaming: Bool = false,
        limit: Double = 100,
        colorTemperature: Int? = nil
    ) -> HueLight {
        .init(
            id: .init(rawValue: id),
            ownerID: .init(rawValue: "device-\(id)"),
            name: id,
            isOn: true,
            brightness: 50,
            color: .init(x: 0.3, y: 0.3),
            colorTemperatureMirek: colorTemperature,
            gamut: nil,
            capabilities: .init(
                power: true,
                dimming: true,
                color: true,
                colorTemperature: colorTemperature != nil,
                dynamicPalette: dynamic,
                streaming: streaming
            ),
            outputLimit: limit
        )
    }

    func testScenePayload() throws {
        let contract = try HueBoardContractLoader.load()
        let preset = try XCTUnwrap(contract.preset(id: "ion-eclipse"))
        let area = HueArea(
            id: .init(rawValue: "room"),
            kind: .room,
            name: "Room",
            lights: [
                light("a", limit: 80),
                light("b", limit: 55),
                light("c", dynamic: false),
                light("d", streaming: true),
            ]
        )
        let draft = try HueSceneBuilder.build(
            area: area,
            preset: preset,
            contract: contract,
            brightness: 90
        )
        XCTAssertEqual(draft.animatedLightIDs.map(\.rawValue), ["a", "b"])
        XCTAssertEqual(draft.create.actions.count, 2)
        XCTAssertTrue(draft.create.actions.allSatisfy { $0.action.dimming?.brightness == 55 })
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft.create))
            as? [String: Any]
        XCTAssertEqual(object?["auto_dynamic"] as? Bool, true)
    }

    func testRejectUnsupported() throws {
        let contract = try HueBoardContractLoader.load()
        let preset = try XCTUnwrap(contract.presets.first)
        let area = HueArea(
            id: .init(rawValue: "r"),
            kind: .room,
            name: "R",
            lights: [light("x", dynamic: false)]
        )
        XCTAssertThrowsError(
            try HueSceneBuilder.build(area: area, preset: preset, contract: contract, brightness: 60)
        )
    }

    func testRestoreSnapshotPrefersActiveColorTemperatureOverStaleXY() throws {
        let snapshot = HueLightSnapshot(light: light("white", colorTemperature: 250))
        XCTAssertEqual(snapshot.action.colorTemperature?.mirek, 250)
        XCTAssertNil(snapshot.action.color)

        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot.action))
            as? [String: Any]
        XCTAssertNotNil(encoded?["color_temperature"])
        XCTAssertNil(encoded?["color"])
    }
}
