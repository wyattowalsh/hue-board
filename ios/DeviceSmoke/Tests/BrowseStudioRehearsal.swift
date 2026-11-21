import XCTest

@MainActor
final class BrowseStudioRehearsal: CandidateBrowseCase {
    func testStepRoomRehearsalWithoutLightActions() {
        let app = pairedCandidate()
        studioSection("Preview", in: app)
        let timeline = app.sliders["studio-rehearsal-time"]
        reveal(timeline, in: app)
        XCTAssertTrue(app.staticTexts["No light writes"].exists)
        let initial = timeline.value as? String
        XCTAssertEqual(initial, "0 seconds")
        let next = app.buttons["studio-rehearsal-next"]
        let previous = app.buttons["studio-rehearsal-previous"]
        reveal(next, in: app)
        XCTAssertTrue(next.isEnabled)
        XCTAssertFalse(previous.isEnabled)
        next.tap()
        XCTAssertTrue(previous.wait(for: \.isEnabled, toEqual: true, timeout: 5))
        XCTAssertNotEqual(timeline.value as? String, initial)
        previous.tap()
        XCTAssertEqual(timeline.value as? String, initial)

        let fixtures = app.descendants(matching: .any).matching(identifier: "studio-rehearsal-fixtures").firstMatch
        reveal(fixtures, in: app)
        fixtures.tap()
        capture("Candidate-studio-fixture-targets", in: app)
        fixtures.tap()
        XCTAssertFalse(app.buttons["Stop & restore"].exists)
    }
}
