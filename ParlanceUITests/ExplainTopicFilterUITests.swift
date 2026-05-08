import XCTest

final class ExplainTopicFilterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_explainMode_showsTopicChip() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-skip-onboarding"]
        app.launch()

        let explainTile = app.buttons.matching(identifier: "home.modeGrid.explanation").firstMatch
        XCTAssertTrue(explainTile.waitForExistence(timeout: 5))
        explainTile.tap()

        let chip = app.buttons["explain.topicChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
    }

    func test_pickingCategory_updatesChipLabel() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-skip-onboarding"]
        app.launch()

        app.buttons.matching(identifier: "home.modeGrid.explanation").firstMatch.tap()

        let chip = app.buttons["explain.topicChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()

        let picker = app.otherElements["explain.topicPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))

        let techRow = app.buttons["explain.topicPicker.tech"]
        XCTAssertTrue(techRow.waitForExistence(timeout: 3))
        techRow.tap()

        XCTAssertTrue(app.staticTexts["Topic: Tech / Software"].waitForExistence(timeout: 3))
    }

    func test_otherModes_doNotShowChip() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-skip-onboarding"]
        app.launch()

        app.buttons.matching(identifier: "home.modeGrid.interview").firstMatch.tap()

        let chip = app.buttons["explain.topicChip"]
        XCTAssertFalse(chip.waitForExistence(timeout: 2))
    }
}
