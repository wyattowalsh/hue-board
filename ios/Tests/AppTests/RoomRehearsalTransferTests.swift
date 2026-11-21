#if DEBUG
import AVFoundation
import Foundation
import HueBoardKit
import HueBoardNativeCore
import XCTest
@testable import Hue_Board

@MainActor
final class RoomRehearsalTransferTests: XCTestCase {
    private struct Activity: Equatable {
        let writeAttempts: UInt64
        let writerAcquisitions: UInt64
        let journalMutations: UInt64

        init(_ model: AppModel) async {
            writeAttempts = await model.client.debugWriteAttempts
            writerAcquisitions = await model.playbackCoordinator.debugWriterAcquisitions
            journalMutations = await model.persistence.debugJournalMutations
        }
    }

    func testRecognizeRehearsePreviewAndMoveSetupWithoutPhysicalWrites() async throws {
        let sourceSuite = "HueBoard-Journey-Source-\(UUID().uuidString)"
        let destinationSuite = "HueBoard-Journey-Destination-\(UUID().uuidString)"
        let sourceDefaults = try XCTUnwrap(UserDefaults(suiteName: sourceSuite))
        let destinationDefaults = try XCTUnwrap(UserDefaults(suiteName: destinationSuite))
        defer {
            sourceDefaults.removePersistentDomain(forName: sourceSuite)
            destinationDefaults.removePersistentDomain(forName: destinationSuite)
        }
        let model = AppModel(setupDefaults: sourceDefaults, persistence: AppPersistence(suiteName: sourceSuite))
        let destination = AppModel(setupDefaults: destinationDefaults, persistence: AppPersistence(suiteName: destinationSuite))
        let sourceBefore = await Activity(model)
        let destinationBefore = await Activity(destination)
        let sample = StudioRehearsalRoom.sample
        let profile = try BridgeProfile(bridgeID: "001788fffe123456", host: "fixture.local")
        model.connectionState = .ready
        model.profile = profile
        model.credential = .init(bridgeID: profile.bridgeID, applicationKey: "fixture-only")
        model.areas = [sample.area]
        model.selectedAreaID = sample.area.id
        model.loadCurrentRoomLayout()
        let original = try XCTUnwrap(model.roomLayout)
        let scope = try XCTUnwrap(model.roomDiscoveryScope)
        let session = RoomDiscoverySession()
        var readCount = 0
        await session.read(scope: scope, revision: 0) { requested in
            XCTAssertEqual(requested, scope)
            readCount += 1
            let json = #"""
                [{"id":"fixture-entertainment-area","name":"Test layout","locations":{"service_locations":[
                  {"service":{"rid":"sample-0","rtype":"light"},"position":{"x":-1,"y":1,"z":0}}
                ]}}]
                """#
            let configurations = try JSONDecoder().decode([HueEntertainmentConfigurationResource].self, from: Data(json.utf8))
            return HueRoomDiscovery(configurations: configurations, services: [], in: sample.area)
        }
        guard case let .loaded(.matches(options, count)) = session.state else {
            return XCTFail("Expected a partially matching layout")
        }
        XCTAssertEqual(readCount, 1)
        XCTAssertEqual(count, 3)
        let option = try XCTUnwrap(options.first)
        XCTAssertEqual(option.matchedCount, 1)
        let preview = try model.previewRoomArrangement(option, from: scope)
        XCTAssertEqual(model.roomLayout, original)
        try model.saveRoomArrangement(preview)
        let saved = try XCTUnwrap(model.roomLayout)
        XCTAssertNotEqual(saved.placements[0].x, original.placements[0].x)
        XCTAssertEqual(saved.placements[0].phase, original.placements[0].phase)
        XCTAssertEqual(saved.placements.dropFirst(), original.placements.dropFirst())
        XCTAssertEqual(try model.roomLayoutStore.load(bridgeID: profile.bridgeID, area: sample.area), saved)

        model.selectedTab = .live
        model.cueIDs = ["ion-eclipse", "plasma-turbine"]
        model.isCueSequenceEnabled = true
        model.cueHoldSeconds = 30
        model.cueOrder = .forward
        let room = try XCTUnwrap(model.studioRehearsalRoom)
        let beforeBoundary = try await model.studioRehearsalFrame(model.studioRehearsalRequest(in: room, at: 29))
        let afterBoundary = try await model.studioRehearsalFrame(model.studioRehearsalRequest(in: room, at: 30))
        XCTAssertEqual(beforeBoundary.cue?.presetID, "ion-eclipse")
        XCTAssertEqual(afterBoundary.cue?.presetID, "plasma-turbine")
        XCTAssertEqual(Set(afterBoundary.targets.keys), Set(sample.area.lights.map(\.id)))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-silence-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writeStudioSilentFixture(to: url)
        model.studioLiveInput = .media
        model.studioMediaURL = url
        model.previewStudioInput(manualReadings: true)
        let deadline = ContinuousClock.now.advanced(by: .seconds(8))
        while !model.studioInputPreview.isIdle && ContinuousClock.now < deadline {
            if model.studioInputPreview.signal != nil, (model.studioMedia.player?.currentTime().seconds ?? 0) > 0 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertGreaterThan(model.studioMedia.player?.currentTime().seconds ?? 0, 0)
        let reading = model.studioInputPreview.signal
        XCTAssertEqual(reading?.level, 0, "The silent clip must produce a meter reading.")
        let suppressInput = model.safetySettings.reduceLightMotion || model.systemLightMotion.isEnabled
        let rehearsal = model.studioRehearsalRequest(in: room, at: 30)
        XCTAssertEqual(rehearsal.safety.reduceLightMotion, suppressInput)
        XCTAssertEqual(rehearsal.signal, suppressInput ? nil : reading)
        XCTAssertFalse(model.studioMicrophone.isCapturing)
        await model.studioInputPreview.stop()?.value
        XCTAssertNil(model.studioMedia.player)

        model.saveFavoritePresets(["plasma-turbine"])
        let chosen: Set<HueSetupSection> = [.draft, .cues, .favorites, .layout]
        let value = try model.exportSetup(sections: chosen)
        let data = try HuePortableDataCodec.encode(value, contract: model.contract)
        let setupURL = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-setup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: setupURL) }
        try data.write(to: setupURL, options: .atomic)
        let transferred = try HuePortableFile.read(from: setupURL)
        let decoded = try HuePortableDataCodec.decode(transferred, contract: destination.contract)
        guard case let .setup(setup) = decoded else { return XCTFail("Expected a setup file") }
        XCTAssertEqual(setup.availableSections, chosen)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(url.lastPathComponent))
        let review = try destination.reviewSetup(setup, sections: chosen)
        XCTAssertTrue(review.canApply)
        XCTAssertTrue(review.lines.contains { $0.contains("skipped") })
        XCTAssertTrue(destination.favoritePresetIDs.isEmpty)
        try await destination.applySetup(setup, sections: chosen, review: review)
        XCTAssertNil(destination.roomLayout)
        XCTAssertEqual(destination.cueIDs, model.cueIDs)
        XCTAssertEqual(destination.cueHoldSeconds, model.cueHoldSeconds)
        XCTAssertTrue(destination.isCueSequenceEnabled)
        XCTAssertEqual(destination.favoritePresetIDs, ["plasma-turbine"])
        let reopened = AppModel(setupDefaults: destinationDefaults, persistence: AppPersistence(suiteName: destinationSuite))
        XCTAssertEqual(reopened.favoritePresetIDs, destination.favoritePresetIDs)
        XCTAssertNil(reopened.roomLayout)

        let sourceAfter = await Activity(model)
        let destinationAfter = await Activity(destination)
        XCTAssertEqual(sourceAfter, sourceBefore)
        XCTAssertEqual(destinationAfter, destinationBefore)
        for candidate in [model, destination] {
            XCTAssertFalse(candidate.hasRestorePoint)
            let lease = await candidate.playbackCoordinator.currentLease()
            let idle = try await candidate.persistence.isIdleForLocalImport()
            XCTAssertNil(lease)
            XCTAssertTrue(idle)
        }
    }
}
#endif
