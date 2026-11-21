import XCTest

@MainActor
final class RoomDiscoveryUITests: XCTestCase {
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HUE_BOARD_UI_TEST_MODE"] = "1"
        app.launchEnvironment["HUE_BOARD_ROOM_FIXTURE"] = scenario
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Room"].tap()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<4 {
            if element.isHittable { return }
            let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.79))
            edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.38)))
        }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if !targetEnvironment(simulator)
        throw XCTSkip("Synthetic Room rendering requires the simulator.")
        #endif
    }

    func testLongPartialMatchOpensAndCancelsAtLargestTextSize() {
        let app = launch("partial")
        let match = app.buttons["room-layout-candidate-0"]
        XCTAssertTrue(match.waitForExistence(timeout: 5))
        XCTAssertTrue(match.label.contains("1 of 3 lights"))
        reveal(match, in: app)
        capture("room-partial-layout-large-type", app: app)
        match.tap()
        let cancel = app.buttons["room-layout-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let center = app.buttons["Center"]
        XCTAssertTrue(center.waitForExistence(timeout: 5))
        let position = center.value as? String ?? ""
        XCTAssertTrue(position.contains("70% from the left"))
        XCTAssertTrue(position.contains("80% from the front"))
        cancel.tap()
        XCTAssertTrue(match.waitForExistence(timeout: 5))
    }

    func testEmptyAndUnmatchedDiscoveriesOfferManualArrangement() {
        for (scenario, id) in [("empty", "room-layout-none"), ("unmatched", "room-layout-no-overlap")] {
            let app = launch(scenario)
            XCTAssertTrue(app.staticTexts[id].waitForExistence(timeout: 5))
            let manual = app.buttons["room-layout-manual"]
            reveal(manual, in: app)
            capture("room-layout-\(scenario)", app: app)
            manual.tap()
            XCTAssertTrue(app.buttons["Center"].wait(for: \.isHittable, toEqual: true, timeout: 5))
            app.terminate()
        }
    }

    func testUnavailableReadOffersRetry() {
        let app = launch("unavailable")
        XCTAssertTrue(app.staticTexts["room-layout-error"].waitForExistence(timeout: 5))
        let retry = app.buttons["room-layout-refresh"]
        reveal(retry, in: app)
        capture("room-discovery-retry", app: app)
        retry.tap()
        XCTAssertTrue(app.staticTexts["room-layout-none"].waitForExistence(timeout: 5))
    }
}
