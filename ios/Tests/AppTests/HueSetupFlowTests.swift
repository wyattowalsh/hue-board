import HueBoardKit
import XCTest
@testable import Hue_Board

final class HueSetupFlowTests: XCTestCase {
    @MainActor
    func testUnpairedImportSkipsForeignLayoutAndPublishesOnlySelectedDraftFields() async throws {
        let model = AppModel()
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
        let model = AppModel()
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
        let model = AppModel()
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
}
