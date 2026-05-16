import XCTest

@MainActor
final class BufoKeyboardScreenshots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingScreenshot() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-onboarded", "NO"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Welcome to Bufo Keyboard"].waitForExistence(timeout: 10),
            "Onboarding screen did not appear"
        )
        snapshot("01-Onboarding")
    }

    func testBrowserScreenshot() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-onboarded", "YES"]
        app.launch()

        // Catalog loads async; wait for the title and at least one bufo cell.
        XCTAssertTrue(
            app.navigationBars["Bufos"].waitForExistence(timeout: 10),
            "Browser navigation bar did not appear"
        )
        // Any tag chip will do — "All" is always present.
        _ = app.buttons["All"].waitForExistence(timeout: 5)
        snapshot("02-Browser")
    }

    func testBrowserWithTagScreenshot() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-onboarded", "YES"]
        app.launch()

        XCTAssertTrue(
            app.navigationBars["Bufos"].waitForExistence(timeout: 10),
            "Browser navigation bar did not appear"
        )

        // Tap the second chip (first tag after "All"), if it exists.
        let tagChips = app.scrollViews.firstMatch.buttons
        if tagChips.count >= 2 {
            tagChips.element(boundBy: 1).tap()
        }
        snapshot("03-BrowserFiltered")
    }

    func testMessagesCompactScreenshot() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshotMode", "messagesCompact"]
        app.launch()

        // Wait for the drawer search field to render.
        XCTAssertTrue(
            app.textFields["Search bufos"].waitForExistence(timeout: 10),
            "Messages drawer did not appear"
        )
        snapshot("04-MessagesCompact")
    }

    func testMessagesExpandedScreenshot() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-screenshotMode", "messagesExpanded"]
        app.launch()

        XCTAssertTrue(
            app.textFields["Search bufos"].waitForExistence(timeout: 10),
            "Messages drawer did not appear"
        )
        // Tag chips render only in expanded mode — wait for "All".
        _ = app.buttons["All"].waitForExistence(timeout: 5)
        snapshot("05-MessagesExpanded")
    }
}
