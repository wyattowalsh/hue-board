import Foundation
import XCTest
@testable import Hue_Board

final class StudioLiveInputAppTests: XCTestCase {
  @MainActor
  func testSelectingAnInputDoesNotStartCaptureOrOwnTheWriter() async {
    let model = AppModel()
    XCTAssertEqual(model.studioLiveInput, .engine)

    model.studioLiveInput = .microphone
    XCTAssertFalse(model.studioMicrophone.isCapturing)
    model.studioLiveInput = .media
    model.studioMediaURL = URL(fileURLWithPath: "/unopened-test-clip.mov")
    XCTAssertNil(model.studioMedia.player)
    let lease = await model.playbackCoordinator.currentLease()
    XCTAssertNil(lease)
  }

  @MainActor
  func testBackgroundCancelsPendingCaptureWithoutRestartingIt() {
    let model = AppModel()
    let startID = UUID()
    model.studioLiveInput = .microphone
    model.liveStartupID = startID
    model.studioCaptureSessionID = startID
    model.isBusy = true

    model.setStudioSceneBackgrounded(true)
    XCTAssertNil(model.liveStartupID)
    XCTAssertNil(model.studioCaptureSessionID)
    XCTAssertFalse(model.isBusy)
    XCTAssertFalse(model.studioMicrophone.isCapturing)

    model.setStudioSceneBackgrounded(false)
    XCTAssertEqual(model.studioLiveInput, .microphone)
    XCTAssertNil(model.studioCaptureSessionID)
    XCTAssertFalse(model.studioMicrophone.isCapturing)
  }

  @MainActor
  func testBackgroundDoesNotCancelEngineOnlyStartup() {
    let model = AppModel()
    let startID = UUID()
    model.liveStartupID = startID
    model.isBusy = true

    model.setStudioSceneBackgrounded(true)
    XCTAssertEqual(model.liveStartupID, startID)
    XCTAssertTrue(model.isBusy)
  }
}
