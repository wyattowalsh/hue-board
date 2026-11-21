import XCTest
@testable import HueBoardKit

final class HueRoomDiscoveryTests: XCTestCase {
    private func area(_ names: [String]) -> HueArea {
        .init(id: .init(rawValue: "room"), kind: .room, name: "Room", lights: names.map { name in
            .init(id: .init(rawValue: name), ownerID: nil, name: name, isOn: true, brightness: 40,
                  color: nil, colorTemperatureMirek: nil, gamut: nil,
                  capabilities: .init(power: true, dimming: true, color: true, colorTemperature: false, dynamicPalette: true))
        })
    }

    private func configuration(_ id: String, _ lightNames: [String], name: String = "Movie") -> HueEntertainmentConfigurationResource {
        .init(id: .init(rawValue: id), metadata: nil, name: name, locations: .init(serviceLocations: lightNames.map { light in
            .init(service: .init(resourceID: .init(rawValue: light), resourceType: "light"),
                  positions: nil, position: .init(x: 0, y: 0, z: 0))
        }))
    }

    func testDistinguishesMissingAreasFromRejectedOutsideAndAmbiguousPositions() {
        let room = area(["left", "right"])
        XCTAssertEqual(HueRoomDiscovery(configurations: [], services: [], in: room), .noSavedAreas)
        for names in [["elsewhere"], ["left", "left"], []] {
            XCTAssertEqual(HueRoomDiscovery(configurations: [configuration("a", names)], services: [], in: room), .noMatchingPositions)
        }
        let duplicate = configuration("same-area", ["left"])
        XCTAssertEqual(HueRoomDiscovery(configurations: [duplicate, duplicate], services: [], in: room), .noMatchingPositions)
    }

    func testCoverageUsesCurrentRoomMembershipAndStableOrder() throws {
        let fixture = try SyntheticHousehold.load()
        for expected in fixture.discovery {
            let room = try fixture.room(expected.roomID)
            let result = HueRoomDiscovery(configurations: fixture.configurations, services: fixture.services, in: room.area)
            guard case let .matches(options, count) = result else { return XCTFail("Missing layouts for \(room.id)") }
            XCTAssertEqual(count, expected.fixtureCount)
            XCTAssertEqual(options.map { $0.id.rawValue }, expected.ranked.map(\.id))
            for (option, match) in zip(options, expected.ranked) {
                XCTAssertEqual(option.matchedCount, match.fixtureIDs.count)
                let matched = room.area.lights.filter { option.hasPosition(for: $0.id) }
                XCTAssertEqual(Set(matched.map { $0.id.rawValue }), Set(match.fixtureIDs))
            }
        }
    }

    func testAsymmetricTopViewUsesHorizontalAndDepthIndependentOfHeight() throws {
        let fixture = try SyntheticHousehold.load()
        for expected in fixture.discovery {
            let room = try fixture.room(expected.roomID)
            let result = HueRoomDiscovery(configurations: fixture.configurations, services: fixture.services, in: room.area)
            let saved = try XCTUnwrap(result.arrangements.first)
            let layout = try saved.applying(to: room.layout, in: room.area)
            for (id, point) in expected.topView {
                let actual = try XCTUnwrap(layout.placements.first { $0.id.rawValue == id })
                XCTAssertEqual(point.count, 2)
                XCTAssertEqual(actual.x, try XCTUnwrap(point.first), accuracy: 1e-12)
                XCTAssertEqual(actual.y, try XCTUnwrap(point.last), accuracy: 1e-12)
            }
        }
    }
}
