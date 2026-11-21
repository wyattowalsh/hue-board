#if DEBUG
import Foundation
import HueBoardKit
import HueBoardNativeCore
import XCTest
@testable import Hue_Board

@MainActor
final class EmergencyAndConsentAppTests: XCTestCase {
    func testInvalidDurationAndFirstUseConsentKeepStartupAndRecoveryIdle() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.model
        XCTAssertTrue(model.canStartLive)
        for invalid in [Double.nan, .infinity, 0, -1] {
            model.liveDuration = invalid
            await model.startNativeLive()
            XCTAssertNil(model.pendingDynamicAction)
            XCTAssertNil(model.liveStartupID)
            XCTAssertFalse(model.isBusy)
        }
        model.liveDuration = 300
        await model.startNativeLive()
        XCTAssertEqual(model.pendingDynamicAction, .ambient)
        XCTAssertTrue(model.isDynamicLightSafetyPresented)
        model.cancelDynamicLightSafety()
        let look = try XCTUnwrap(model.selectedPreset)
        await model.play(look)
        XCTAssertEqual(model.pendingDynamicAction, .bridge(presetID: look.id))
        model.cancelDynamicLightSafety()
        let acquisitions = await model.playbackCoordinator.debugWriterAcquisitions
        let writes = await model.client.debugWriteAttempts
        let journals = await model.persistence.debugJournalMutations
        XCTAssertEqual(acquisitions, 0)
        XCTAssertEqual(writes, 0)
        XCTAssertEqual(journals, 0)
        XCTAssertFalse(model.safetySettings.warningAcknowledged)
    }

    func testPendingForeignRecoveryPreemptsReviewedSetupWithoutSendingOff() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.model
        let setup = HueSetupDocument(favorites: ["ion-eclipse"])
        let review = try model.reviewSetup(setup, sections: [.favorites])
        let area = try XCTUnwrap(model.selectedArea)
        let foreign = RestoreJournal(bridgeID: "001788fffeabcdef", area: area, lights: area.lights)
        try await model.persistence.saveRestoreJournal(foreign)
        let original = try await model.persistence.loadRestoreJournal()

        let preempted = model.emergencyGeneration
        model.isBusy = true
        XCTAssertTrue(model.canTurnOffNow)
        await model.turnOffNow()
        XCTAssertTrue(model.foreignRecoveryPending)
        XCTAssertFalse(model.emergencyOffInFlight)
        XCTAssertFalse(model.canImportPortableData)
        let profile = try XCTUnwrap(model.profile)
        let credential = try XCTUnwrap(model.credential)
        let target = try XCTUnwrap(area.lights.first?.id)
        let writesBeforeResume = await model.playbackCoordinator.debugWriterAcquisitions
        do {
            try await model.executeDirectFrame([target: .init(on: .init(on: true))], profile: profile,
                credential: credential, areaID: area.id, purpose: "resumed-edit", generation: preempted)
            XCTFail("A pre-emergency direct intent must stay cancelled after Off has returned")
        } catch is CancellationError {}
        do {
            _ = try await model.beginDirectControl(profile: profile, credential: credential, areaID: area.id,
                allowedLightIDs: [target], purpose: "restore-baseline", generation: preempted)
            XCTFail("A stale restore must never reacquire the writer")
        } catch is CancellationError {}
        let writesAfterResume = await model.playbackCoordinator.debugWriterAcquisitions
        XCTAssertEqual(writesBeforeResume, writesAfterResume)
        do {
            try await model.applySetup(setup, sections: [.favorites], review: review)
            XCTFail("A review from before a pending baseline must no longer apply")
        } catch {
            XCTAssertTrue(model.favoritePresetIDs.isEmpty)
        }
        let retained = try await model.persistence.loadRestoreJournal()
        let writes = await model.client.debugWriteAttempts
        XCTAssertEqual(retained, original)
        XCTAssertEqual(writes, 0)
    }

    private struct Fixture {
        let suite = "HueBoard.EmergencyApp.\(UUID())"
        let model: AppModel

        @MainActor init() throws {
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            model = AppModel(setupDefaults: defaults, persistence: AppPersistence(suiteName: suite))
            let area = StudioRehearsalRoom.sample.area
            let profile = try BridgeProfile(bridgeID: "001788fffe123456", host: "fixture.local")
            model.profile = profile
            model.credential = .init(bridgeID: profile.bridgeID, applicationKey: "synthetic")
            model.connectionState = .ready
            model.areas = [area]
            model.selectedAreaID = area.id
            model.loadCurrentRoomLayout()
        }

        func cleanUp() { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
    }
}
#endif
