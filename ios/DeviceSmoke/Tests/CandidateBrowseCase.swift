import XCTest

/// Use only against a fresh, externally audited candidate process. Capture the
/// activation marker, complete write-attempt log, and pre/post state outside XCTest.
@MainActor
class CandidateBrowseCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func pairedCandidate() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.wyattowalsh.HueBoard.dev")
        XCTAssertTrue([.runningForeground, .runningBackground, .runningBackgroundSuspended].contains(app.state),
                      "Start a fresh audited candidate before running this selector.")
        app.activate()
        let lights = app.tabBars.buttons["Lights"]
        XCTAssertTrue(lights.wait(for: \.isHittable, toEqual: true, timeout: 15))
        lights.tap()
        let room = app.descendants(matching: .any)["lights-room-picker"]
        XCTAssertTrue(room.waitForExistence(timeout: 35), "A paired room must be ready before browsing.")
        XCTAssertFalse(app.buttons["restore-lights"].exists)
        return app
    }

    func openStudioPlayback(in app: XCUIApplication) {
        app.tabBars.buttons["Studio"].tap()
        let playback = app.buttons["studio-playback"]
        reveal(playback, in: app)
        playback.tap()
        XCTAssertTrue(app.navigationBars["Playback"].waitForExistence(timeout: 5))
    }

    func menuItem(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", title, "studio-live-input"
        )).firstMatch
        let item = button.waitForExistence(timeout: 1) ? button : app.menuItems[title].firstMatch
        XCTAssertTrue(item.wait(for: \.isHittable, toEqual: true, timeout: 5))
        return item
    }

    func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.78))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.35))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists && element.isHittable, "The requested control could not be reached.")
    }

    func cancelFilePicker(in app: XCUIApplication) {
        let inAppCancel = app.buttons["Cancel"].firstMatch
        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        let cancel = inAppCancel.waitForExistence(timeout: 3)
            ? inAppCancel : files.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.wait(for: \.isHittable, toEqual: true, timeout: 10))
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10))
    }

    func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
