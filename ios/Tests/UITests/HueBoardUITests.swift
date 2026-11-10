import XCTest

final class HueBoardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsPrimaryDestinationsWithoutStartingPlayback() {
        let app = XCUIApplication()
        app.launchEnvironment["HUE_BOARD_UI_TEST_MODE"] = "1"
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Lights"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Scenes"].exists)
        XCTAssertTrue(app.tabBars.buttons["Live"].exists)
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
        XCTAssertFalse(app.buttons["Stop & restore"].exists)
    }
}
