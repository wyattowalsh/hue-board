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

    func testOfflineSearchAndStudioDraftKeepPhysicalActionsDisabled() {
        let app = XCUIApplication()
        app.launchEnvironment["HUE_BOARD_UI_TEST_MODE"] = "1"
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let scenes = app.tabBars.buttons["Scenes"]
        XCTAssertTrue(scenes.waitForExistence(timeout: 20))
        scenes.tap()

        let search = app.textFields["scene-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zzqvnomatchcheck")
        XCTAssertEqual(app.staticTexts["scene-match-count"].label, "0 matching looks")
        XCTAssertTrue(app.staticTexts["No matching looks"].exists)

        app.buttons["scene-search-clear"].tap()
        XCTAssertEqual(app.staticTexts["scene-match-count"].label, "32 matching looks")
        search.tap()
        search.typeText("Ion Eclipse" + XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(app.staticTexts["scene-match-count"].label, "1 matching look")
        XCTAssertTrue(app.staticTexts["Ion Eclipse"].exists)
        let compose = app.buttons["compose-ion-eclipse"]
        if !compose.isHittable { app.swipeUp() }
        XCTAssertTrue(compose.isHittable)
        let play = app.buttons["Play"].firstMatch
        XCTAssertTrue(play.exists)
        XCTAssertFalse(play.isEnabled)
        compose.tap()
        XCTAssertTrue(app.staticTexts["Engine preview"].waitForExistence(timeout: 5))
        let jump = app.buttons["studio-section-jump"]
        XCTAssertTrue(jump.exists)
        jump.tap()
        app.buttons["Palette"].tap()
        let usePalette = app.buttons["studio-custom-palette-A"]
        XCTAssertTrue(usePalette.waitForExistence(timeout: 5))
        if !usePalette.isHittable { app.swipeUp() }
        usePalette.tap()
        XCTAssertEqual(usePalette.label, "Using in A")

        jump.tap()
        app.buttons["Playback"].tap()
        let start = app.buttons["studio-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled)
        XCTAssertFalse(app.buttons["Stop & restore"].exists)
    }
}
