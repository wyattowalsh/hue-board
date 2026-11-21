import XCTest
import HueBoardKit
@testable import Hue_Board

final class HuePortableDataAppTests: XCTestCase {
    @MainActor
    func testStudioDraftTransferDoesNotAcquireWriterOrRequirePairing() async throws {
        let model = AppModel()
        let look = try XCTUnwrap(model.contract.presets.first)
        var settings = model.studioSceneSettings
        settings.brightness = 33
        settings.customColors = ["#AABBCC", "#010203", "#FFA321", "#101010"]
        settings.sequenceIds = [look.id]
        settings.sequenceHold = 75
        let file = HuePortableData.studioDraft(.init(
            settings: settings, sourceLookID: look.id, duration: 900, cuesEnabled: true
        ))
        let data = try HuePortableDataCodec.encode(file, contract: model.contract)
        let imported = try HuePortableDataCodec.decode(data, contract: model.contract)
        _ = try model.reviewPortableImport(imported)
        try await model.applyPortableImport(imported)

        XCTAssertFalse(model.isReady)
        XCTAssertEqual(model.brightness, 33)
        XCTAssertEqual(model.studioSettings.customColors, settings.customColors)
        XCTAssertEqual(model.cueIDs, [look.id])
        XCTAssertEqual(model.cueHoldSeconds, 75)
        XCTAssertEqual(model.liveDuration, 900)
        XCTAssertTrue(model.isCueSequenceEnabled)
        XCTAssertEqual(model.playbackSnapshot.mode, .idle)
        let lease = await model.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
    }

    @MainActor
    func testImportDuringRecoveryPreservesDraftAndRecoveryFlag() async throws {
        let model = AppModel()
        let initial = model.studioSettings.customColors
        model.hasRestorePoint = true
        let file = HuePortableData.customPalette(["#001100", "#DEADB0", "#666666", "#111111"])
        XCTAssertThrowsError(try model.reviewPortableImport(file))
        do {
            try await model.applyPortableImport(file)
            XCTFail("Recovery must prevent a settings import")
        } catch {
            XCTAssertEqual(model.studioSettings.customColors, initial)
            XCTAssertTrue(model.hasRestorePoint)
        }
    }
}
