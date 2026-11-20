import XCTest
@testable import HueBoardKit

final class HueSpatialCueTests: XCTestCase {
    private func fixture(_ id: String, streaming: Bool = false, color: Bool = true) -> HueLight {
        HueLight(
            id: .init(rawValue: id),
            ownerID: nil,
            name: id,
            isOn: true,
            brightness: 60,
            color: color ? HueXY(x: 0.3, y: 0.3) : nil,
            colorTemperatureMirek: nil,
            gamut: nil,
            capabilities: .init(
                power: true,
                dimming: true,
                color: color,
                colorTemperature: false,
                dynamicPalette: true,
                streaming: streaming
            ),
            outputLimit: 70,
            minimumBrightness: 5
        )
    }

    private func area(_ lights: [HueLight]) -> HueArea {
        HueArea(id: .init(rawValue: "room-1"), kind: .room, name: "Room", lights: lights)
    }

    func testRoomLayoutStoreIsScopedAndRoundTrips() throws {
        let suite = "HueSpatialStore.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HueRoomLayoutStore(defaults: defaults)
        let room = area([fixture("one")])
        var saved = try store.load(bridgeID: "bridge-a", area: room)
        saved.placements[0].phase = 0.81
        saved.placements[0].selected = false
        try store.save(saved, bridgeID: "bridge-a", area: room)
        XCTAssertEqual(try store.load(bridgeID: "bridge-a", area: room), saved)
        XCTAssertTrue(
            try store.load(bridgeID: "bridge-b", area: room).placements[0].selected
        )

        let expanded = area([fixture("one"), fixture("new")])
        let loaded = try store.load(bridgeID: "bridge-a", area: expanded)
        XCTAssertEqual(loaded.placements[0].phase, 0.81)
        XCTAssertFalse(loaded.placements[1].selected)
    }

    func testCorruptedRoomLayoutIsPreservedAndCannotOverwriteOnLoad() throws {
        let suite = "HueSpatialCorrupt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HueRoomLayoutStore(defaults: defaults)
        let room = area([fixture("one")])
        let key = "hue-board.native.layout.v1.bridge-a.\(room.id.rawValue)"
        let corrupt = Data("{not valid JSON}".utf8)
        defaults.set(corrupt, forKey: key)
        XCTAssertThrowsError(try store.load(bridgeID: "bridge-a", area: room))
        XCTAssertEqual(defaults.data(forKey: key), corrupt)
    }

    func testStartingLayoutUsesEligibleLightsOnly() throws {
        let room = area([
            fixture("color"), fixture("streaming", streaming: true),
            fixture("white", color: false)
        ])
        let layout = HueRoomLayout.startingLayout(for: room)
        try layout.validate(for: room)
        XCTAssertEqual(layout.selectedEntries(in: room).map { $0.0.id.rawValue }, ["color"])
        XCTAssertTrue(layout.placements.allSatisfy { $0.x >= 0 && $0.x <= 1 })
        XCTAssertTrue(layout.placements.allSatisfy { $0.phase >= 0 && $0.phase <= 1 })
    }

    func testAdditionalLightsStartExcludedWithoutReplacingPriorPlacements() throws {
        let original = area([fixture("first")])
        var layout = HueRoomLayout.startingLayout(for: original)
        layout.placements[0].phase = 0.83
        layout.placements[0].ceiling = 35
        let enlarged = area([fixture("first"), fixture("new")])
        let next = try layout.includingNewLights(from: enlarged)
        XCTAssertEqual(next.placements.count, 2)
        XCTAssertEqual(next.placements[0].phase, 0.83)
        XCTAssertEqual(next.placements[0].ceiling, 35)
        XCTAssertFalse(next.placements[1].selected)
        XCTAssertEqual(next.selectedEntries(in: enlarged).count, 1)
    }

    func testLimitsAndInvalidPlacementsFailClosed() throws {
        let light = fixture("one")
        let layout = area([light])
        let placement = HueFixturePlacement(
            id: light.id, selected: true,
            x: 0.3, y: 0.4, phase: 0.25,
            trim: 0.5, ceiling: 30
        )
        try placement.validate()
        XCTAssertEqual(placement.brightness(for: 100, light: light), 30)
        XCTAssertEqual(placement.brightness(for: 20, light: light), 10)
        XCTAssertEqual(placement.brightness(for: 0, light: light), 5)
        XCTAssertNil(placement.brightness(for: .nan, light: light))

        var invalid = placement
        invalid.x = .nan
        XCTAssertThrowsError(try invalid.validate())
        invalid = placement
        invalid.trim = 1.5
        XCTAssertThrowsError(try invalid.validate())
        XCTAssertThrowsError(
            try HueRoomLayout(areaID: layout.id, placements: [placement, placement])
                .validate(for: layout)
        )
        XCTAssertTrue(HueFixtureRole.task.isStatic)
        XCTAssertFalse(HueFixtureRole.accent.isStatic)
    }

    func testCueBoundaryForwardAndNoCatchUp() throws {
        let program = HueCueSequence(
            presetIDs: ["a", "b", "c"], holdSeconds: 30, order: .forward, seed: 13
        )
        XCTAssertEqual(try program.cue(at: 29.999).presetID, "a")
        let next = try program.cue(at: 30)
        XCTAssertEqual(next.presetID, "b")
        XCTAssertEqual(next.remaining, 30)
        XCTAssertEqual(try program.cue(at: 91).presetID, "a")
        XCTAssertEqual(try program.cue(at: 91).cycle, 1)
        XCTAssertThrowsError(try program.cue(at: -.infinity))
    }

    func testSeededShuffleReproducibleAndAvoidsBoundaryRepeats() throws {
        let program = HueCueSequence(
            presetIDs: ["a", "b", "c", "d"],
            holdSeconds: 30, order: .shuffle, seed: 731
        )
        let first = try (0..<40).map { try program.cue(at: Double($0 * 30)).presetID }
        let again = try (0..<40).map { try program.cue(at: Double($0 * 30)).presetID }
        XCTAssertEqual(first, again)
        for index in 1..<first.count {
            XCTAssertNotEqual(first[index], first[index - 1])
        }
    }

    func testCueSettingsRetainGlobalMasterAndRejectUnknownIDs() throws {
        let contract = try HueBoardContractLoader.load()
        let presets = Array(contract.presets.prefix(2))
        XCTAssertEqual(presets.count, 2)
        let program = HueCueSequence(
            presetIDs: presets.map(\.id), holdSeconds: 90,
            order: .forward, seed: 42
        )
        try program.validate(contract: contract)
        var draft = HueEngineSettings()
        draft.brightness = 38
        draft.topology = "path"
        let frame = try program.settings(at: 91, contract: contract, base: draft)
        XCTAssertEqual(frame.settings.brightness, 38)
        XCTAssertEqual(frame.settings.topology, "path")
        XCTAssertEqual(frame.settings.showA, presets[1].pattern)
        let invalid = HueCueSequence(
            presetIDs: ["unknown"], holdSeconds: 90, order: .forward, seed: 42
        )
        XCTAssertThrowsError(try invalid.validate(contract: contract))
    }

    func testShuffleRejectsDuplicatesRatherThanClaimingNoRepeats() throws {
        let contract = try HueBoardContractLoader.load()
        let first = try XCTUnwrap(contract.presets.first)
        let program = HueCueSequence(
            presetIDs: [first.id, first.id], holdSeconds: 30,
            order: .shuffle, seed: 1
        )
        XCTAssertThrowsError(try program.validate(contract: contract))
    }
}
