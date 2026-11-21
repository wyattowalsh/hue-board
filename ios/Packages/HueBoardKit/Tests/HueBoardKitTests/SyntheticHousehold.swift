import Foundation
import HueBoardKit
import XCTest

/// Test-only inventory and independently authored expectations shared by the Room and sweep suites.
struct SyntheticHousehold: Decodable {
    struct Fixture: Decodable {
        enum Capability: String, Decodable { case color, white }
        let id: String
        let name: String
        let capability: Capability
        let x: Double
        let role: HueFixtureRole?
        let selected: Bool?
        let minimumBrightness: Double?

        var light: HueLight {
            .init(id: .init(rawValue: id), ownerID: nil, name: name, isOn: true, brightness: 50,
                  color: nil, colorTemperatureMirek: nil, gamut: nil,
                  capabilities: .init(power: true, dimming: true, color: capability == .color,
                                      colorTemperature: capability == .white, dynamicPalette: capability == .color),
                  minimumBrightness: minimumBrightness ?? 1)
        }

        var placement: HueFixturePlacement {
            .init(id: .init(rawValue: id), selected: selected ?? true, x: x, y: 0.5, phase: 0.91,
                  trim: 0.8, ceiling: 85, role: role ?? .wash)
        }
    }

    struct Room: Decodable {
        let id: String
        let fixtures: [Fixture]
        var area: HueArea { .init(id: .init(rawValue: id), kind: .room, name: id, lights: fixtures.map(\.light)) }
        var layout: HueRoomLayout { .init(areaID: .init(rawValue: id), placements: fixtures.map(\.placement)) }
    }

    struct Discovery: Decodable {
        struct Match: Decodable { let id: String; let fixtureIDs: [String] }
        let roomID: String
        let fixtureCount: Int
        let ranked: [Match]
        let topView: [String: [Double]]
    }

    struct Sweep: Decodable {
        let roomID: String
        let brightnessLimit: Double
        let distinctRanks: Int
        let eligibleIDs: [String]
        let expectedPhases: [String: Double]
    }

    let revision: String
    let provenance: String
    let rooms: [Room]
    let configurations: [HueEntertainmentConfigurationResource]
    let services: [HueEntertainmentServiceResource]
    let discovery: [Discovery]
    let sweep: Sweep

    func room(_ id: String) throws -> Room { try XCTUnwrap(rooms.first { $0.id == id }) }

    static func load() throws -> Self {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "synthetic-household-v1", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let hash = fixtureSHA256(data)
        XCTAssertEqual(hash, "4084f20d234c0924672cefe2e08b6d22bb49d52bce08124e8d29351fab129426")
        let fixture = try JSONDecoder().decode(Self.self, from: data)
        XCTAssertEqual(fixture.revision, "F02-1")
        XCTAssertTrue(fixture.provenance.hasPrefix("Hand-authored synthetic household"))
        return fixture
    }
}
