import Foundation
import HueBoardKit
import HueBoardNativeCore
import XCTest
@testable import Hue_Board

final class HueSetupFlowTests: XCTestCase {
    private struct Fixture {
        let model: AppModel
        let defaults: UserDefaults
        let name: String

        @MainActor init() throws {
            name = "HueBoard.SetupFlowTests." + UUID().uuidString
            defaults = try XCTUnwrap(UserDefaults(suiteName: name))
            model = AppModel(setupDefaults: defaults, persistence: AppPersistence(suiteName: name))
        }

        func cleanUp() { defaults.removePersistentDomain(forName: name) }
    }

    @MainActor
    func testUnpairedImportSkipsForeignLayoutAndPublishesOnlySelectedDraftFields() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.model
        let oldBrightness = model.brightness
        let oldDuration = model.liveDuration
        let colors = ["#123456", "#ABCDEF", "#112233", "#445566"]
        let setup = HueSetupDocument(palette: colors, layout: .init(
            scope: String(repeating: "a", count: 64), layout: .init(areaID: .init(rawValue: "synthetic-room"), placements: [])
        ))
        let review = try model.reviewSetup(setup, sections: setup.availableSections)
        XCTAssertTrue(review.lines.contains { $0.contains("skipped") })
        XCTAssertTrue(review.canApply)
        try await model.applySetup(setup, sections: setup.availableSections, review: review)
        XCTAssertEqual(model.studioSettings.customColors, colors)
        XCTAssertEqual(model.brightness, oldBrightness)
        XCTAssertEqual(model.liveDuration, oldDuration)
        XCTAssertFalse(model.hasRestorePoint)
        XCTAssertNil(model.roomLayout)
        let lease = await model.playbackCoordinator.currentLease()
        XCTAssertNil(lease)
    }

    @MainActor
    func testChangedDraftWithIdenticalReviewTextInvalidatesConfirmation() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.model
        let originalColors = model.studioSettings.customColors
        let setup = HueSetupDocument(palette: ["#000001", "#000002", "#000003", "#000004"])
        let review = try model.reviewSetup(setup, sections: [.palette])
        model.brightness = model.brightness == 50 ? 51 : 50
        XCTAssertEqual(try model.reviewSetup(setup, sections: [.palette]).lines, review.lines)
        do {
            try await model.applySetup(setup, sections: [.palette], review: review)
            XCTFail("A stale confirmation was accepted")
        } catch {
            XCTAssertEqual(model.studioSettings.customColors, originalColors)
        }
        model.hasRestorePoint = true
        XCTAssertThrowsError(try model.reviewSetup(setup, sections: [.palette]))
    }

    @MainActor
    func testExportOmitsUnselectedPrivateSectionsAndMedia() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.model
        let value = try model.exportSetup(sections: [.draft, .palette, .cues, .favorites])
        guard case .setup(let setup) = value else { return XCTFail("Expected a setup") }
        XCTAssertNil(setup.safety)
        XCTAssertNil(setup.layout)
        let encoded = try HuePortableDataCodec.encode(value, contract: model.contract)
        let json = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(json.contains("mediaURL"))
        XCTAssertFalse(json.contains("bridgeID"))
        XCTAssertFalse(json.contains("recovery"))
    }


    @MainActor
    func testSameFixtureIDsOnAnotherBridgeCannotRemapTheImportedLayout() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.model
        let light = HueLight(id: .init(rawValue: "same-light"), ownerID: nil, name: "Test lamp",
                             isOn: true, brightness: 60, color: nil, colorTemperatureMirek: nil,
                             gamut: nil, capabilities: .init(power: true, dimming: true, color: true,
                                                            colorTemperature: false, dynamicPalette: false))
        let area = HueArea(id: .init(rawValue: "same-room"), kind: .room, name: "Test room", lights: [light])
        let sourceBridge = "001788fffe000001"
        model.areas = [area]
        model.selectedAreaID = area.id
        model.connectionState = .ready
        model.profile = try BridgeProfile(bridgeID: sourceBridge, host: "hue-test.local")
        model.credential = .init(bridgeID: sourceBridge, applicationKey: "synthetic")
        model.roomLayout = .startingLayout(for: area)
        model.roomLayout?.placements[0].ceiling = 85
        guard case .setup(let setup) = try model.exportSetup(sections: [.layout, .palette]) else {
            return XCTFail("Expected setup")
        }

        let otherBridge = "001788fffe000002"
        model.profile = try BridgeProfile(bridgeID: otherBridge, host: "other-test.local")
        model.credential = .init(bridgeID: otherBridge, applicationKey: "synthetic")
        model.roomLayout?.placements[0].ceiling = 35
        let skipped = try model.reviewSetup(setup, sections: [.layout, .palette])
        XCTAssertTrue(skipped.lines.contains { $0.contains("skipped") })
        try await model.applySetup(setup, sections: [.layout, .palette], review: skipped)
        XCTAssertEqual(model.roomLayout?.placements[0].ceiling, 35)

        model.profile = try BridgeProfile(bridgeID: sourceBridge, host: "hue-test.local")
        model.credential = .init(bridgeID: sourceBridge, applicationKey: "synthetic")
        let matched = try model.reviewSetup(setup, sections: [.layout])
        XCTAssertTrue(matched.lines.contains { $0.contains("Test lamp") && $0.contains("35%") && $0.contains("85%") })
        try await model.applySetup(setup, sections: [.layout], review: matched)
        XCTAssertEqual(model.roomLayout?.placements[0].ceiling, 85)
        let saved = try model.roomLayoutStore.load(bridgeID: sourceBridge, area: area)
        XCTAssertEqual(saved.placements[0].ceiling, 85)
    }

    @MainActor
    func testConflictingMixBlocksSelectedSectionsAndExistingConsentSurvives() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.model
        let source = HueSceneDocumentSource(productVersion: model.contract.release, implementation: "native")
        let existing = HueSceneDocumentCodec.makeDocument(name: "Existing", settings: .init(), source: source)
        let conflict = HueSceneDocumentCodec.makeDocument(name: "Imported", settings: .init(), source: source,
                                                         documentId: existing.documentId)
        try model.studioDocumentStore.save([existing], contract: model.contract)
        model.savedStudioDocuments = [existing]
        model.safetySettings = .init(warningAcknowledged: true, reduceLightMotion: true, maximumDynamicBrightness: 50)
        try PhysicalLightSafetyStore.saveSynchronously(model.safetySettings, defaults: fixture.defaults)
        let setup = HueSetupDocument(mixes: [conflict], safety: .init(reduceLightMotion: false, maximumDynamicBrightness: 65))
        let blocked = try model.reviewSetup(setup, sections: setup.availableSections)
        XCTAssertFalse(blocked.canApply)
        XCTAssertTrue(blocked.lines.contains { $0.contains("Existing") && $0.contains("Imported") })
        do {
            try await model.applySetup(setup, sections: setup.availableSections, review: blocked)
            XCTFail("A conflicted section was committed")
        } catch {
            XCTAssertEqual(model.safetySettings.maximumDynamicBrightness, 50)
        }
        let allowed = try model.reviewSetup(setup, sections: [.safety])
        try await model.applySetup(setup, sections: [.safety], review: allowed)
        XCTAssertEqual(model.safetySettings.maximumDynamicBrightness, 65)
        XCTAssertTrue(model.safetySettings.warningAcknowledged)
        let reloaded = await PhysicalLightSafetyStore(suiteName: fixture.name).load()
        XCTAssertEqual(reloaded, model.safetySettings)
        XCTAssertEqual(model.savedStudioDocuments, [existing])
    }
}
