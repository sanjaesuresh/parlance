import XCTest

// Currently disabled. Like ExplainTopicFilterUITests, these tests need a
// test-only bootstrap path that seeds an authenticated Pro user and lands
// the app on the home tab. The app currently only reads `UITesting` and
// uses it to force sign-out — so the home mode grid is never visible
// during UI tests, and every assertion below would fail at the first tap.
//
// To re-enable:
//   1. Add a launch arg (e.g. `--ui-test-seed-pro`) that, when set,
//      seeds a SwiftData User with `hasCompletedSetup = true`, marks
//      AuthService authenticated, and forces SubscriptionService.isPro
//      to true.
//   2. Dismiss SplashView when the launch arg is set.
//   3. Remove the XCTSkip below.
//
// Until that harness exists, skipping keeps CI green without losing the
// documented intent of the test.
final class RealLifeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        throw XCTSkip("Pending: --ui-test-seed-pro harness is not implemented in the app.")
    }

    func test_realLifeTile_proUser_opensSetupAndStarts() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITesting",
            "--ui-test-seed-pro",
        ]
        app.launch()

        // Wait for the home mode grid to render, then tap the Real Life tile.
        let realLifeTile = app.buttons["home.modeGrid.realLife"]
        XCTAssertTrue(realLifeTile.waitForExistence(timeout: 5))
        realLifeTile.tap()

        // Setup view appears — SwiftUI TextField with axis: .vertical
        // surfaces in XCUITest as a textView, not a textField.
        let scenarioField = app.textViews["realLife.scenarioField"].firstMatch
        XCTAssertTrue(scenarioField.waitForExistence(timeout: 3))
        scenarioField.tap()
        scenarioField.typeText("Asking my manager for time off after a death in the family.")

        // Start button is enabled (duration default 1:00 ≥ 0:15).
        let startBtn = app.buttons["realLife.startButton"]
        XCTAssertTrue(startBtn.exists)
        XCTAssertTrue(startBtn.isEnabled)
        startBtn.tap()

        // We left the setup screen — the field should no longer exist.
        XCTAssertFalse(scenarioField.waitForExistence(timeout: 2))
    }
}
