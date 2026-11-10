import XCTest
@testable import HueBoard

final class HueBoardAppTests: XCTestCase {
    @MainActor
    func testFreshModelStartsDisconnectedWithoutWriterOwnership() async {
        let model = AppModel()
        XCTAssertEqual(model.connectionState, .disconnected)
        XCTAssertFalse(model.isReady)
        XCTAssertNil(await model.playbackCoordinator.currentLease())
    }
}
