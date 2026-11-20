import XCTest
import HueBoardKit
@testable import HueBoardNativeCore

private enum EndFixtureFrame: Error { case captured }

private actor SyntheticHueSampler: HueEngineSampling {
    private var positions: [Double] = []
    private var patterns: [String] = []

    func sample(
        time: Double,
        position: Double,
        settings: HueEngineSettings,
        surge: Double
    ) async throws -> HueLightFrame {
        positions.append(position)
        patterns.append(settings.showA)
        return HueLightFrame(
            color: RGB(red: 0.1, green: 0.3, blue: 0.7),
            brightness: 80
        )
    }

    func xy(_ color: RGB, gamut: HueGamut?) async throws -> HueXY {
        .init(x: 0.3, y: 0.35)
    }

    func recordedPositions() -> [Double] { positions }
    func recordedPatterns() -> [String] { patterns }
}

private actor SyntheticFrameRecorder {
    private var frames: [LightingFrame] = []

    func record(_ frame: LightingFrame) {
        frames.append(frame)
    }
    func first() -> LightingFrame? { frames.first }
}

final class HueSpatialFrameTests: XCTestCase {
    private func light(_ id: String) -> HueLight {
        HueLight(
            id: .init(rawValue: id), ownerID: nil, name: id,
            isOn: true, brightness: 45,
            color: .init(x: 0.3, y: 0.35), colorTemperatureMirek: nil,
            gamut: nil,
            capabilities: .init(
                power: true, dimming: true, color: true,
                colorTemperature: false, dynamicPalette: true
            ),
            outputLimit: 70, minimumBrightness: 5
        )
    }

    func testSpatialFrameHonorsSelectionPhaseAndOutputLimitsWithoutBridge() async throws {
        let first = light("a")
        let second = light("b")
        let area = HueArea(
            id: .init(rawValue: "synthetic-room"),
            kind: .room, name: "Synthetic room", lights: [first, second]
        )
        var layout = HueRoomLayout.startingLayout(for: area)
        layout.placements[0].phase = 0.70
        layout.placements[0].role = .accent
        layout.placements[0].trim = 0.5
        layout.placements[0].ceiling = 30
        layout.placements[1].selected = false

        let sampler = SyntheticHueSampler()
        let recorder = SyntheticFrameRecorder()
        let runner = NativeLiveRunner(engine: sampler)
        let contract = try HueBoardContractLoader.load()
        let safe = PhysicalLightSafetySettings(
            warningAcknowledged: true, reduceLightMotion: false,
            maximumDynamicBrightness: 90
        )
        do {
            try await runner.run(
                area: area, layout: layout,
                settings: HueEngineSettings(),
                cueSequence: nil, contract: contract,
                duration: 1, safetySettings: safe,
                submit: { frame in
                    await recorder.record(frame)
                    throw EndFixtureFrame.captured
                },
                progress: { _ in }
            )
            XCTFail("Synthetic sink should abort after one frame.")
        } catch EndFixtureFrame.captured {
            let recorded = await recorder.first()
            let frame = try XCTUnwrap(recorded)
            XCTAssertEqual(frame.actions.count, 1)
            XCTAssertNotNil(frame.actions[first.id])
            XCTAssertNil(frame.actions[second.id])
            XCTAssertEqual(frame.actions[first.id]?.dimming?.brightness, 30)
            let positions = await sampler.recordedPositions()
            XCTAssertEqual(positions.count, 1)
            XCTAssertEqual(positions.first ?? -1, 0.95, accuracy: 0.0001)
        }
    }

    func testCueExecutionUsesFirstPresetWithoutSpawningSecondWriter() async throws {
        let area = HueArea(
            id: .init(rawValue: "cue-room"), kind: .room,
            name: "Cue room", lights: [light("a")]
        )
        let layout = HueRoomLayout.startingLayout(for: area)
        let sampler = SyntheticHueSampler()
        let runner = NativeLiveRunner(engine: sampler)
        let contract = try HueBoardContractLoader.load()
        let presets = Array(contract.presets.prefix(2))
        let program = HueCueSequence(
            presetIDs: presets.map(\.id),
            holdSeconds: 30, order: .forward, seed: 7
        )
        let recorder = SyntheticFrameRecorder()
        let safe = PhysicalLightSafetySettings(
            warningAcknowledged: true, reduceLightMotion: false,
            maximumDynamicBrightness: 75
        )
        do {
            try await runner.run(
                area: area, layout: layout,
                settings: HueEngineSettings(), cueSequence: program,
                contract: contract, duration: 1, safetySettings: safe,
                submit: { frame in
                    await recorder.record(frame)
                    throw EndFixtureFrame.captured
                },
                progress: { _ in }
            )
            XCTFail("Synthetic sink should abort after one frame.")
        } catch EndFixtureFrame.captured {
            let patterns = await sampler.recordedPatterns()
            XCTAssertEqual(patterns.first, presets[0].pattern)
            let frame = await recorder.first()
            XCTAssertEqual(frame?.actions.count, 1)
        }
    }
}
