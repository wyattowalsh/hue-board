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
            // Scroll from the edge to avoid beginning the drag on a slider or room fixture.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.78))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.35))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected control was not reachable.")
    }

    private func revealSceneSearch(in app: XCUIApplication) -> XCUIElement {
        let inlineSearch = app.textFields["scene-search"]
        if inlineSearch.exists && inlineSearch.isHittable { return inlineSearch }

        // The existing build 5 installation used a navigation-bar search field.
        let legacySearch = app.searchFields.firstMatch
        if !legacySearch.isHittable {
            app.swipeDown()
        }
        if !legacySearch.isHittable {
            let navigationSearch = app.navigationBars.buttons["Search"].firstMatch
            let searchButton = navigationSearch.exists ? navigationSearch : app.buttons["Search"].firstMatch
            if searchButton.exists && searchButton.isHittable { searchButton.tap() }
        }
        XCTAssertTrue(legacySearch.waitForExistence(timeout: 5))
        XCTAssertTrue(legacySearch.isHittable, "The Scenes search field is hidden.")
        return legacySearch
    }

    private func sceneCount(_ count: Int, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "label BEGINSWITH %@", "\(count) matching look"
        )).firstMatch
    }

    private func clearSearch(_ search: XCUIElement, typed query: String, in app: XCUIApplication) {
        let clear = app.buttons["scene-search-clear"]
        if clear.exists && clear.isHittable {
            clear.tap()
        } else {
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: query.count))
        }
    }

    private func reachStudioSection(_ title: String, menuItem: String, in app: XCUIApplication) {
        let jump = app.buttons["studio-section-jump"]
        if jump.exists && jump.isHittable {
            jump.tap()
            let section = app.buttons[menuItem]
            XCTAssertTrue(section.waitForExistence(timeout: 5))
            section.tap()
        }
        reveal(app.staticTexts[title], in: app)
    }

    func testBrowsePairedInstallationWithoutLightActions() throws {
        let app = XCUIApplication(bundleIdentifier: "com.wyattowalsh.HueBoard.dev")
        app.activate()
        XCTAssertTrue(app.tabBars.buttons["Lights"].waitForExistence(timeout: 15))
        for title in ["Lights", "Scenes", "Studio", "Room"] {
            XCTAssertTrue(app.tabBars.buttons[title].exists, "Missing primary destination: \(title)")
        }

        app.tabBars.buttons["Lights"].tap()
        XCTAssertTrue(app.staticTexts["Bridge connected"].waitForExistence(timeout: 35))
        XCTAssertFalse(app.buttons["Stop & restore"].exists)
        XCTAssertTrue(app.buttons["Refresh Bridge state"].exists)
        reveal(app.buttons["Apply brightness & turn on"], in: app)
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
        let search = revealSceneSearch(in: app)
        search.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))

        let knownLook = "Ion Eclipse"
        search.typeText(knownLook)
        XCTAssertTrue(sceneCount(1, in: app).waitForExistence(timeout: 5))
        capture("04-Scenes-search-match", in: app)
        clearSearch(search, typed: knownLook, in: app)
        if !keyboard.exists { search.tap() }

        let missingLook = "zzqvnomatchcheck"
        search.typeText(missingLook)
        XCTAssertTrue(sceneCount(0, in: app).waitForExistence(timeout: 5))
        capture("05-Scenes-empty-search", in: app)
        clearSearch(search, typed: missingLook, in: app)
        if app.buttons["Cancel"].exists && app.buttons["Cancel"].isHittable {
            app.buttons["Cancel"].tap()
        } else if keyboard.exists {
            search.typeText(XCUIKeyboardKey.return.rawValue)
        }
        XCTAssertTrue(sceneCount(32, in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Studio"].tap()
        XCTAssertTrue(app.staticTexts["Make it move."].waitForExistence(timeout: 5))
        reveal(app.staticTexts["Engine preview"], in: app)
        XCTAssertTrue(app.staticTexts["No light writes"].exists)
        capture("06-Studio-preview", in: app)
        for (title, item, name) in [
            ("Create your own palette", "Palette", "07-Studio-palette"),
            ("Cue sequencer", "Cues", "08-Studio-cues"),
            ("Your saved mixes", "Saved mixes", "09-Studio-library")
        ] {
            reachStudioSection(title, menuItem: item, in: app)
            capture(name, in: app)
        }

        app.tabBars.buttons["Room"].tap()
        XCTAssertTrue(app.staticTexts["Room, not a list."].waitForExistence(timeout: 5))
        reveal(app.staticTexts["Spatial map"], in: app)
        capture("10-Room-map", in: app)
        reveal(app.sliders["Output trim"], in: app)
        XCTAssertTrue(app.sliders["Additional ceiling"].exists)
        capture("11-Room-fixture-controls", in: app)
        XCTAssertFalse(app.buttons["Stop & restore"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }
}
