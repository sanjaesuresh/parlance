import XCTest

final class AccountE2ETests: XCTestCase {

    private var app: XCUIApplication!

    // Unique per test run so we never collide with an existing account
    private let testEmail = "parlancee2e+\(Int(Date().timeIntervalSince1970))@gmail.com"
    private let testPassword = "TestPass123"
    private let testName = "E2E Tester"
    private let testUsername = "e2etester\(Int(Date().timeIntervalSince1970) % 100000)"

    override func setUpWithError() throws {
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

        // 4. Tap Continue
        let continueButton = app.buttons["authSubmitButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // 5. Profile setup — fill name
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(testName)

        // 6. Fill username
        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText(testUsername)

        // 7. Pick comfort level (Nervous = level 1)
        let comfortButton = app.buttons["comfortOption_1"]
        XCTAssertTrue(comfortButton.waitForExistence(timeout: 5))
        comfortButton.tap()

        // 8. Tap "Let's go"
        let letsGoButton = app.buttons["letsGoButton"]
        XCTAssertTrue(letsGoButton.waitForExistence(timeout: 5))
        letsGoButton.tap()
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

        // Scroll down to reveal "Delete Account" (sheet is a medium detent with ScrollView)
        app.swipeUp()

        // Tap Delete Account in the settings sheet
        let deleteAccountButton = app.buttons["Delete Account"]
        XCTAssertTrue(deleteAccountButton.waitForExistence(timeout: 5))
        deleteAccountButton.tap()

        // Confirm in the alert
        let confirmDeleteButton = app.alerts["Delete Account"].buttons["Delete Account"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 5))
        confirmDeleteButton.tap()
    }
}
