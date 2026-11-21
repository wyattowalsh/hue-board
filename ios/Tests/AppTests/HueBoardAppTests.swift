import XCTest
import HueBoardKit
import HueBoardNativeCore
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

    @MainActor
    func testRoomBrightnessUsesReadbackAndFixtureLimitsWithoutEditingStudio() async throws {
        let suite = "HueBoardRoomBrightness.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = RoomCommandRecorder()
        let model = AppModel(setupDefaults: defaults, persistence: AppPersistence(suiteName: suite),
                             directControlClient: recorder)
        func fixture(_ name: String, level: Double, on: Bool = true, ceiling: Double = 100,
                     minimum: Double = 1, streaming: Bool = false, canPower: Bool = true) -> HueLight {
            .init(id: .init(rawValue: name), ownerID: nil, name: name, isOn: on, brightness: level,
                  color: nil, colorTemperatureMirek: nil, gamut: nil,
                  capabilities: .init(power: canPower, dimming: true, color: false, colorTemperature: false,
                                      dynamicPalette: false, streaming: streaming),
                  outputLimit: ceiling, minimumBrightness: minimum)
        }
        let low = fixture("low", level: 20, ceiling: 35, minimum: 8)
        let high = fixture("high", level: 60)
        let off = fixture("off", level: 95, on: false)
        let room = HueArea(id: .init(rawValue: "room"), kind: .room, name: "Room", lights: [
            low, high, off, fixture("stream", level: 95, streaming: true),
            fixture("below-minimum", level: 95, ceiling: 10, minimum: 20), fixture("no-power", level: 95, canPower: false)
        ])
        XCTAssertEqual(room.initialRoomBrightness, 40)
        XCTAssertEqual(room.roomBrightnessActions(for: -10)[low.id]?.dimming?.brightness, 8)
        XCTAssertEqual(HueArea(id: room.id, kind: .room, name: room.name, lights: [off]).initialRoomBrightness, 50)

        let profile = try BridgeProfile(bridgeID: "001788fffe123456", host: "fixture.local")
        let scope = LightingScope(bridgeID: profile.bridgeID, areaID: room.id)
        model.profile = profile
        model.credential = .init(bridgeID: profile.bridgeID, applicationKey: "synthetic")
        model.connectionState = .ready
        model.areas = [room]
        model.selectedAreaID = room.id
        model.brightness = 76
        let studio = model.studioSceneSettings

        let stale = LightingScope(bridgeID: profile.bridgeID, areaID: .init(rawValue: "previous-room"))
        let staleResult = await model.setAreaBrightness(110, in: stale)
        let invalidResult = await model.setAreaBrightness(.nan, in: scope)
        XCTAssertNil(staleResult)
        XCTAssertNil(invalidResult)
        let writesBeforeApply = await recorder.actions
        XCTAssertTrue(writesBeforeApply.isEmpty)
        XCTAssertFalse(model.hasRestorePoint)

        let receipt = await model.setAreaBrightness(110, in: scope)
        XCTAssertEqual(receipt, "Bridge accepted brightness for 3 lights. Skipped 3.")
        let sent = await recorder.actions
        XCTAssertEqual(Set(sent.keys), [low.id, high.id, off.id])
        XCTAssertEqual(sent[low.id]?.dimming?.brightness, 35)
        XCTAssertEqual(sent[high.id]?.dimming?.brightness, 100)
        XCTAssertEqual(sent[off.id]?.on?.on, true)
        XCTAssertTrue(model.hasRestorePoint)
        XCTAssertEqual(model.brightness, 76)
        XCTAssertEqual(model.studioSceneSettings, studio)
    }

    @MainActor
    func testRestoreRequiresReconnectWhenSavedBridgeHasNoCredential() async throws {
        let model = AppModel()
        model.profile = try BridgeProfile(bridgeID: "001788fffe123456", host: "test-bridge.local")
        model.hasRestorePoint = true
        model.restoreAreaID = .init(rawValue: "test-room")
        let originalPlayback = model.playbackSnapshot

        XCTAssertFalse(model.canStopAndRestore)
        await model.stopAndRestore()

        XCTAssertEqual(model.errorMessage, "Reconnect the saved Bridge before trying to restore.")
        XCTAssertEqual(model.playbackSnapshot, originalPlayback)
        XCTAssertTrue(model.hasRestorePoint)
        XCTAssertEqual(model.restoreAreaID?.rawValue, "test-room")
        let lease = await model.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
    }

    @MainActor
    func testRestoreAvailabilityRequiresReadyConnectionAndMatchingRecoveryScope() throws {
        let model = AppModel()
        let profile = try BridgeProfile(bridgeID: "001788fffe123456", host: "test-bridge.local")
        model.profile = profile
        model.credential = .init(bridgeID: profile.bridgeID, applicationKey: "synthetic")

        model.connectionState = .connecting
        XCTAssertFalse(model.canStopAndRestore)
        model.connectionState = .ready
        XCTAssertTrue(model.canStopAndRestore)
        model.isBusy = true
        XCTAssertFalse(model.canStopAndRestore)
        model.isBusy = false
        model.emergencyOffInFlight = true
        XCTAssertFalse(model.canStopAndRestore)
        model.emergencyOffInFlight = false
        model.foreignRecoveryPending = true
        XCTAssertFalse(model.canStopAndRestore)
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

private actor RoomCommandRecorder: HueLightUpdateSending {
    private(set) var actions: [HueResourceID: HueLightAction] = [:]

    func updateLight(id: HueResourceID, action: HueLightAction, profile: BridgeProfile,
                     credential: HueBridgeCredential) async throws {
        actions[id] = action
    }
}
