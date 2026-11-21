import XCTest
import HueBoardKit
import HueBoardNativeCore
@testable import Hue_Board

private struct FirstSweepFrame: Error { let value: LightingFrame }

@MainActor
final class SweepRehearsalTests: XCTestCase {
    func testSavedSweepDrivesIdenticalRehearsalAndCapturedLiveTargets() async throws {
        let suite = "hue-sweep-frame-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HueRoomLayoutStore(defaults: defaults)
        let area = StudioRehearsalRoom.sample.area
        let profile = try BridgeProfile(bridgeID: "0000000000000002", host: "fixture.local")
        func loadModel() -> AppModel {
            let model = AppModel(roomLayoutStore: store)
            model.profile = profile
            model.credential = .init(bridgeID: profile.bridgeID, applicationKey: "fixture")
            model.connectionState = .ready
            model.areas = [area]
            model.selectedAreaID = area.id
            model.loadCurrentRoomLayout()
            return model
        }

        var manual = HueRoomLayout.startingLayout(for: area)
        let xCoordinates = [0.9, 0.1, 0.5]
        for index in manual.placements.indices {
            manual.placements[index].x = xCoordinates[index]
            manual.placements[index].phase = 0.86
        }
        manual.placements[1].trim = 0.6
        try store.save(manual, bridgeID: profile.bridgeID, area: area)
        let editor = loadModel()
        let proposal = try editor.previewRoomSweep()
        XCTAssertEqual(try store.load(bridgeID: profile.bridgeID, area: area), manual)
        try editor.saveRoomSweep(proposal)

        let player = loadModel()
        // Freeze movement to sample the same engine instant in both execution paths.
        player.studioSettings.speed = 0
        let room = try XCTUnwrap(player.studioRehearsalRoom)
        let phases = [2.0 / 3, 0, 1.0 / 3]
        XCTAssertEqual(room.layout.placements.map(\.phase), phases)
        let request = player.studioRehearsalRequest(in: room, at: 0)
        let rehearsal = try await player.studioRehearsalFrame(request)
        let runner = NativeLiveRunner(engine: player.engine)
        do {
            try await runner.run(
                area: room.area, layout: room.layout, settings: request.settings,
                cueSequence: request.cues, contract: player.contract, duration: request.duration,
                safetySettings: request.safety, submit: { throw FirstSweepFrame(value: $0) }, progress: { _ in }
            )
            XCTFail("Expected the fake transport to capture the first Live frame")
        } catch let captured as FirstSweepFrame {
            let expectedIDs = Set(area.lights.map(\.id))
            XCTAssertEqual(Set(rehearsal.targets.keys), expectedIDs)
            XCTAssertEqual(Set(captured.value.actions.keys), expectedIDs)
            let settings = PhysicalLightSafetyPolicy.adjustedEngineSettings(request.settings, safety: request.safety)
            for (index, light) in area.lights.enumerated() {
                let sample = try await player.engine.sample(time: 0, position: phases[index], settings: settings, surge: 0)
                let expectedXY = try await player.engine.xy(sample.color, gamut: light.gamut)
                let trimmed = try XCTUnwrap(manual.placements[index].brightness(for: sample.brightness, light: light))
                let expectedBrightness = min(trimmed, settings.brightness)
                let target = try XCTUnwrap(rehearsal.targets[light.id])
                let action = try XCTUnwrap(captured.value.actions[light.id])
                XCTAssertEqual(target.color, sample.color)
                XCTAssertEqual(target.xy, expectedXY)
                XCTAssertEqual(target.brightness, expectedBrightness, accuracy: 1e-10)
                XCTAssertEqual(action.color?.xy, target.xy)
                XCTAssertEqual(try XCTUnwrap(action.dimming?.brightness), target.brightness, accuracy: 1e-10)
            }
        }
        let lease = await player.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
        XCTAssertFalse(player.hasRestorePoint)
    }
}
