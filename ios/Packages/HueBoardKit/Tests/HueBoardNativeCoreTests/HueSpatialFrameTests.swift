import Foundation
import XCTest
import HueBoardKit
@testable import HueBoardNativeCore

private enum EndFixtureFrame: Error { case captured }

private actor SyntheticHueSampler: HueEngineSampling {
    private let brightness: Double
    private var positions: [Double] = []
    private var times: [Double] = []
    private var patterns: [String] = []
    private var colors: [RGB] = []

    init(brightness: Double = 80) {
        self.brightness = brightness
    }

    func sample(
        time: Double,
        position: Double,
        settings: HueEngineSettings,
        surge: Double
    ) async throws -> HueLightFrame {
        times.append(time)
        positions.append(position)
        patterns.append(settings.showA)
        return HueLightFrame(
            color: RGB(red: 0.1, green: 0.3, blue: 0.7),
            brightness: brightness
        )
    }

    func xy(_ color: RGB, gamut: HueGamut?) async throws -> HueXY {
        colors.append(color)
        return .init(x: 0.3, y: 0.35)
    }

    func recordedTimes() -> [Double] { times }
    func recordedPositions() -> [Double] { positions }
    func recordedPatterns() -> [String] { patterns }
    func recordedColors() -> [RGB] { colors }
}

private actor SyntheticFrameRecorder {
    private var frames: [LightingFrame] = []

    func record(_ frame: LightingFrame) {
        frames.append(frame)
    }
    func first() -> LightingFrame? { frames.first }
    func count() -> Int { frames.count }
}

private actor SyntheticSignalSource {
    let signal: HueLiveSignal
    private var times: [TimeInterval] = []

    init(_ signal: HueLiveSignal) { self.signal = signal }

    func sample(at elapsed: TimeInterval) -> HueLiveSignal {
        times.append(elapsed)
        return signal
    }

    func sampleTimes() -> [TimeInterval] { times }
}

