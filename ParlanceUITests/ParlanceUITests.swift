import XCTest

final class AccountE2ETests: XCTestCase {

    private var app: XCUIApplication!

    // UUID-based tag guarantees uniqueness across test class instances
    private let testTag = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
    private var testEmail: String { "parlancee2e+\(testTag)@gmail.com" }
    private let testPassword = "TestPass123!"
    private let testName = "E2E Tester"
    private var testUsername: String { "e2e\(testTag)" }

    override func setUpWithError() throws {
        try skipIfBrokenSESimulator()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UITesting"]
        app.launch()
        // Wait for auth screen to appear (splash dismisses and we're not signed in)
        XCTAssertTrue(
            app.textFields["emailField"].waitForExistence(timeout: 15),
            "Auth screen should be visible after launch with UITesting flag"
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func testCreateAccount() throws {
        try signUp()
        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 20),
            "Home tab should be visible after successful sign-up"
        )
    }

    func testCreateAndDeleteAccount() throws {
        try signUp()
        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 20),
            "Home tab should be visible after sign-up"
        )

        try deleteAccount()

        // After deletion, AccountDeletedSplashView plays (~3.2s) then AuthView appears
        XCTAssertTrue(
            app.textFields["emailField"].waitForExistence(timeout: 20),
            "Auth screen should reappear after account deletion"
        )
    }

    // MARK: - Helpers

    private func signUp() throws {
        // 1. Tap "Create account" tab
        let createAccountTab = app.buttons["createAccountTab"]
        XCTAssertTrue(createAccountTab.waitForExistence(timeout: 5))
        createAccountTab.tap()

        // 2. Enter email
        let emailField = app.textFields["emailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(testEmail)

        // 3. Enter password — GoldSecureTextField is a UITextField with isSecureTextEntry=true
        //    XCUITest finds it via the accessibilityIdentifier set on the UITextField
        let passwordField = app.secureTextFields["passwordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(testPassword)
        // Dismiss password keyboard so the auth → profile-setup transition isn't racing
        // an in-flight keyboard dismissal animation (causes nameField "not hittable").
        app.dismissKeyboard()

        // 4. Tap Continue
        let continueButton = app.buttons["authSubmitButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // 5. Profile setup — fill name
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        app.tapAndFocus(nameField)
        nameField.typeText(testName)
        // Dismiss before moving to username so SwiftUI scroll-to-focused-field
        // doesn't shift the next field mid-tap (causes "no keyboard focus" failure).
        app.dismissKeyboard()

        // 6. Fill username
        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        app.tapAndFocus(usernameField)
        usernameField.typeText(testUsername)
        app.dismissKeyboard()

        // 7. Scroll down to reveal comfort options, then pick one
        app.swipeUp()
        let comfortButton = app.buttons["comfortOption_1"]
        XCTAssertTrue(comfortButton.waitForExistence(timeout: 5))
        comfortButton.safeTap()

        // 8. Scroll down to reveal "Let's go" and tap it
        app.swipeUp()
        let letsGoButton = app.buttons["letsGoButton"]
        XCTAssertTrue(letsGoButton.waitForExistence(timeout: 5))
        letsGoButton.safeTap()

        // 9. WelcomeSplashView is shown after first sign-up — dismiss it
        // NOTE: Requires Supabase email auto-confirmation to be enabled
        //       (Authentication > Settings > "Confirm email" must be OFF)
        let startButton = app.buttons["Start practicing"]
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 30),
            "WelcomeSplashView should appear — ensure Supabase email confirmation is disabled for testing"
        )
        startButton.tap()
    }

    private func deleteAccount() throws {
        // Navigate to Profile tab
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()

        // Tap Settings gear (accessibilityLabel set in ProfileView)
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Wait for the sheet's navigation bar to confirm it's fully open
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        // Scroll the sheet until "Delete Account" appears
        let deleteAccountButton = app.buttons["deleteAccountButton"]
        var attempts = 0
        while !deleteAccountButton.exists && attempts < 5 {
            // Target the scroll view inside the "Settings" navigation context
            app.otherElements.containing(.navigationBar, identifier: "Settings")
                .scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(deleteAccountButton.waitForExistence(timeout: 5))
        deleteAccountButton.tap()

        // Confirm in the alert
        let confirmDeleteButton = app.alerts["Delete Account"].buttons["Delete Account"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 5))
        confirmDeleteButton.tap()
    }
}
