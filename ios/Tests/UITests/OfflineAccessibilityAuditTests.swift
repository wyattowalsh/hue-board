import XCTest

@MainActor
final class OfflineAccessibilityAuditTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if !targetEnvironment(simulator)
        throw XCTSkip("These audits use isolated simulator UI fixtures.")
        #endif
    }

    func testFilteredSceneDetailAccessibility() throws {
        let app = launch()
        let scenes = app.tabBars.buttons["Scenes"]
        XCTAssertTrue(scenes.waitForExistence(timeout: 15))
        scenes.tap()

        let search = app.textFields["scene-search"]
        XCTAssertTrue(search.wait(for: \.isHittable, toEqual: true, timeout: 5))
        search.tap()
        search.typeText("Plasma Turbine" + XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["scene-match-count"].label, "1 scene")
        let scene = app.buttons["scene-plasma-turbine"]
        reveal(scene, in: app)
        scene.tap()
        reveal(app.buttons["compose-plasma-turbine"], in: app)
        reveal(app.buttons["Connect Bridge to play"], in: app)
        XCTAssertFalse(app.buttons["play-plasma-turbine"].exists)

        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion, .contrast])
    }

    func testSavedLayoutPreviewAccessibilityAtLargestTextSize() throws {
        let app = launch(roomFixture: "partial", largestText: true)
        let room = app.tabBars.buttons["Room"]
        XCTAssertTrue(room.waitForExistence(timeout: 15))
        room.tap()

        let layout = app.buttons["room-layout-candidate-0"]
        reveal(layout, in: app)
        XCTAssertTrue(layout.label.contains("1 of 3 lights"))
        layout.tap()
        let marker = app.buttons["Center"]
        reveal(marker, in: app)
        let position = try XCTUnwrap(marker.value as? String)
        XCTAssertTrue(position.contains("70% from the left") && position.contains("80% from the front"))

        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription, .hitRegion])
        app.buttons["room-layout-cancel"].tap()
    }

    private func launch(roomFixture: String? = nil, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["HUE_BOARD_UI_TEST_MODE"] = "1"
        if let roomFixture { app.launchEnvironment["HUE_BOARD_ROOM_FIXTURE"] = roomFixture }
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<6 {
            if element.isHittable { return }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.78))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.36))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        XCTAssertTrue(element.isHittable)
    }
}
