import XCTest

@MainActor
final class HueBoardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsPrimaryDestinationsWithoutStartingPlayback() {
        let app = XCUIApplication()
        app.launchEnvironment["HUE_BOARD_UI_TEST_MODE"] = "1"
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let lights = app.tabBars.buttons["Lights"].waitForExistence(timeout: 20)
        XCTAssertTrue(lights, "Lights destination did not appear after launch.")

        let scenes = app.tabBars.buttons["Scenes"].waitForExistence(timeout: 5)
        let studio = app.tabBars.buttons["Studio"].waitForExistence(timeout: 5)
        let room = app.tabBars.buttons["Room"].waitForExistence(timeout: 5)
        XCTAssertTrue(scenes, "Scenes destination is missing.")
        XCTAssertTrue(studio, "Studio destination is missing.")
        XCTAssertTrue(room, "Room destination is missing.")

        let settingsTabExists = app.tabBars.buttons["Settings"].exists
        let settingsButtonExists = app.buttons["Settings"].exists
        let restoreExists = app.buttons["Stop & restore"].exists
        XCTAssertFalse(settingsTabExists, "Settings must remain modal rather than a primary tab.")
        XCTAssertTrue(settingsButtonExists, "The modal Settings action is missing.")
        XCTAssertFalse(restoreExists, "A fresh no-write UI-test launch must not create recovery state.")
    }
}
