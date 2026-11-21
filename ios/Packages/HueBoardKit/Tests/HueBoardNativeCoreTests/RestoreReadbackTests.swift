import HueBoardKit
import HueBoardNativeCore
import XCTest

final class RestoreReadbackTests: XCTestCase {
    func testXYRestoreRequiresMatchingCoordinatesInTheActiveColorMode() {
        let snapshot = HueLightSnapshot(light: light("color"))

        XCTAssertTrue(snapshot.matchesRestoreReadback(light(
            "color", brightness: 50.5, xy: .init(x: 0.3001, y: 0.3099)
        )))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light(
            "color", xy: .init(x: 0.3002, y: 0.31)
        )))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light(
            "color", xy: .init(x: 0.3, y: 0.3098)
        )))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light("color", xy: nil)))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light("color", mirek: 250)))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light(
            "color", dynamicStatus: "dynamic_palette"
        )))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light("color", brightness: 49)))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light("color", isOn: false)))
    }

    func testWhiteRestoreRequiresActiveMirekAndIgnoresRetainedXY() {
        let snapshot = HueLightSnapshot(light: light("white", mirek: 250))

        XCTAssertTrue(snapshot.matchesRestoreReadback(light(
            "white", xy: .init(x: 0.6, y: 0.3), mirek: 250
        )))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light("white")))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light("white", mirek: 251)))
        XCTAssertFalse(snapshot.canRestore(to: light("white", hasTemperature: false)))
        XCTAssertFalse(snapshot.canRestore(to: light("white", temperatureMinimum: 251)))
    }

    func testPowerOnlyBaselineDoesNotRequireUnrecordedBrightnessOrColor() {
        let off = light("plug", isOn: false, brightness: nil, xy: nil,
                        hasColor: false, hasTemperature: false, hasDimming: false)
        let snapshot = HueLightSnapshot(light: off)

        XCTAssertTrue(snapshot.matchesRestoreReadback(off))
        XCTAssertFalse(snapshot.matchesRestoreReadback(light(
            "plug", isOn: true, brightness: nil, xy: nil,
            hasColor: false, hasTemperature: false, hasDimming: false
        )))
    }

    func testPartialReadbackRetainsWrongModeMissingAndIneligibleFixtures() {
        let initialArea = area([
            light("matched"),
            light("wrong-mode", mirek: 250),
            light("missing"),
            light("streaming"),
            light("lost-color"),
            light("lost-dimming"),
        ])
        let journal = RestoreJournal(
            bridgeID: "test-bridge",
            area: initialArea,
            lights: initialArea.lights
        )
        let readback = area([
            light("matched"),
            light("wrong-mode"),
            light("streaming", streaming: true),
            light("lost-color", hasColor: false),
            light("lost-dimming", hasDimming: false),
        ])

        XCTAssertEqual(
            journal.snapshotsEligibleForRestore(in: [readback]).map(\.lightID.rawValue),
            ["matched", "wrong-mode"]
        )
        XCTAssertEqual(
            journal.snapshotsAwaitingRestoreReadback(in: [readback]),
            Array(journal.snapshots.dropFirst())
        )
        XCTAssertTrue(journal.snapshotsAwaitingRestoreReadback(in: [initialArea]).isEmpty)
    }

    private func area(_ lights: [HueLight]) -> HueArea {
        .init(id: .init(rawValue: "test-area"), kind: .room, name: "Test room", lights: lights)
    }

    private func light(
        _ id: String,
        isOn: Bool = true,
        brightness: Double? = 50,
        xy: HueXY? = .init(x: 0.3, y: 0.31),
        mirek: Int? = nil,
        dynamicStatus: String = "none",
        hasColor: Bool = true,
        hasTemperature: Bool = true,
        hasDimming: Bool = true,
        temperatureMinimum: Int = 153,
        streaming: Bool = false
    ) -> HueLight {
        .init(
            id: .init(rawValue: id),
            ownerID: nil,
            name: "Test light",
            isOn: isOn,
            brightness: brightness,
            color: xy,
            colorTemperatureMirek: mirek,
            dynamicStatus: dynamicStatus,
            gamut: nil,
            capabilities: .init(
                power: true,
                dimming: hasDimming,
                color: hasColor,
                colorTemperature: hasTemperature,
                dynamicPalette: true,
                streaming: streaming
            ),
            temperatureMinimumMirek: temperatureMinimum,
            temperatureMaximumMirek: 454
        )
    }
}
