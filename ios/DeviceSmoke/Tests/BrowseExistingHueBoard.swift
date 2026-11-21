import XCTest

@MainActor
final class BrowseExistingHueBoard: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.78))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.35))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected control was not reachable.")
    }

    func testBrowsePairedInstallationWithoutLightActions() throws {
        let app = XCUIApplication(bundleIdentifier: "com.wyattowalsh.HueBoard.dev")
        app.activate()
        XCTAssertTrue(app.staticTexts["Bridge connected"].waitForExistence(timeout: 35))
        XCTAssertFalse(app.buttons["Stop & restore"].exists)

        for title in ["Lights", "Scenes", "Studio", "Room"] {
            XCTAssertTrue(app.tabBars.buttons[title].exists, "Missing primary destination: \(title)")
        }

        app.tabBars.buttons["Lights"].tap()
        XCTAssertTrue(app.buttons["Refresh Bridge state"].exists)
        XCTAssertTrue(app.buttons["Apply brightness & turn on"].exists)
        capture("01-Lights", in: app)
        let edit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Edit ")).firstMatch
        reveal(edit, in: app)
        edit.tap()
        XCTAssertTrue(app.navigationBars["Individual light"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
        capture("02-Individual-light", in: app)
        app.buttons["Done"].tap()

        app.tabBars.buttons["Scenes"].tap()
        XCTAssertTrue(app.staticTexts["Find your next look."].waitForExistence(timeout: 5))
        capture("03-Scenes", in: app)
        let search = app.searchFields.firstMatch
        if !search.exists {
            app.swipeDown()
        }
        if !search.waitForExistence(timeout: 3) {
            let searchButton = app.buttons["Search"].firstMatch
            if searchButton.exists { searchButton.tap() }
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        let query = "zzqv-no-match-check"
        search.typeText(query)
        let empty = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "0 matching looks")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        capture("04-Scenes-empty-search", in: app)
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: query.count))
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else if app.keyboards.buttons["Search"].exists {
            app.keyboards.buttons["Search"].tap()
        }
        let restored = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "32 matching looks")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 5))

        app.tabBars.buttons["Studio"].tap()
        XCTAssertTrue(app.staticTexts["Make it move."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Engine preview"].exists)
        XCTAssertTrue(app.staticTexts["No light writes"].exists)
        capture("05-Studio-preview", in: app)
        for (title, name) in [
            ("Create your own palette", "06-Studio-palette"),
            ("Cue sequencer", "07-Studio-cues"),
            ("Your saved mixes", "08-Studio-library")
        ] {
            reveal(app.staticTexts[title], in: app)
            capture(name, in: app)
        }

        app.tabBars.buttons["Room"].tap()
        XCTAssertTrue(app.staticTexts["Room, not a list."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Spatial map"].exists)
        capture("09-Room", in: app)
        XCTAssertFalse(app.buttons["Stop & restore"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.tabBars.buttons["Studio"].tap()
    }
}
