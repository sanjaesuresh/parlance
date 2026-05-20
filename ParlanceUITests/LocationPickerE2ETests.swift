import XCTest

// Exercises LocationPickerField inside the account-creation flow.
// Creates a Supabase user, drives the picker, then deletes the account
// to avoid leaving orphan rows behind.
final class LocationPickerE2ETests: XCTestCase {

    private var app: XCUIApplication!

    private let testTag = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
    private var testEmail: String { "parlance-loc+\(testTag)@gmail.com" }
    private let testPassword = "TestPass123!"
    private let testName = "Loc E2E Tester"
    private var testUsername: String { "loc\(testTag)" }

    override func setUpWithError() throws {
        try skipIfBrokenSESimulator()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UITesting"]
        app.launch()
        XCTAssertTrue(
            app.textFields["emailField"].waitForExistence(timeout: 15),
            "Auth screen should be visible after launch with UITesting flag"
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test

    func testLocationPicker_searchSelectAndClear() throws {
        try navigateToProfileSetup()
        try fillNameAndUsername()

        // Reveal the location field
        app.swipeUp()

        // Type a query into the picker
        let searchField = app.textFields["locationSearchField"]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Location search field should appear in profile setup"
        )
        app.tapAndFocus(searchField)
        searchField.typeText("London")

        // At least one suggestion should arrive from MapKit
        let firstSuggestion = app.buttons["locationSuggestion_0"]
        XCTAssertTrue(
            firstSuggestion.waitForExistence(timeout: 10),
            "MapKit should return at least one city suggestion for 'London'"
        )
        firstSuggestion.safeTap()

        // After resolve, field collapses to the formatted display
        let display = app.staticTexts["locationSelectedDisplay"]
        XCTAssertTrue(
            display.waitForExistence(timeout: 10),
            "Selected location should appear after picking a suggestion"
        )
        XCTAssertTrue(
            display.label.contains(","),
            "Selected location should be formatted 'City, Country' (got: \(display.label))"
        )

        // Tap clear → field should revert to the search input
        let clearButton = app.buttons["locationClearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5))
        clearButton.tap()
        XCTAssertTrue(
            app.textFields["locationSearchField"].waitForExistence(timeout: 5),
            "Search field should reappear after clearing selection"
        )

        // Complete signup so we can delete the account in cleanup
        try completeSignupAndDelete()
    }

    // MARK: - Flow helpers

    private func navigateToProfileSetup() throws {
        let createAccountTab = app.buttons["createAccountTab"]
        XCTAssertTrue(createAccountTab.waitForExistence(timeout: 5))
        createAccountTab.tap()

        let emailField = app.textFields["emailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(testEmail)

        let passwordField = app.secureTextFields["passwordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(testPassword)
        app.dismissKeyboard()

        let continueButton = app.buttons["authSubmitButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        XCTAssertTrue(
            app.textFields["nameField"].waitForExistence(timeout: 15),
            "AuthProfileSetupView should appear after Continue"
        )
    }

    private func fillNameAndUsername() throws {
        let nameField = app.textFields["nameField"]
        app.tapAndFocus(nameField)
        nameField.typeText(testName)

        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        app.advanceFocus(from: nameField, to: usernameField)
        usernameField.typeText(testUsername)
        app.dismissKeyboard()
    }

    private func completeSignupAndDelete() throws {
        app.swipeUp()
        let comfortButton = app.buttons["comfortOption_1"]
        XCTAssertTrue(comfortButton.waitForExistence(timeout: 5))
        comfortButton.safeTap()

        app.swipeUp()
        let letsGoButton = app.buttons["letsGoButton"]
        XCTAssertTrue(letsGoButton.waitForExistence(timeout: 5))
        letsGoButton.safeTap()

        let startButton = app.buttons["Start practicing"]
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 30),
            "WelcomeSplashView should appear — ensure Supabase email confirmation is disabled"
        )
        startButton.tap()

        // Delete the account so this test leaves no Supabase trail
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let deleteAccountButton = app.buttons["deleteAccountButton"]
        var attempts = 0
        while !deleteAccountButton.exists && attempts < 5 {
            app.otherElements.containing(.navigationBar, identifier: "Settings")
                .scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(deleteAccountButton.waitForExistence(timeout: 5))
        deleteAccountButton.tap()

        let confirmDeleteButton = app.alerts["Delete Account"].buttons["Delete Account"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 5))
        confirmDeleteButton.tap()
    }
}
