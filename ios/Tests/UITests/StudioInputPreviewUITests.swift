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
    let jump = app.buttons["studio-section-jump"]
    XCTAssertTrue(jump.wait(for: \.isHittable, toEqual: true, timeout: 5))
    jump.tap()
    tapMenuItem("Playback", in: app)
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
    tapMenuItem("Local media", in: app)
    XCTAssertTrue(app.buttons["studio-choose-media"].waitForExistence(timeout: 5))
    XCTAssertFalse(preview.isEnabled)
    XCTAssertFalse(app.buttons["studio-start"].isEnabled)
  }

  private func tapMenuItem(_ title: String, in app: XCUIApplication) {
    let button = app.buttons[title]
    let option = button.waitForExistence(timeout: 1) ? button : app.menuItems[title]
    XCTAssertTrue(option.waitForExistence(timeout: 4))
    option.tap()
  }
}
