import XCTest

@MainActor
final class HueBoardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.78))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.36))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, "Expected control was not reachable.")
    }

    private func goBack(from title: String, to previous: String, in app: XCUIApplication) {
        let back = app.navigationBars[title].buttons.matching(NSPredicate(
            format: "identifier == %@ OR label == %@ OR label == %@", "BackButton", "Back", previous
        )).firstMatch
        XCTAssertTrue(back.wait(for: \.isHittable, toEqual: true, timeout: 5))
        back.tap()
        XCTAssertTrue(app.navigationBars[previous].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
        let restoreExists = app.buttons["restore-lights"].exists
        XCTAssertFalse(settingsTabExists, "Settings must remain modal rather than a primary tab.")
        XCTAssertTrue(settingsButtonExists, "The modal Settings action is missing.")
        XCTAssertFalse(restoreExists, "A fresh no-write UI-test launch must not create recovery state.")
        app.buttons["Settings"].tap()
        let limits = app.buttons["settings-playback-limits"]
        XCTAssertTrue(limits.waitForExistence(timeout: 5))
        XCTAssertFalse(app.sliders["Maximum playback brightness"].exists)
        limits.tap()
        XCTAssertTrue(app.navigationBars["Playback limits"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["Maximum playback brightness"].exists)
        goBack(from: "Playback limits", to: "Settings", in: app)
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
        XCTAssertEqual(app.staticTexts["scene-match-count"].label, "0 scenes")
        XCTAssertTrue(app.staticTexts["No scenes found"].exists)
        capture("Scenes-empty-search")

        app.buttons["scene-search-clear"].tap()
        XCTAssertEqual(app.staticTexts["scene-match-count"].label, "32 scenes")
        search.tap()
        let look = "Plasma Turbine"
        search.typeText(look + XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["scene-match-count"].label, "1 scene")
        let scene = app.buttons["scene-plasma-turbine"]
        reveal(scene, in: app)
        XCTAssertFalse(app.buttons["play-plasma-turbine"].exists)
        XCTAssertFalse(app.buttons["compose-plasma-turbine"].exists)
        scene.tap()

        XCTAssertTrue(app.buttons["Connect Bridge to play"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["play-plasma-turbine"].exists)
        let editInStudio = app.buttons["compose-plasma-turbine"]
        reveal(editInStudio, in: app)
        editInStudio.tap()
        XCTAssertTrue(app.navigationBars["Edit mix"].waitForExistence(timeout: 5))
        let source = app.buttons["studio-source-look"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertTrue(source.label.contains(look) || (source.value as? String)?.contains(look) == true,
                      "Studio should load the scene that was selected.")
        capture("Studio-composition-loaded")

        let palette = app.buttons["studio-palette"]
        reveal(palette, in: app)
        palette.tap()
        let usePalette = app.buttons["studio-custom-palette-A"]
        reveal(usePalette, in: app)
        usePalette.tap()
        XCTAssertEqual(usePalette.label, "Used in pattern A")
        capture("Studio-custom-palette-assigned")

        goBack(from: "Custom palette", to: "Edit mix", in: app)
        goBack(from: "Edit mix", to: "Studio", in: app)
        XCTAssertTrue(app.staticTexts["studio-preview-title"].exists)
        XCTAssertFalse(app.buttons["studio-custom-palette-A"].exists)
        let playback = app.buttons["studio-playback"]
        reveal(playback, in: app)
        playback.tap()
        let start = app.buttons["studio-start"]
        reveal(app.buttons["Connect Hue Bridge"], in: app)
        XCTAssertTrue(start.exists)
        XCTAssertFalse(start.isEnabled)
        XCTAssertFalse(app.buttons["restore-lights"].exists)
    }
}
