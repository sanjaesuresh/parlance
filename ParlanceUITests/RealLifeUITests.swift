import XCTest

// Real Life mode end-to-end UI test.
//
// Uses the `--ui-test-seed-pro` launch arg to seed an authenticated Pro
// user (see `UITestBootstrap` in the app target). The seeded user has
// `hasCompletedSetup = true` and `practiceLevel = 5`, so the app lands
// directly on the home tab with the Real Life tile available.
final class RealLifeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_realLifeTile_proUser_opensSetupAndStarts() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITesting",
            "--ui-test-seed-pro",
        ]
        app.launch()

        // Wait for the home tab to render. The realLife tile lives inside a
        // LazyVGrid below the fold (greeting → XP hero → daily challenge →
        // difficulty → modeGrid), so it does not enter the accessibility
        // tree until scrolled into view — we cannot wait on its existence
        // up front. Use a known visible anchor instead.
        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 10),
            "Home tab should be visible after seed-pro launch"
        )

        // Scroll the home tab until the LazyVGrid materializes the tile,
        // then keep scrolling until it becomes hittable.
        let realLifeTile = app.buttons["home.modeGrid.realLife"]
        var attempts = 0
        while !realLifeTile.exists && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(realLifeTile.exists, "Real Life tile never appeared in the mode grid after scrolling")

        attempts = 0
        while !realLifeTile.isHittable && attempts < 4 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(realLifeTile.isHittable, "Real Life tile never became hittable after scrolling")

        realLifeTile.safeTap()

        // Setup view appears. SwiftUI TextField with axis: .vertical can
        // surface as textView or otherElement depending on iOS version,
        // so match by identifier across all descendants. Retry the tile
        // tap once if the setup view doesn't appear — see hit-test note above.
        let scenarioField = app.descendants(matching: .any)["realLife.scenarioField"].firstMatch
        if !scenarioField.waitForExistence(timeout: 4) {
            realLifeTile.safeTap()
            XCTAssertTrue(scenarioField.waitForExistence(timeout: 6))
        }
        app.tapAndFocus(scenarioField)
        scenarioField.typeText("Asking my manager for time off after a death in the family.")
        app.dismissKeyboard()

        // Start button is enabled (duration default 1:00 ≥ 0:15).
        let startBtn = app.buttons["realLife.startButton"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 3))
        XCTAssertTrue(startBtn.isEnabled)
        startBtn.safeTap()

        // We left the setup screen — the field should disappear.
        XCTAssertFalse(scenarioField.waitForExistence(timeout: 3))
    }
}
