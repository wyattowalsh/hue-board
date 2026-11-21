import XCTest

@MainActor
final class StudioInputPreviewUITests: XCTestCase {
  func testOfflineInputOptionsStayPassiveAtAccessibilityTextSize() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchEnvironment["HUE_BOARD_UI_TEST_MODE"] = "1"
    app.launchArguments = [
      "-ApplePersistenceIgnoreState", "YES",
      "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
    ]
    app.launch()

    let studio = app.tabBars.buttons["Studio"]
    XCTAssertTrue(studio.waitForExistence(timeout: 15))
    studio.tap()
    let playback = app.buttons["studio-playback"]
    reveal(playback, in: app)
    playback.tap()
    XCTAssertTrue(app.navigationBars["Inputs & playback"].waitForExistence(timeout: 5))
    let source = app.buttons["studio-live-input"]
    XCTAssertTrue(source.wait(for: \.isHittable, toEqual: true, timeout: 5))
    source.tap()
    tapMenuItem("Microphone", in: app)
    let preview = app.buttons["studio-input-preview"]
    XCTAssertTrue(preview.waitForExistence(timeout: 5))
    XCTAssertEqual(preview.label, "Preview input")
    XCTAssertTrue(preview.isEnabled)
    XCTAssertFalse(app.descendants(matching: .any)["studio-input-level"].exists)

    source.tap()
    tapMenuItem("Audio or video file", in: app)
    XCTAssertTrue(app.buttons["studio-choose-media"].waitForExistence(timeout: 5))
    XCTAssertFalse(preview.isEnabled)
    reveal(app.buttons["Connect Hue Bridge"], in: app)
    let start = app.buttons["studio-start"]
    XCTAssertTrue(start.exists)
    XCTAssertFalse(start.isEnabled)
  }

  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<8 {
      if element.exists && element.isHittable { return }
      let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.78))
      let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.36))
      start.press(forDuration: 0.05, thenDragTo: end)
    }
    XCTAssertTrue(element.exists && element.isHittable)
  }

  private func tapMenuItem(_ title: String, in app: XCUIApplication) {
    let button = app.buttons[title]
    let option = button.waitForExistence(timeout: 1) ? button : app.menuItems[title]
    XCTAssertTrue(option.waitForExistence(timeout: 4))
    option.tap()
  }
}
