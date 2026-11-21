import XCTest

@MainActor
final class BrowseStudioInputsAndSetup: CandidateBrowseCase {
    func testBrowseInputChoicesAndSetupWithoutLightActions() {
        let app = pairedCandidate()
        studioSection("Playback", in: app)
        let source = app.descendants(matching: .any).matching(identifier: "studio-live-input").firstMatch
        reveal(source, in: app)
        source.tap()
        XCTAssertTrue(menuItem("Engine", in: app).exists)
        XCTAssertTrue(menuItem("Microphone", in: app).exists)
        menuItem("Local media", in: app).tap()
        let media = app.buttons["studio-choose-media"]
        reveal(media, in: app)
        let preview = app.buttons["studio-input-preview"]
        XCTAssertTrue(preview.exists)
        XCTAssertFalse(preview.isEnabled, "Use a fresh process with no selected media.")
        media.tap()
        cancelFilePicker(in: app)
        XCTAssertTrue(media.wait(for: \.isHittable, toEqual: true, timeout: 5))
        XCTAssertFalse(preview.isEnabled)
        capture("Candidate-input-without-media", in: app)
        source.tap()
        menuItem("Engine", in: app).tap()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let export = app.buttons["setup-export"]
        reveal(export, in: app)
        export.tap()
        XCTAssertTrue(app.navigationBars["Export setup"].waitForExistence(timeout: 5))
        let draft = app.switches["setup-section-draft"]
        let safety = app.switches["setup-section-safety"]
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        XCTAssertEqual(draft.value as? String, "1")
        draft.tap()
        XCTAssertEqual(draft.value as? String, "0")
        reveal(safety, in: app)
        XCTAssertEqual(safety.value as? String, "0")
        let layout = app.switches["setup-section-layout"]
        if layout.exists { XCTAssertEqual(layout.value as? String, "0") }
        XCTAssertTrue(app.buttons["setup-export-location"].exists)
        capture("Candidate-setup-export-sections", in: app)
        app.navigationBars["Export setup"].buttons["Cancel"].tap()

        let importFile = app.buttons["setup-import"]
        reveal(importFile, in: app)
        importFile.tap()
        // Do not open a personal document or capture the system Files picker.
        cancelFilePicker(in: app)
        XCTAssertTrue(importFile.wait(for: \.isHittable, toEqual: true, timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.navigationBars["Settings"].buttons["Done"].tap()
        XCTAssertFalse(app.buttons["Stop & restore"].exists)
    }
}
