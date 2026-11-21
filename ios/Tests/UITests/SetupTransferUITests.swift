import XCTest

@MainActor
final class SetupTransferUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if !targetEnvironment(simulator)
        throw XCTSkip("This fixture is available only on a simulator.")
        #endif
    }

    func testLegacyConversionWarningsAppearBeforeImport() {
        let app = XCUIApplication()
        app.launchEnvironment["HUE_BOARD_UI_TEST_MODE"] = "1"
        app.launchEnvironment["HUE_BOARD_SETUP_FIXTURE"] = "legacy"
        app.launch()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.wait(for: \.isHittable, toEqual: true, timeout: 10))
        settings.tap()
        let review = app.navigationBars["Review file"]
        for _ in 0..<8 {
            if review.waitForExistence(timeout: 0.3) { break }
            app.swipeUp()
        }
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        for text in ["Migrated a legacy Scriptable schema 3 mix to scene schema 2.",
                     "Replaced invalid custom colors with defaults.",
                     "Clamped brightness to the supported range."] {
            let warning = app.staticTexts[text]
            for _ in 0..<6 {
                if warning.exists && warning.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(warning.isHittable)
        }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Synthetic-legacy-migration-warnings"
        capture.lifetime = .keepAlways
        add(capture)
        XCTAssertTrue(review.buttons["Import"].isEnabled)
        review.buttons["Cancel"].tap()
        XCTAssertTrue(review.waitForNonExistence(timeout: 5))
    }

    func testReviewSelectedLimitsAndCancelWithoutChangingTheDevice() {
        let app = XCUIApplication()
        app.launchEnvironment["HUE_BOARD_UI_TEST_MODE"] = "1"
        app.launchEnvironment["HUE_BOARD_SETUP_FIXTURE"] = "limits"
        app.launch()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.wait(for: \.isHittable, toEqual: true, timeout: 10))
        settings.tap()

        let review = app.navigationBars["Review setup"]
        // The transfer section is below the Bridge and safety settings in the form.
        for _ in 0..<8 {
            if review.waitForExistence(timeout: 0.3) { break }
            app.swipeUp()
        }
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        let favorites = app.switches["setup-section-favorites"]
        let safety = app.switches["setup-section-safety"]
        XCTAssertEqual(favorites.value as? String, "1")
        XCTAssertEqual(safety.value as? String, "0")
        favorites.tap()
        XCTAssertFalse(app.buttons["setup-confirm-import"].isEnabled)
        safety.tap()
        let impact = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", "Maximum dynamic brightness", "80% to 95%"
        )).firstMatch
        XCTAssertTrue(impact.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["setup-confirm-import"].isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Synthetic-setup-cap-review"
        shot.lifetime = .keepAlways
        add(shot)
        review.buttons["Cancel"].tap()
        XCTAssertTrue(review.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        XCTAssertFalse(app.staticTexts["Setup imported."].exists)
    }
}
