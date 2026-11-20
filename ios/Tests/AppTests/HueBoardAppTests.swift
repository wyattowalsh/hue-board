import XCTest
import HueBoardKit
@testable import Hue_Board

final class HueBoardAppTests: XCTestCase {
    @MainActor
    func testFreshModelStartsDisconnectedWithoutWriterOwnership() async {
        let model = AppModel()
        XCTAssertEqual(model.connectionState, .disconnected)
        XCTAssertFalse(model.isReady)
        let lease = await model.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
    }

    @MainActor
    func testLoadingStudioPresetNeverStartsPhysicalWriter() async throws {
        let model = AppModel()
        let preset = try XCTUnwrap(model.contract.presets.first)
        model.loadPresetIntoStudio(preset)
        XCTAssertEqual(model.studioSettings.showA, preset.pattern)
        XCTAssertEqual(model.studioSettings.paletteA, preset.palette)
        let lease = await model.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
    }

    @MainActor
    func testDisconnectedPerLightEditsNeverStartPhysicalWriter() async {
        let model = AppModel()
        await model.setLightPower(.init(rawValue: "light-one"), on: true)
        XCTAssertNotNil(model.errorMessage)
        let lease = await model.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
    }

    func testStudioLibraryRoundTripsCanonicalScopeFreeDocument() throws {
        let suite = "HueBoardStudioTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StudioDocumentStore(defaults: defaults)
        let contract = try HueBoardContractLoader.load()
        let preset = try XCTUnwrap(contract.presets.first)
        let settings = HueSceneSettings(
            engineSettings: HueEngineSettings.from(preset: preset)
        )
        let document = HueSceneDocumentCodec.makeDocument(
            name: "Night pulse",
            settings: settings,
            source: .init(productVersion: contract.release, implementation: "native")
        )
        try store.save([document], contract: contract)
        XCTAssertEqual(try store.load(contract: contract), [document])
        XCTAssertEqual(document.scope, .userSelected)
        XCTAssertEqual(document.settings.nativeEngineSettings.showA, preset.pattern)
    }

    func testInvalidLibraryIsNotSilentlyDiscarded() throws {
        let suite = "HueBoardStudioCorrupt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StudioDocumentStore(defaults: defaults)
        let corrupt = Data("malformed".utf8)
        defaults.set(corrupt, forKey: "hue-board.native.studio-documents.v1")
        let contract = try HueBoardContractLoader.load()
        XCTAssertThrowsError(try store.load(contract: contract))
        XCTAssertEqual(
            defaults.data(forKey: "hue-board.native.studio-documents.v1"),
            corrupt
        )
    }
}
