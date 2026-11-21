import XCTest
@testable import HueBoardKit

final class HueEntertainmentLayoutTests: XCTestCase {
    func testCLIPServicePositionsProjectIntoOnlyMatchedRoomFixtures() throws {
        let configurations = try resources(HueEntertainmentConfigurationResource.self, #"""
        {"errors":[],"data":[{
          "id":"saved-area","type":"entertainment_configuration","metadata":{"name":" Movie lights "},
          "configuration_type":"screen","status":"inactive",
          "locations":{"service_locations":[
            {"service":{"rid":"left-service","rtype":"entertainment"},"positions":[{"x":-1,"y":0.5,"z":0.5},{"x":0,"y":1,"z":-0.5}]},
            {"service":{"rid":"right-light","rtype":"light"},"position":{"x":1,"y":-1,"z":1}},
            {"service":{"rid":"outside","rtype":"light"},"positions":[{"x":1,"y":1,"z":0}]}
          ]},
          "channels":[{"position":{"x":1,"y":1,"z":0},"members":[{"service":{"rid":"unmatched","rtype":"light"},"index":0}]}],
          "light_services":[{"rid":"unmatched","rtype":"light"}]
        }]}
        """#)
        let services = try resources(HueEntertainmentServiceResource.self, #"""
        {"errors":[],"data":[{
          "id":"left-service","type":"entertainment","owner":{"rid":"owner","rtype":"device"},
          "renderer":true,"renderer_reference":{"rid":"left-light","rtype":"light"}
        }]}
        """#)
        let room = area(["left-light", "right-light", "unmatched"])
        let options = HueRoomArrangement.matching(configurations: configurations, services: services, in: room)
        let option = try XCTUnwrap(options.first)
        XCTAssertEqual(options.count, 1)
        XCTAssertEqual(option.name, "Movie lights")
        XCTAssertEqual(option.areaID, room.id)
        XCTAssertEqual(option.matchedCount, 2)

        var before = HueRoomLayout.startingLayout(for: room)
        before.placements[0].selected = false
        before.placements[0].trim = 0.3
        before.placements[0].ceiling = 40
        before.placements[0].role = .task
        before.placements[0].phase = 0.9
        let after = try option.applying(to: before, in: room)
        XCTAssertEqual(after.placements[0].x, 0.3, accuracy: 1e-12)
        XCTAssertEqual(after.placements[0].y, 0.2, accuracy: 1e-12)
        XCTAssertEqual(after.placements[1].x, 0.9, accuracy: 1e-12)
        XCTAssertEqual(after.placements[1].y, 0.9, accuracy: 1e-12)
        XCTAssertEqual(after.placements[2], before.placements[2])
        var unchanged = after.placements[0]
        unchanged.x = before.placements[0].x
        unchanged.y = before.placements[0].y
        XCTAssertEqual(unchanged, before.placements[0])
    }

    func testSkipsAmbiguousInvalidAndUnlinkedPositions() throws {
        let configurations = try resources(HueEntertainmentConfigurationResource.self, #"""
        {"errors":[],"data":[{
          "id":"saved-area","name":"Legacy name","locations":{"service_locations":[
            {"service":{"rid":"ambiguous","rtype":"light"},"positions":[{"x":1,"y":0,"z":0}]},
            {"service":{"rid":"repeated","rtype":"entertainment"},"positions":[{"x":-1,"y":0,"z":0}]},
            {"service":{"rid":"invalid","rtype":"light"},"positions":[{"x":0,"y":0,"z":1.1}],"position":{"x":0,"y":0,"z":0}},
            {"service":{"rid":"unlinked-service","rtype":"entertainment"},"position":{"x":0,"y":0,"z":0}},
            {"service":{"rid":"valid","rtype":"light"},"positions":[{"x":0,"y":0,"z":0}]}
          ]}
        }]}
        """#)
        let services = try resources(HueEntertainmentServiceResource.self, #"""
        {"errors":[],"data":[
          {"id":"unlinked-service","owner":{"rid":"owner","rtype":"device"}},
          {"id":"repeated","renderer_reference":{"rid":"ambiguous","rtype":"light"}}
        ]}
        """#)
        let room = area(["ambiguous", "invalid", "unlinked", "valid"])
        let options = HueRoomArrangement.matching(configurations: configurations, services: services, in: room)
        let option = try XCTUnwrap(options.first)
        XCTAssertEqual(option.name, "Legacy name")
        XCTAssertEqual(option.matchedCount, 1)
        let original = HueRoomLayout.startingLayout(for: room)
        let applied = try option.applying(to: original, in: room)
        XCTAssertEqual(Array(applied.placements.prefix(3)), Array(original.placements.prefix(3)))
        XCTAssertEqual(applied.placements[3].x, 0.5)
        XCTAssertEqual(applied.placements[3].y, 0.5)

        let duplicateOptions = HueRoomArrangement.matching(configurations: configurations + configurations, services: services, in: room)
        XCTAssertTrue(duplicateOptions.isEmpty)
    }

    func testRejectsApplyingToAnotherRoomOrAfterMatchedFixtureLeaves() throws {
        let configurations = try resources(HueEntertainmentConfigurationResource.self, #"""
        {"errors":[],"data":[{"id":"saved-area","locations":{"service_locations":[
          {"service":{"rid":"fixture","rtype":"light"},"positions":[{"x":0,"y":0,"z":0}]}
        ]}}]}
        """#)
        let room = area(["fixture", "other"])
        let options = HueRoomArrangement.matching(configurations: configurations, services: [], in: room)
        let option = try XCTUnwrap(options.first)

        let otherRoom = area(["fixture"], id: "other-room")
        XCTAssertThrowsError(try option.applying(to: .startingLayout(for: otherRoom), in: otherRoom))
        let shrunkRoom = area(["other"])
        XCTAssertThrowsError(try option.applying(to: .startingLayout(for: room), in: shrunkRoom))
    }

    private func resources<T: Codable & Sendable>(_ type: T.Type, _ json: String) throws -> [T] {
        try JSONDecoder().decode(HueAPIResponse<T>.self, from: Data(json.utf8)).data
    }

    private func area(_ IDs: [String], id: String = "selected-room") -> HueArea {
        .init(id: .init(rawValue: id), kind: .room, name: "Room", lights: IDs.map { id in
            HueLight(
                id: .init(rawValue: id), ownerID: .init(rawValue: "owner"), name: id, isOn: true,
                brightness: 30, color: nil, colorTemperatureMirek: nil, gamut: nil,
                capabilities: .init(power: true, dimming: true, color: true, colorTemperature: false, dynamicPalette: true)
            )
        })
    }
}