final class HueSpatialFrameTests: XCTestCase {
    private func light(_ id: String, minimum: Double = 5) -> HueLight {
        HueLight(
            id: .init(rawValue: id), ownerID: nil, name: id,
            isOn: true, brightness: 45,
            color: .init(x: 0.3, y: 0.35), colorTemperatureMirek: nil,
            gamut: nil,
            capabilities: .init(
                power: true, dimming: true, color: true,
                colorTemperature: false, dynamicPalette: true
            ),
            outputLimit: 70, minimumBrightness: minimum
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

    func testLiveSignalUsesOneSampleAndPreservesStaticFixturesAndOutputCaps() async throws {
        let wash = light("wash")
        let task = light("task")
        let accent = light("accent")
        let area = HueArea(
            id: .init(rawValue: "signal-room"), kind: .room,
            name: "Signal room", lights: [wash, task, accent]
        )
        var layout = HueRoomLayout.startingLayout(for: area)
        layout.placements[1].role = .task
        layout.placements[2].role = .accent
        layout.placements[2].ceiling = 52
        let source = SyntheticSignalSource(
            HueLiveSignal(level: 1, color: RGB(red: 0.9, green: 0.1, blue: 0.2))
        )
        let sampler = SyntheticHueSampler(brightness: 50)

        let frame = try await captureSignalFrame(
            area: area, layout: layout, sampler: sampler, source: source,
            masterBrightness: 70, safety: .init(maximumDynamicBrightness: 55)
        )
        let times = await source.sampleTimes()
        XCTAssertEqual(times.count, 1)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(times.first), 0)
        XCTAssertEqual(frame.actions[wash.id]?.dimming?.brightness, 55)
        XCTAssertEqual(frame.actions[task.id]?.dimming?.brightness, 50)
        XCTAssertEqual(frame.actions[accent.id]?.dimming?.brightness, 52)
        XCTAssertTrue(frame.actions.values.allSatisfy { $0.dynamics?.duration == 4_500 })
        let colors = await sampler.recordedColors()
        XCTAssertEqual(colors.count, 3)
        let tinted = try XCTUnwrap(colors.first)
        XCTAssertEqual(tinted.red, 0.244, accuracy: 0.0001)
        XCTAssertEqual(tinted.green, 0.264, accuracy: 0.0001)
        XCTAssertEqual(tinted.blue, 0.61, accuracy: 0.0001)
        XCTAssertEqual(colors.dropFirst().first, RGB(red: 0.1, green: 0.3, blue: 0.7))
        XCTAssertEqual(colors.last, tinted)
    }

    func testReduceLightMotionSkipsSignalAndKeepsLongTransition() async throws {
        let fixture = light("a")
        let area = HueArea(
            id: .init(rawValue: "steady-room"), kind: .room,
            name: "Steady room", lights: [fixture]
        )
        let layout = HueRoomLayout.startingLayout(for: area)
        let source = SyntheticSignalSource(
            HueLiveSignal(level: 1, color: RGB(red: 1, green: 0, blue: 0))
        )
        let sampler = SyntheticHueSampler(brightness: 50)

        let frame = try await captureSignalFrame(
            area: area, layout: layout, sampler: sampler, source: source,
            masterBrightness: 65,
            safety: .init(reduceLightMotion: true, maximumDynamicBrightness: 85)
        )
        let times = await source.sampleTimes()
        XCTAssertTrue(times.isEmpty)
        XCTAssertEqual(frame.actions[fixture.id]?.dimming?.brightness, 50)
        XCTAssertEqual(frame.actions[fixture.id]?.dynamics?.duration, 8_000)
        let colors = await sampler.recordedColors()
        XCTAssertEqual(colors, [RGB(red: 0.1, green: 0.3, blue: 0.7)])
    }

    func testLiveSignalCannotExceedMasterBrightness() async throws {
        let fixture = light("a")
        let area = HueArea(
            id: .init(rawValue: "master-room"), kind: .room,
            name: "Master room", lights: [fixture]
        )
        let frame = try await captureSignalFrame(
            area: area, layout: .startingLayout(for: area),
            sampler: SyntheticHueSampler(brightness: 50),
            source: SyntheticSignalSource(HueLiveSignal(level: 1)),
            masterBrightness: 53, safety: .init(maximumDynamicBrightness: 85)
        )
        XCTAssertEqual(frame.actions[fixture.id]?.dimming?.brightness, 53)
    }

    func testLiveSignalNormalizesNonfiniteAndOutOfRangeInput() {
        XCTAssertEqual(HueLiveSignal(level: .infinity).level, 0)
        XCTAssertEqual(HueLiveSignal(level: -.infinity).level, 0)
        XCTAssertEqual(HueLiveSignal(level: -1).level, 0)
        XCTAssertEqual(HueLiveSignal(level: 2).level, 1)
        XCTAssertEqual(
            HueLiveSignal(level: .nan, color: RGB(red: .nan, green: 0, blue: 0)),
            HueLiveSignal(level: 0)
        )
        XCTAssertEqual(
            HueLiveSignal(level: 0, color: RGB(red: 2, green: -1, blue: 0.5)).color,
            RGB(red: 1, green: 0, blue: 0.5)
        )
    }

    func testCancellationWhileSamplingInputPreventsFirstWrite() async throws {
        let area = HueArea(
            id: .init(rawValue: "cancel-input-room"), kind: .room,
            name: "Cancel input room", lights: [light("a")]
        )
        let layout = HueRoomLayout.startingLayout(for: area)
        let contract = try HueBoardContractLoader.load()
        let recorder = SyntheticFrameRecorder()
        let runner = NativeLiveRunner(engine: SyntheticHueSampler())
        let session = Task {
            try await runner.run(
                area: area, layout: layout,
                settings: HueEngineSettings(), cueSequence: nil,
                contract: contract, duration: 1, safetySettings: .default,
                signal: { _ in
                    withUnsafeCurrentTask { task in task?.cancel() }
                    return HueLiveSignal(level: 1)
                },
                submit: { frame in await recorder.record(frame) },
                progress: { _ in }
            )
        }

        do {
            try await session.value
            XCTFail("Cancellation while sampling input must end the session.")
        } catch is CancellationError {
            let writes = await recorder.count()
            XCTAssertEqual(writes, 0)
        }
    }

    func testInterruptedLiveRunStopsSubmittingAndAllowsExplicitRestart() async throws {
        let area = HueArea(
            id: .init(rawValue: "interruption-room"), kind: .room,
            name: "Interruption room", lights: [light("a")]
        )
        let layout = HueRoomLayout.startingLayout(for: area)
        let contract = try HueBoardContractLoader.load()
        let safety = PhysicalLightSafetySettings.default
        let recorder = SyntheticFrameRecorder()
        let runner = NativeLiveRunner(engine: SyntheticHueSampler())

        let session = Task {
            try await runner.run(
                area: area, layout: layout,
                settings: HueEngineSettings(), cueSequence: nil,
                contract: contract, duration: 1, safetySettings: safety,
                submit: { frame in await recorder.record(frame) },
                progress: { _ in
                    withUnsafeCurrentTask { task in task?.cancel() }
                }
            )
        }
        do {
            try await session.value
            XCTFail("The interrupted session must report cancellation.")
        } catch is CancellationError {
            let count = await recorder.count()
            XCTAssertEqual(count, 1)
        }

        do {
            try await runner.run(
                area: area, layout: layout,
                settings: HueEngineSettings(), cueSequence: nil,
                contract: contract, duration: 1, safetySettings: safety,
                submit: { frame in
                    await recorder.record(frame)
                    throw EndFixtureFrame.captured
                },
                progress: { _ in }
            )
            XCTFail("The restarted session must reach the synthetic frame sink.")
        } catch EndFixtureFrame.captured {
            let count = await recorder.count()
            XCTAssertEqual(count, 2)
        }
    }

    func testRehearsalAndLiveExcludeHardwareFloorAboveMasterAndIncludeEquality() async throws {
        let area = HueArea(
            id: .init(rawValue: "floor"), kind: .room, name: "Floor",
            lights: [light("eligible", minimum: 15), light("ineligible", minimum: 20)]
        )
        let layout = HueRoomLayout.startingLayout(for: area)
        let safety = PhysicalLightSafetySettings(maximumDynamicBrightness: 80)
        let planner = try StudioFramePlanner(
            area: area, layout: layout, settings: .init(brightness: 15), cueSequence: nil,
            contract: HueBoardContractLoader.load(), safety: safety
        )
        XCTAssertEqual(planner.fixtureCount, 1)
        let eligible = area.lights[0].id
        let signal = HueLiveSignal(level: 1)
        let forecast = try await planner.frame(
            at: 0, duration: 5, signal: signal, engine: SyntheticHueSampler(brightness: 6)
        )
        let sent = try await captureSignalFrame(
            area: area, layout: layout, sampler: SyntheticHueSampler(brightness: 6),
            source: SyntheticSignalSource(signal), masterBrightness: 15, safety: safety
        )
        XCTAssertEqual(Set(forecast.targets.keys), [eligible])
        XCTAssertEqual(Set(sent.actions.keys), [eligible])
        XCTAssertEqual(forecast.targets[eligible]?.brightness, 15)
        XCTAssertEqual(sent.actions[eligible]?.dimming?.brightness, forecast.targets[eligible]?.brightness)
        XCTAssertEqual(sent.actions[eligible]?.color?.xy, forecast.targets[eligible]?.xy)
        XCTAssertEqual(sent.actions[eligible]?.dynamics?.duration, planner.transitionMilliseconds)

        let empty = layout.selectedEntries(in: area, brightnessLimit: 14)
        XCTAssertTrue(empty.isEmpty)
        let recorder = SyntheticFrameRecorder()
        do {
            try await NativeLiveRunner(engine: SyntheticHueSampler()).run(
                area: area, layout: layout, settings: .init(brightness: 14),
                cueSequence: nil, contract: HueBoardContractLoader.load(), duration: 5,
                safetySettings: safety, submit: { await recorder.record($0) }, progress: { _ in }
            )
            XCTFail("An ineligible room must not start")
        } catch HueBoardError.unsupported { }
        let count = await recorder.count()
        XCTAssertEqual(count, 0)
    }

    func testRehearsalKeepsCoincidentFixturesSeparateAndUsesCueLocalTime() async throws {
        let area = HueArea(
            id: .init(rawValue: "coincident"), kind: .room, name: "Coincident",
            lights: [light("wash"), light("accent"), light("anchor")]
        )
        var layout = HueRoomLayout.startingLayout(for: area)
        for i in layout.placements.indices {
            layout.placements[i].x = 0.5
            layout.placements[i].y = 0.5
        }
        layout.placements[0].phase = 0.4
        layout.placements[1].phase = 0.8
        layout.placements[1].role = .accent
        layout.placements[2].phase = 0.2
        layout.placements[2].role = .anchor
        let contract = try HueBoardContractLoader.load()
        let presets = Array(contract.presets.prefix(2))
        let cues = HueCueSequence(presetIDs: presets.map(\.id), holdSeconds: 30, order: .forward, seed: 5)
        let planner = try StudioFramePlanner(
            area: area, layout: layout, settings: .init(), cueSequence: cues, contract: contract, safety: .default
        )
        let sampler = SyntheticHueSampler()
        let first = try await planner.frame(at: 29.999, duration: 60, signal: nil, engine: sampler)
        let next = try await planner.frame(at: 30, duration: 60, signal: nil, engine: sampler)
        let end = try await planner.frame(at: 60, duration: 60, signal: nil, engine: sampler)
        XCTAssertEqual(first.targets.count, 3)
        XCTAssertEqual(first.cue?.presetID, presets[0].id)
        XCTAssertEqual(next.cue?.presetID, presets[1].id)
        XCTAssertEqual(next.cue?.slotElapsed, 0)
        XCTAssertTrue(end.ended)
        XCTAssertNil(end.cue)
        XCTAssertTrue(end.targets.isEmpty)
        let positions = await sampler.recordedPositions()
        let times = await sampler.recordedTimes()
        XCTAssertEqual(times, [29.999 * presets[0].speed, 29.999 * presets[0].speed, 0, 0, 0, 0])
        XCTAssertEqual(positions.count, 6)
        for (value, expected) in zip(positions, [0.4, 0.05, 0.2, 0.4, 0.05, 0.2]) {
            XCTAssertEqual(value, expected, accuracy: 1e-10)
        }
        let rewound = try await planner.frame(at: 29.999, duration: 60, signal: nil, engine: sampler)
        XCTAssertEqual(rewound, first)
    }

    private func captureSignalFrame(
        area: HueArea,
        layout: HueRoomLayout,
        sampler: SyntheticHueSampler,
        source: SyntheticSignalSource,
        masterBrightness: Double,
        safety: PhysicalLightSafetySettings
    ) async throws -> LightingFrame {
        let recorder = SyntheticFrameRecorder()
        let runner = NativeLiveRunner(engine: sampler)
        let contract = try HueBoardContractLoader.load()
        do {
            try await runner.run(
                area: area, layout: layout,
                settings: HueEngineSettings(brightness: masterBrightness),
                cueSequence: nil, contract: contract, duration: 1, safetySettings: safety,
                signal: { await source.sample(at: $0) },
                submit: { frame in
                    await recorder.record(frame)
                    throw EndFixtureFrame.captured
                },
                progress: { _ in }
            )
        } catch EndFixtureFrame.captured {}
        let frame = await recorder.first()
        return try XCTUnwrap(frame)
    }
}
