import XCTest
@testable import Hue_Board

final class StudioMicrophoneTests: XCTestCase {
  func testNormalizesMeanSquareToBoundedLevel() {
    XCTAssertEqual(StudioMicrophone.normalizedLevel(meanSquare: 0), 0)
    XCTAssertEqual(StudioMicrophone.normalizedLevel(meanSquare: .nan), 0)
    XCTAssertEqual(StudioMicrophone.normalizedLevel(meanSquare: .infinity), 0)
    XCTAssertEqual(StudioMicrophone.normalizedLevel(meanSquare: 0.000_001), 0)
    XCTAssertEqual(StudioMicrophone.normalizedLevel(meanSquare: 0.001), 25.0 / 43, accuracy: 0.000_001)
    XCTAssertEqual(StudioMicrophone.normalizedLevel(meanSquare: 0.1), 1)
  }

  @MainActor
  func testStoppingInactiveMicrophoneLeavesSilentMeter() {
    let microphone = StudioMicrophone()
    microphone.stop()
    microphone.stop()
    XCTAssertFalse(microphone.isCapturing)
    XCTAssertEqual(microphone.signal().level, 0)
  }
}
