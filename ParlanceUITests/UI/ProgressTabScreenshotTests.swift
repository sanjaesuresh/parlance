// ParlanceUITests/UI/ProgressTabScreenshotTests.swift
//
// Screenshot harness for the Progress-tab rework (plan 2026-05-13 §6.2).
//
// Launches the app with `-mockProgressData`, which both seeds the curated
// SwiftData dataset (see `ProgressMockData.seed`) and synth-auths a user so
// the app lands directly on the main tab view. Each captured screenshot is
// attached to the test result with `.keepAlways` lifetime so Xcode test
// reports retain them — the side-by-side HTML report (built by
// `scripts/visual-verify-build-report.sh`) then pairs them with the mockup
// renders.
//
// NOTE on filesystem export: XCTAttachment writes into the test bundle
// sandbox, which is read-only from the host. The companion script reads
// attachments out of the .xcresult bundle after the run. We do NOT try to
// write into `_docs/visual-verification/...` from inside the test process.

import XCTest

final class ProgressTabScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-mockProgressData"]
        app.launch()

        // Wait for the tab bar (signal that the splash has dismissed and
        // the synthetic auth user has resolved).
        let progressTab = app.tabBars.buttons["Progress"]
        XCTAssertTrue(
            progressTab.waitForExistence(timeout: 30),
            "Progress tab should be visible after -mockProgressData launch"
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    /// Captures screenshots for each period filter (week / month / allTime),
    /// the open-standout state, two skill-card expansions, and the recent
    /// session detail screen. All attached to the test as `.keepAlways`.
    func testProgressTabScreenshotMatrix() throws {
        navigateToProgress()

        // 1. Period matrix
        for period in ["week", "month", "allTime"] {
            tapPeriod(period)
            sleep(forUI: 0.5)
            snapshot(named: "progress-\(period).png")
        }

        // 2. Standout open (with period=month, the most populated view)
        tapPeriod("month")
        sleep(forUI: 0.3)
        tapStandoutIfPresent()
        sleep(forUI: 0.5)
        snapshot(named: "standout-open.png")
        // Collapse before moving on so skill-card screenshots aren't
        // dominated by the standout expansion.
        tapStandoutIfPresent()
        sleep(forUI: 0.3)

        // 3. Skill cards: open Structure, then open Pace (Structure should
        //    auto-close — single-open behavior per plan §4.5.3).
        tapSkillCardByName("Structure")
        sleep(forUI: 0.5)
        snapshot(named: "skill-structure-open.png")

        tapSkillCardByName("Pace")
        sleep(forUI: 0.5)
        snapshot(named: "skill-pace-open.png")

        // 4. Recent session row → SessionDetailView
        tapFirstRecentSession()
        sleep(forUI: 0.8)
        snapshot(named: "session-detail.png")
    }

    // MARK: - Navigation

    private func navigateToProgress() {
        let tab = app.tabBars.buttons["Progress"]
        if !tab.isSelected {
            tab.tap()
        }
        // Confirm the period filter rendered before continuing.
        let filter = app.buttons["periodFilter.month"]
        XCTAssertTrue(
            filter.waitForExistence(timeout: 10),
            "Period filter should be visible on the Progress tab"
        )
    }

    private func tapPeriod(_ key: String) {
        let button = app.buttons["periodFilter.\(key)"]
        XCTAssertTrue(
            button.waitForExistence(timeout: 5),
            "periodFilter.\(key) should exist"
        )
        button.tap()
    }

    private func tapStandoutIfPresent() {
        // The standout card has no dedicated identifier; identify via the
        // "View breakdown" / "Hide breakdown" CTA inside it.
        let viewBreakdown = app.staticTexts["View breakdown"]
        let hideBreakdown = app.staticTexts["Hide breakdown"]
        if viewBreakdown.exists {
            viewBreakdown.tap()
        } else if hideBreakdown.exists {
            hideBreakdown.tap()
        }
    }

    private func tapSkillCardByName(_ name: String) {
        // SkillCardView is a Button whose label contains the metric's
        // displayName as a static text. XCUITest collapses Button label
        // text into the button's `label`, so we can match either.
        let direct = app.buttons[name]
        if direct.exists {
            direct.tap()
            return
        }
        // Fallback: tap the static text element directly.
        let text = app.staticTexts[name]
        if text.exists {
            text.tap()
        }
    }

    private func tapFirstRecentSession() {
        // RecentSessionRow sets an accessibilityLabel like
        // "<mode> session, score <n>. Tap for full breakdown."
        let predicate = NSPredicate(format: "label CONTAINS 'Tap for full breakdown'")
        let candidates = app.buttons.matching(predicate)
        guard candidates.count > 0 else {
            XCTFail("Expected at least one recent-session row")
            return
        }
        let first = candidates.element(boundBy: 0)
        // Scroll into view if needed.
        if !first.isHittable {
            app.swipeUp()
        }
        first.tap()
    }

    // MARK: - Helpers

    private func sleep(forUI seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func snapshot(named name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
