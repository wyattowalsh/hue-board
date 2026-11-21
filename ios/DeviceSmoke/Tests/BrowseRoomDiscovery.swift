import XCTest

@MainActor
final class BrowseRoomDiscovery: CandidateBrowseCase {
    func testBrowseSavedRoomLayoutsWithoutLightActions() {
        let app = pairedCandidate()
        app.tabBars.buttons["Room"].tap()
        let refresh = app.buttons["room-layout-refresh"]
        reveal(refresh, in: app)

        let candidate = app.buttons["room-layout-candidate-0"]
        let none = app.staticTexts["room-layout-none"]
        let noOverlap = app.staticTexts["room-layout-no-overlap"]
        let error = app.staticTexts["room-layout-error"]
        let result = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier IN %@",
            ["room-layout-candidate-0", "room-layout-none", "room-layout-no-overlap", "room-layout-error"]
        )).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        XCTAssertFalse(error.exists, "The Bridge failed to return a layout inventory.")

        if candidate.exists {
            reveal(candidate, in: app)
            candidate.tap()
            let cancel = app.buttons["room-layout-cancel"]
            XCTAssertTrue(cancel.wait(for: \.isHittable, toEqual: true, timeout: 5))
            XCTAssertTrue(app.buttons["room-layout-save"].exists)
            capture("Candidate-room-matched-preview", in: app)
            cancel.tap()
            XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        } else {
            XCTAssertTrue(none.exists || noOverlap.exists)
            capture(none.exists ? "Candidate-room-no-saved-layouts" : "Candidate-room-no-overlap", in: app)
        }
        XCTAssertFalse(app.buttons["restore-lights"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }
}
