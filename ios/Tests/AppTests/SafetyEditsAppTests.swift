import Foundation
import HueBoardNativeCore
import XCTest
@testable import Hue_Board

final class SafetyEditsAppTests: XCTestCase {
  @MainActor
  func testRunningBridgeSceneRetainsItsReviewedSafetySettings() async throws {
    let suite = "hue-board.safety-editor.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = AppModel(setupDefaults: defaults, persistence: AppPersistence(suiteName: suite))
    model.playback.beginBridge(presetID: "ion-eclipse")
    XCTAssertFalse(model.canEditPhysicalSafetySettings)
    let initial = model.safetySettings
    await model.setMaximumDynamicBrightness(10)
    XCTAssertEqual(model.safetySettings, initial)
    model.playback.stop("Test playback ended.")
    XCTAssertTrue(model.canEditPhysicalSafetySettings)
    await model.setMaximumDynamicBrightness(10)
    XCTAssertEqual(PhysicalLightSafetyStore.loadSynchronously(defaults: defaults).maximumDynamicBrightness, 10)
  }
}
