import Foundation
import HueBoardKit
import XCTest
@testable import HueBoardNativeCore

/// These tests observe synthetic commands on the paced REST path. A physical lamp
/// and its transition behavior require a separate device qualification.
final class DynamicLightSafetyVectorTests: XCTestCase {
    func testExtremeRedToCyanFlashIsPacedAndCappedBeforeSubmission() async throws {
        let fixture = try makeFixture()
        let sampler = AlternatingColors()
        let receipts = VectorReceipts()
        do {
            try await NativeLiveRunner(engine: sampler).run(
                area: fixture.area, layout: fixture.layout, settings: .init(brightness: 27),
                cueSequence: fixture.cues, contract: fixture.contract, duration: 12,
                safetySettings: .init(warningAcknowledged: true, maximumDynamicBrightness: 23),
                signal: { elapsed in await receipts.signal(elapsed) },
                submit: { frame in try await receipts.record(frame) }, progress: { _ in }
            )
            XCTFail("Expected two commands before the test source completed")
        } catch EndVector.finished {}
        let (actions, times) = await receipts.observations()
        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(times.count, 2)
        guard actions.count == 2, times.count == 2 else { return }
        XCTAssertGreaterThanOrEqual(times[1] - times[0], 4.49)
        let id = fixture.area.lights[0].id
        let first = try XCTUnwrap(actions[0].actions[id])
        let second = try XCTUnwrap(actions[1].actions[id])
        XCTAssertEqual(first.dimming?.brightness, 19)
        XCTAssertEqual(second.dimming?.brightness, 1)
        XCTAssertEqual(first.color?.xy, HueXY(x: 0.64, y: 0.33))
        XCTAssertEqual(second.color?.xy, HueXY(x: 0.22, y: 0.33))
        XCTAssertEqual(first.dynamics?.duration, 4_500)
        XCTAssertEqual(second.dynamics?.duration, 4_500)
    }

    func testPhysicalReduceLightMotionRejectsTransientColorAndLevelInputsForCueFrames() async throws {
        let fixture = try makeFixture()
        let planner = try StudioFramePlanner(area: fixture.area, layout: fixture.layout,
            settings: .init(brightness: 24), cueSequence: fixture.cues, contract: fixture.contract,
            safety: .init(warningAcknowledged: true, reduceLightMotion: true, maximumDynamicBrightness: 21))
        XCTAssertFalse(planner.acceptsSignal)
        XCTAssertEqual(planner.transitionMilliseconds, 8_000)
        let phase = 30.0
        let plain = try await planner.frame(at: phase, duration: 60, signal: nil, engine: AlternatingColors())
        let react = try await planner.frame(at: phase, duration: 60,
            signal: .init(level: 10, color: .init(red: 0, green: 1, blue: 1)), engine: AlternatingColors())
        XCTAssertEqual(react, plain)
        XCTAssertEqual(react.cue?.presetID, fixture.cues.presetIDs[1])
        XCTAssertEqual(react.targets[fixture.area.lights[0].id]?.brightness, 19)
    }

    func testImportedRapidCueAndInvalidSessionTimesCannotSubmit() async throws {
        let fixture = try makeFixture()
        let counters = VectorReceipts()
        let malformed = HueCueSequence(presetIDs: fixture.cues.presetIDs, holdSeconds: 0.10, order: .forward, seed: 5)
        XCTAssertThrowsError(try HuePortableDataCodec.encode(.cues(malformed), contract: fixture.contract))
        for (duration, cues) in [(Double.nan, fixture.cues), (.infinity, fixture.cues),
                                    (0, fixture.cues), (-1, fixture.cues), (30, malformed)] {
            do {
                try await NativeLiveRunner(engine: AlternatingColors()).run(
                    area: fixture.area, layout: fixture.layout, settings: .init(brightness: 23),
                    cueSequence: cues, contract: fixture.contract, duration: duration, safetySettings: .default,
                    submit: { try await counters.record($0) }, progress: { _ in }
                )
                XCTFail("Invalid timing must stop before any command")
            } catch HueBoardError.unsupported {}
        }
        let counts = await counters.observations()
        XCTAssertTrue(counts.0.isEmpty)
    }

    private func makeFixture() throws -> (area: HueArea, layout: HueRoomLayout, cues: HueCueSequence, contract: HueBoardContract) {
        let light = HueLight(id: .init(rawValue: "fixture"), ownerID: nil, name: "Test fixture", isOn: true,
            brightness: 20, color: .init(x: 0.33, y: 0.32), colorTemperatureMirek: nil, gamut: nil,
            capabilities: .init(power: true, dimming: true, color: true, colorTemperature: false, dynamicPalette: false),
            outputLimit: 25, minimumBrightness: 1)
        let area = HueArea(id: .init(rawValue: "test-room"), kind: .room, name: "Test room", lights: [light])
        var layout = HueRoomLayout.startingLayout(for: area)
        layout.placements[0].ceiling = 19
        let contract = try HueBoardContractLoader.load()
        let cues = HueCueSequence(presetIDs: Array(contract.presets.prefix(2)).map(\.id), holdSeconds: 30,
                                  order: .forward, seed: 5)
        return (area, layout, cues, contract)
    }
}

private enum EndVector: Error { case finished }

private actor AlternatingColors: HueEngineSampling {
    var count = 0
    func sample(time: Double, position: Double, settings: HueEngineSettings, surge: Double) async throws -> HueLightFrame {
        count += 1
        let red = count.isMultiple(of: 2) ? 0.0 : 1.0
        return .init(color: .init(red: red, green: 1 - red, blue: 1 - red), brightness: red * 100)
    }
    func xy(_ color: RGB, gamut: HueGamut?) async throws -> HueXY {
        .init(x: color.red > 0.5 ? 0.64 : 0.22, y: 0.33)
    }
}

private actor VectorReceipts {
    private var frames: [LightingFrame] = []
    private var signalTimes: [TimeInterval] = []
    func signal(_ time: TimeInterval) -> HueLiveSignal {
        signalTimes.append(time)
        return .init(level: 1)
    }
    func record(_ frame: LightingFrame) throws {
        frames.append(frame)
        if frames.count == 2 { throw EndVector.finished }
    }
    func observations() -> ([LightingFrame], [TimeInterval]) { (frames, signalTimes) }
}
