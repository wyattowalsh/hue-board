import XCTest

@MainActor
final class BrowseCurrentWorkspace: CandidateBrowseCase {
    func testInspectLightsSearchScenesAndInspectRoomWithoutLightActions() {
        let app = pairedCandidate()
        for tab in ["Lights", "Scenes", "Studio", "Room"] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists)
        }

        let editLight = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Edit ")).firstMatch
        reveal(editLight, in: app)
        editLight.tap()
        let done = app.buttons["light-detail-done"]
        XCTAssertTrue(done.wait(for: \.isHittable, toEqual: true, timeout: 5))
        capture("Candidate-individual-light", in: app)
        done.tap()

        app.tabBars.buttons["Scenes"].tap()
        let search = app.textFields["scene-search"]
        let count = app.staticTexts["scene-match-count"]
        XCTAssertTrue(search.wait(for: \.isHittable, toEqual: true, timeout: 5))
        XCTAssertEqual(count.label, "32 scenes")
        search.tap()
        search.typeText("zzqvnomatchcheck")
        XCTAssertTrue(app.staticTexts["No scenes found"].waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "0 scenes")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Candidate-empty-search-keyboard"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["scene-search-clear"].tap()
        XCTAssertEqual(count.label, "32 scenes")
        search.tap()
        search.typeText("Ion Eclipse" + XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertEqual(count.label, "1 scene")
        let scene = app.buttons["scene-ion-eclipse"]
        reveal(scene, in: app)
        scene.tap()
        XCTAssertTrue(app.buttons["compose-ion-eclipse"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["play-ion-eclipse"].exists)
        capture("Candidate-scene-detail", in: app)

        app.tabBars.buttons["Studio"].tap()
        XCTAssertTrue(app.staticTexts["studio-preview-title"].waitForExistence(timeout: 5))
        reveal(app.buttons["studio-edit-mix"], in: app)
        for (id, title) in [("studio-cues", "Cue sequence"), ("studio-library", "Saved mixes")] {
            let link = app.buttons[id]
            reveal(link, in: app)
            link.tap()
            let bar = app.navigationBars[title]
            XCTAssertTrue(bar.waitForExistence(timeout: 5))
            capture("Candidate-\(id)", in: app)
            let back = bar.buttons.matching(NSPredicate(
                format: "identifier == %@ OR label IN %@", "BackButton", ["Back", "Studio"]
            )).firstMatch
            XCTAssertTrue(back.wait(for: \.isHittable, toEqual: true, timeout: 5))
            back.tap()
            XCTAssertTrue(app.navigationBars["Studio"].waitForExistence(timeout: 5))
        }
        reveal(app.buttons["studio-playback"], in: app)

        app.tabBars.buttons["Room"].tap()
        let position = app.descendants(matching: .any).matching(identifier: "room-position-controls").firstMatch
        reveal(position, in: app)
        let x = app.sliders["Position X"]
        XCTAssertFalse(x.exists && x.isHittable)
        position.tap()
        reveal(x, in: app)
        XCTAssertTrue(app.sliders["Position Y"].exists)
        capture("Candidate-room-position-controls", in: app)
        let adjustments = app.descendants(matching: .any).matching(identifier: "room-studio-controls").firstMatch
        reveal(adjustments, in: app)
        adjustments.tap()
        reveal(app.sliders["room-output-trim"], in: app)
        XCTAssertTrue(app.sliders["room-output-ceiling"].exists)
        capture("Candidate-room-output-controls", in: app)
        XCTAssertFalse(app.buttons["restore-lights"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }
}
