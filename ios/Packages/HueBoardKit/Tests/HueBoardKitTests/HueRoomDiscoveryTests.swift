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

    func testCoverageUsesCurrentRoomMembershipAndStableOrder() {
        let configurations = [configuration("b", ["left"]), configuration("a", ["right"]),
                              configuration("whole", ["right", "outside", "left"])]
        let result = HueRoomDiscovery(configurations: configurations, services: [], in: area(["right", "left"]))
        guard case let .matches(options, count) = result else { return XCTFail("Expected three layouts") }
        XCTAssertEqual(count, 2)
        XCTAssertEqual(options.map { $0.id.rawValue }, ["whole", "a", "b"])
        XCTAssertEqual(options.map(\.matchedCount), [2, 1, 1])
    }

    func testAsymmetricTopViewUsesHorizontalAndDepthIndependentOfHeight() throws {
        let ids = ["left-front", "right-back", "elevated"]
        let room = area(ids)
        let coords: [HueEntertainmentPosition] = [.init(x: -0.5, y: 0.75, z: 0), .init(x: 0.75, y: -0.5, z: 0),
                                                   .init(x: 0.75, y: -0.5, z: 1)]
        let locations = zip(ids, coords).map { id, point in
            HueEntertainmentConfigurationResource.ServiceLocation(
                service: .init(resourceID: .init(rawValue: id), resourceType: "light"), positions: nil, position: point)
        }
        let saved = HueEntertainmentConfigurationResource(id: .init(rawValue: "test"), metadata: nil, name: nil,
                                                         locations: .init(serviceLocations: locations))
        let result = HueRoomDiscovery(configurations: [saved], services: [], in: room)
        let layout = try XCTUnwrap(result.arrangements.first).applying(to: .startingLayout(for: room), in: room)
        let expected = [(0.3, 0.2), (0.8, 0.7), (0.8, 0.7)]
        for (actual, point) in zip(layout.placements, expected) {
            XCTAssertEqual(actual.x, point.0, accuracy: 1e-12)
            XCTAssertEqual(actual.y, point.1, accuracy: 1e-12)
        }
    }
}
