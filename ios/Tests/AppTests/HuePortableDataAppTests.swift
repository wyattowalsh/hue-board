import XCTest
import HueBoardKit
import HueBoardNativeCore
@testable import Hue_Board

final class HuePortableDataAppTests: XCTestCase {
    @MainActor
    func testFavoritesImportReportsStorageFailureAndPreservesExistingStars() async throws {
        let name = "HueBoard.FavoritesImport." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = AppModel(setupDefaults: defaults, persistence: AppPersistence(suiteName: name))
        try await model.applyPortableImport(.favorites(["plasma-turbine"]))
        let replacement = HuePortableData.favorites(["ion-eclipse"])
        _ = try model.reviewPortableImport(replacement)

        let record = "hue-board.native.setup-import-transaction.v1"
        defaults.set("unreadable", forKey: record)
        do {
            try await model.applyPortableImport(replacement)
            XCTFail("A failed favorites write must keep the file in review")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("unreadable"))
        }
        XCTAssertEqual(model.favoritePresetIDs, ["plasma-turbine"])
        XCTAssertNil(model.errorMessage)

        model.toggleFavoritePreset("ion-eclipse")
        XCTAssertTrue(model.errorMessage?.contains("Could not save favorites") == true)
        XCTAssertEqual(model.favoritePresetIDs, ["plasma-turbine"])
        XCTAssertEqual(defaults.stringArray(forKey: SetupImportTransaction.Section.favorites.preferenceKey), ["plasma-turbine"])
        XCTAssertEqual(defaults.string(forKey: record), "unreadable")
    }

    @MainActor
    func testStudioDraftTransferDoesNotAcquireWriterOrRequirePairing() async throws {
        let name = "HueBoard.OfflinePortableDraft." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = AppModel(setupDefaults: defaults, persistence: AppPersistence(suiteName: name))
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
    func testSingleFileSafetyImportAfterUnpairedColdLaunchHonorsMigratedRecovery() async throws {
        // Both installs take the normal offline bootstrap path. Only one has legacy recovery to preserve.
        for pending in [false, true] {
            let name = "HueBoard.ColdPortableImport." + UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
            defer { defaults.removePersistentDomain(forName: name) }
            let settings = PhysicalLightSafetySettings(warningAcknowledged: true, reduceLightMotion: true,
                                                      maximumDynamicBrightness: 30)
            try PhysicalLightSafetyStore.saveSynchronously(settings, defaults: defaults)
            if pending {
                let light = HueLight(id: .init(rawValue: "synthetic-light"), ownerID: nil, name: "Fixture",
                                     isOn: true, brightness: 24, color: nil, colorTemperatureMirek: nil, gamut: nil,
                                     capabilities: .init(power: true, dimming: true, color: false,
                                                         colorTemperature: false, dynamicPalette: false))
                let area = HueArea(id: .init(rawValue: "synthetic-area"), kind: .room, name: "Test", lights: [light])
                let journal = RestoreJournal(bridgeID: "001788fffe000001", area: area, lights: [light],
                                             createdAt: Date(timeIntervalSince1970: 1_700_000_000))
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                defaults.set(try encoder.encode(journal), forKey: "hue-board.native.restore-journal.v1")
            }
            let model = AppModel(setupDefaults: defaults, persistence: AppPersistence(suiteName: name))
            await model.bootstrap()
            XCTAssertNil(model.profile)
            XCTAssertFalse(model.hasRestorePoint)
            let safetyKey = SetupImportTransaction.Section.safety.preferenceKey
            let recoveryKey = "hue-board.native.recovery.v2"
            let oldSafety = try XCTUnwrap(defaults.data(forKey: safetyKey))
            let oldRecovery = defaults.data(forKey: recoveryKey)
            XCTAssertEqual(oldRecovery != nil, pending)

            let file = Data(#"{"format":"hue-board.native-data","schema":1,"kind":"safety","payload":{"reduceLightMotion":false,"maximumDynamicBrightness":72}}"#.utf8)
            let imported = try HuePortableDataCodec.decodeForReview(file, contract: model.contract)
            _ = try model.reviewPortableImport(imported)
            if pending {
                do {
                    try await model.applyPortableImport(imported.value)
                    XCTFail("The retained recovery journal must block a safety-settings import")
                } catch {
                    XCTAssertTrue(error.localizedDescription.contains("recovery"))
                }
                XCTAssertEqual(defaults.data(forKey: safetyKey), oldSafety)
                XCTAssertEqual(model.safetySettings, settings)
            } else {
                try await model.applyPortableImport(imported.value)
                XCTAssertEqual(model.safetySettings.maximumDynamicBrightness, 72)
                XCTAssertFalse(model.safetySettings.reduceLightMotion)
                XCTAssertTrue(model.safetySettings.warningAcknowledged)
                XCTAssertEqual(PhysicalLightSafetyStore.loadSynchronously(defaults: defaults), model.safetySettings)
            }
            XCTAssertEqual(defaults.data(forKey: recoveryKey), oldRecovery)
            let lease = await model.playbackCoordinator.currentLease()
            XCTAssertNil(lease)
        }
    }

    @MainActor
    func testFilesReviewExplainsLegacySubstitutionsBeforeSaving() throws {
        let name = "HueBoard.LegacyReview." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = AppModel(setupDefaults: defaults)
        let raw = Data(##"{"app":"hue-board","schema":3,"settings":{"brightness":150,"customColors":["#bad"]}}"##.utf8)
        let imported = try HuePortableDataCodec.decodeForReview(raw, contract: model.contract)
        let message = try model.reviewPortableImport(imported)
        XCTAssertTrue(message.contains("1 new mix"))
        XCTAssertTrue(message.contains("Clamped brightness to the supported range."))
        XCTAssertTrue(message.contains("Replaced invalid custom colors with defaults."))
        XCTAssertEqual(try model.reviewPortableImport(imported), message)
        XCTAssertTrue(model.savedStudioDocuments.isEmpty)
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
