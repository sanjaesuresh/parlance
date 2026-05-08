import XCTest

/// End-to-end tests for the Social tab's Friends flows.
///
/// Fixturing model:
/// - Account A (primary): fresh per test, UUID-tagged. Deleted at end of each test
///   via the existing Settings → Delete Account flow. Cascade-cleans all friend rows.
/// - Account B (persistent fixture): one shared account across runs. Auto-bootstrapped
///   on first class invocation by `ensureFixtureBExists()`. Cleaned implicitly via
///   cascade when account A is deleted.
///
/// Requires Supabase email auto-confirmation to be OFF
/// (Authentication > Settings > "Confirm email" must be OFF).
final class FriendsE2ETests: XCTestCase {

    private var app: XCUIApplication!

    // Per-test fresh primary
    private let aTag = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
    private var aEmail: String { "parlancee2e+a\(aTag)@gmail.com" }
    private var aUsername: String { "e2ea\(aTag)" }
    private let aPassword = "TestPass123!"
    private let aDisplayName = "E2E Tester A"

    // Persistent fixture (constants — same across all runs)
    private static let bEmail = "parlancee2e-fixtureb@gmail.com"
    private static let bPassword = "TestPass123!"
    private static let bUsername = "e2efixteb"
    private static let bDisplayName = "E2E Fixture B"

    private var bEmail: String { Self.bEmail }
    private var bPassword: String { Self.bPassword }
    private var bUsername: String { Self.bUsername }

    // MARK: - Class-level bootstrap

    override class func setUp() {
        super.setUp()
        ensureFixtureBExists()
    }

    /// Wait for an element to be hittable (covers cases where it exists in the hierarchy
    /// but is obscured by an overlay like SplashView).
    @discardableResult
    fileprivate static func waitForHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let hittable = NSPredicate(format: "isHittable == true")
        let exp = XCTNSPredicateExpectation(predicate: hittable, object: element)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    /// Bootstrap fixture B: try to sign in; if it fails, run the full sign-up flow.
    /// Idempotent — does nothing on subsequent runs after the first.
    private static func ensureFixtureBExists() {
        let bootstrapApp = XCUIApplication()
        bootstrapApp.launchArguments = ["UITesting"]
        bootstrapApp.launch()

        // Wait for AuthView (UITesting flag forces sign-out on launch)
        let emailField = bootstrapApp.textFields["emailField"]
        guard emailField.waitForExistence(timeout: 15) else {
            XCTFail("Bootstrap: AuthView did not appear")
            return
        }

        // Tap Sign In tab
        let signInTab = bootstrapApp.buttons["signInTab"]
        if signInTab.waitForExistence(timeout: 5) {
            signInTab.tap()
        }

        // Try to sign in as B
        emailField.tap()
        emailField.typeText(bEmail)

        let passwordField = bootstrapApp.secureTextFields["passwordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(bPassword)

        bootstrapApp.buttons["authSubmitButton"].tap()

        // If signin succeeds, Home tab appears within ~10s. If B doesn't exist,
        // we stay on AuthView with an error message.
        let homeTab = bootstrapApp.tabBars.buttons["Home"]
        if homeTab.waitForExistence(timeout: 12) {
            // B exists — wait for splash to dismiss (sync completion) then sign out
            _ = waitForHittable(homeTab, timeout: 15)
            bootstrapSignOut(app: bootstrapApp)
        } else {
            // B doesn't exist — sign up
            bootstrapSignUpFixtureB(app: bootstrapApp)
        }

        bootstrapApp.terminate()
    }

    private static func bootstrapSignOut(app: XCUIApplication) {
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        _ = waitForHittable(profileTab, timeout: 10)
        profileTab.tap()
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        let signOutButton = app.buttons["signOutButton"]
        var attempts = 0
        while !signOutButton.exists && attempts < 5 {
            app.otherElements.containing(.navigationBar, identifier: "Settings")
                .scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5))
        signOutButton.tap()

        let confirm = app.alerts["Sign Out"].buttons["Sign Out"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.textFields["emailField"].waitForExistence(timeout: 15))
    }

    private static func bootstrapSignUpFixtureB(app: XCUIApplication) {
        // Field state from the failed signin attempt may persist — clear and re-enter.
        // Tap Create account tab; this resets viewModel.errorMessage and switches to signup mode
        // without clearing email/password (per AuthView lines 55-60). That's fine for B.
        let createAccountTab = app.buttons["createAccountTab"]
        XCTAssertTrue(createAccountTab.waitForExistence(timeout: 5))
        createAccountTab.tap()

        // Re-fill email + password to be safe (the failed signin may have left them)
        let emailField = app.textFields["emailField"]
        emailField.tap()
        // Clear field by selecting all + delete
        emailField.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
            emailField.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        emailField.typeText(bEmail)

        let passwordField = app.secureTextFields["passwordField"]
        passwordField.tap()
        passwordField.press(forDuration: 1.0)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) {
            app.menuItems["Select All"].tap()
            passwordField.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        passwordField.typeText(bPassword)

        app.buttons["authSubmitButton"].tap()

        // Profile setup
        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(bDisplayName)

        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText(bUsername)
        usernameField.typeText("\n")

        app.swipeUp()
        let comfortButton = app.buttons["comfortOption_1"]
        XCTAssertTrue(comfortButton.waitForExistence(timeout: 5))
        comfortButton.tap()

        app.swipeUp()
        let letsGoButton = app.buttons["letsGoButton"]
        XCTAssertTrue(letsGoButton.waitForExistence(timeout: 5))
        letsGoButton.tap()

        // WelcomeSplashView
        let startButton = app.buttons["Start practicing"]
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 30),
            "WelcomeSplashView should appear — ensure Supabase email confirmation is disabled"
        )
        startButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        bootstrapSignOut(app: app)
    }

    // MARK: - Per-test setup / teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UITesting"]

        // Dismiss any system popups (dictation, keyboard tutorial, allow notifications, etc.)
        // that would otherwise block the test. The monitor fires on the next interaction.
        addUIInterruptionMonitor(withDescription: "System Dialog") { alert in
            let dismissLabels = ["Don't Allow", "Not Now", "Cancel", "OK", "Dismiss",
                                 "Continue", "Allow", "Enable Dictation"]
            for label in dismissLabels {
                let button = alert.buttons[label]
                if button.exists {
                    if label == "Enable Dictation" {
                        // For dictation popup, prefer "Not Now" / "Don't Allow" if both exist
                        continue
                    }
                    button.tap()
                    return true
                }
            }
            // Fallback: tap first available button to dismiss
            let firstButton = alert.buttons.element(boundBy: 0)
            if firstButton.exists {
                firstButton.tap()
                return true
            }
            return false
        }

        app.launch()
        XCTAssertTrue(
            app.textFields["emailField"].waitForExistence(timeout: 15),
            "Auth screen should be visible after launch"
        )
    }

    /// Dismiss the keyboard before tab navigation. Required because `searchField`
    /// keeps focus, and the keyboard would otherwise cover the tab bar.
    private func dismissKeyboardIfNeeded() {
        // Tap on the content area (below the safe area, above the keyboard).
        // The LeagueView has a tap-to-dismiss gesture that resigns focus.
        // dy: 0.25 lands in the tier banner / tab selector area — definitely on
        // SwiftUI content, definitely above the keyboard.
        let contentArea = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        contentArea.tap()
        // Brief settle so subsequent layout reflects the dismissed keyboard.
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 2)
    }

    /// Tap a tab-bar button reliably. If the button isn't hittable (e.g., keyboard
    /// is covering it), force a keyboard dismissal and retry.
    private func tapTabBarButton(_ identifier: String) {
        let button = app.tabBars.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 10),
                      "\(identifier) tab should exist")

        if !button.isHittable {
            dismissKeyboardIfNeeded()
        }
        // If still not hittable after a dismissal attempt, try a second time.
        if !button.isHittable {
            // Aggressive: tap top area twice
            let topArea = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            topArea.tap()
            topArea.tap()
        }
        _ = Self.waitForHittable(button, timeout: 5)
        button.tap()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    /// 6.1 — Search for B, send a friend request, verify Request Sent state.
    func testSearchAndSendRequest() throws {
        try signUp(email: aEmail, password: aPassword, displayName: aDisplayName, username: aUsername)
        navigateToFriendsTab()

        let searchField = app.textFields["friendSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(bUsername)

        let resultRow = app.buttons["searchResult_\(bUsername)"]
        XCTAssertTrue(
            resultRow.waitForExistence(timeout: 15),
            "Search result for fixture B should appear"
        )
        resultRow.tap()

        let addFriend = app.buttons["addFriendButton"]
        XCTAssertTrue(addFriend.waitForExistence(timeout: 10))
        addFriend.tap()

        XCTAssertTrue(
            app.staticTexts["requestSentLabel"].waitForExistence(timeout: 10),
            "Request Sent label should appear after tapping Add Friend"
        )

        app.buttons["userProfileDoneButton"].tap()
        try deleteAccount()
    }

    /// 6.2 — Full handshake: A sends, B accepts, both see each other in friends.
    func testAcceptRequest() throws {
        try signUp(email: aEmail, password: aPassword, displayName: aDisplayName, username: aUsername)
        sendFriendRequest(toUsername: bUsername)

        try signOut()
        try signIn(email: bEmail, password: bPassword)

        navigateToFriendsTab()
        let banner = app.buttons["pendingRequestsBanner"]
        XCTAssertTrue(
            banner.waitForExistence(timeout: 15),
            "Pending requests banner should appear for B after A's request"
        )
        banner.tap()

        let acceptButton = app.buttons["friendRequestAcceptButton_\(aUsername)"]
        // Sheet may have many rows (orphan friend requests from prior failed runs).
        // Scroll the sheet's ScrollView until our row is visible.
        var scrollAttempts = 0
        while !acceptButton.exists && scrollAttempts < 8 {
            let sheet = app.otherElements.containing(.navigationBar, identifier: "Friend Requests").firstMatch
            sheet.swipeUp()
            scrollAttempts += 1
        }
        if !acceptButton.exists {
            // DIAG: capture state for analysis
            let screenshot = app.screenshot()
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/diag-accept-not-found.png"))
            try? app.debugDescription.write(toFile: "/tmp/diag-tree-accept-not-found.txt",
                                            atomically: true, encoding: .utf8)
        }
        XCTAssertTrue(acceptButton.waitForExistence(timeout: 5),
                      "Accept button for \(aUsername) should appear in requests sheet")
        acceptButton.tap()

        app.buttons["friendRequestsDoneButton"].tap()

        XCTAssertTrue(
            app.buttons["friendRow_\(aUsername)"].waitForExistence(timeout: 15),
            "B should see A in My Friends after accepting"
        )

        try signOut()
        try signIn(email: aEmail, password: aPassword)
        navigateToFriendsTab()

        XCTAssertTrue(
            app.buttons["friendRow_\(bUsername)"].waitForExistence(timeout: 15),
            "A should see B in My Friends after B accepted"
        )

        try deleteAccount()
    }

    /// 6.3 — A sends, B declines, A is back to "Add Friend" state, banner gone for B.
    func testDeclineRequest() throws {
        try signUp(email: aEmail, password: aPassword, displayName: aDisplayName, username: aUsername)
        sendFriendRequest(toUsername: bUsername)

        try signOut()
        try signIn(email: bEmail, password: bPassword)

        navigateToFriendsTab()
        let banner = app.buttons["pendingRequestsBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        banner.tap()

        // Sheet may have many rows (orphan friend requests from prior failed runs).
        // Scroll until our specific decline button is visible.
        let declineButton = app.buttons["friendRequestDeclineButton_\(aUsername)"]
        var declineScrollAttempts = 0
        while !declineButton.exists && declineScrollAttempts < 8 {
            let sheet = app.otherElements.containing(.navigationBar, identifier: "Friend Requests").firstMatch
            sheet.swipeUp()
            declineScrollAttempts += 1
        }
        XCTAssertTrue(declineButton.waitForExistence(timeout: 5),
                      "Decline button for \(aUsername) should appear in requests sheet")
        declineButton.tap()

        // After declining, A's specific row should be gone from the sheet
        // (other orphan requests from prior failed test runs may still exist).
        let stillThere = declineButton.waitForExistence(timeout: 3)
        XCTAssertFalse(stillThere, "A's row should be removed from the sheet after decline")

        app.buttons["friendRequestsDoneButton"].tap()

        try signOut()
        try signIn(email: aEmail, password: aPassword)
        navigateToFriendsTab()

        // Search for B and verify A is back to "Add Friend" (declined → relationshipState = .none)
        let searchField = app.textFields["friendSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(bUsername)

        let resultRow = app.buttons["searchResult_\(bUsername)"]
        XCTAssertTrue(resultRow.waitForExistence(timeout: 15))
        resultRow.tap()

        XCTAssertTrue(
            app.buttons["addFriendButton"].waitForExistence(timeout: 10),
            "After decline, A should see Add Friend (not Request Sent) — declined requests are not 'pending'"
        )

        app.buttons["userProfileDoneButton"].tap()
        try deleteAccount()
    }

    /// 6.4 — Search for nonexistent username shows the empty state.
    func testSearchEmptyState() throws {
        try signUp(email: aEmail, password: aPassword, displayName: aDisplayName, username: aUsername)
        navigateToFriendsTab()

        let searchField = app.textFields["friendSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("zxqvnoresult")

        // searchNoResultsState is on a VStack — query as otherElements or any element type
        let noResults = app.descendants(matching: .any).matching(identifier: "searchNoResultsState").firstMatch
        XCTAssertTrue(
            noResults.waitForExistence(timeout: 10),
            "No-results empty state should appear for unmatched search"
        )

        try deleteAccount()
    }

    /// 6.5 — Fresh account, no friends, friends tab shows the empty state copy.
    func testFriendsTabEmptyState() throws {
        try signUp(email: aEmail, password: aPassword, displayName: aDisplayName, username: aUsername)
        navigateToFriendsTab()

        let emptyState = app.descendants(matching: .any).matching(identifier: "friendsEmptyState").firstMatch
        XCTAssertTrue(
            emptyState.waitForExistence(timeout: 10),
            "Friends empty state should appear for fresh account"
        )

        try deleteAccount()
    }

    /// 6.6 — Share Profile button is present, tappable, and presents the share sheet.
    func testShareProfileCard() throws {
        try signUp(email: aEmail, password: aPassword, displayName: aDisplayName, username: aUsername)
        navigateToFriendsTab()

        let shareButton = app.buttons["shareProfileButton"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 10))
        XCTAssertTrue(shareButton.isHittable)
        shareButton.tap()

        // The system share sheet — exact identifier varies by iOS version. Probe several.
        let activitySheet = app.otherElements["ActivityListView"]
        let sharePresented = activitySheet.waitForExistence(timeout: 5)
            || app.sheets.firstMatch.waitForExistence(timeout: 1)

        XCTAssertTrue(sharePresented, "Share sheet should be presented")

        // Dismiss
        app.swipeDown()

        try deleteAccount()
    }

    /// 6.7 — After accepting, B appears in A's leaderboard tab.
    func testLeaderboardReflectsAcceptedFriend() throws {
        try signUp(email: aEmail, password: aPassword, displayName: aDisplayName, username: aUsername)
        sendFriendRequest(toUsername: bUsername)

        try signOut()
        try signIn(email: bEmail, password: bPassword)
        acceptFriendRequest(fromUsername: aUsername)

        try signOut()
        try signIn(email: aEmail, password: aPassword)

        app.tabBars.buttons["League"].tap()
        let leaderboardTab = app.buttons["socialTab_leaderboard"]
        XCTAssertTrue(leaderboardTab.waitForExistence(timeout: 5))
        leaderboardTab.tap()

        // Leaderboard rows are buttons; B's row will contain B's display name.
        // Search by predicate since rows don't have stable identifiers in the leaderboard.
        let bRowPredicate = NSPredicate(format: "label CONTAINS %@", Self.bDisplayName)
        let bRow = app.buttons.matching(bRowPredicate).firstMatch
        XCTAssertTrue(
            bRow.waitForExistence(timeout: 15),
            "B's row should appear in A's leaderboard after accepting friendship"
        )

        try deleteAccount()
    }

    // MARK: - Helpers

    private func signUp(email: String, password: String, displayName: String, username: String) throws {
        let createAccountTab = app.buttons["createAccountTab"]
        XCTAssertTrue(createAccountTab.waitForExistence(timeout: 5))
        createAccountTab.tap()

        let emailField = app.textFields["emailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["passwordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["authSubmitButton"].tap()

        let nameField = app.textFields["nameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(displayName)

        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText(username)
        usernameField.typeText("\n")

        app.swipeUp()
        let comfortButton = app.buttons["comfortOption_1"]
        XCTAssertTrue(comfortButton.waitForExistence(timeout: 5))
        comfortButton.tap()

        app.swipeUp()
        let letsGoButton = app.buttons["letsGoButton"]
        XCTAssertTrue(letsGoButton.waitForExistence(timeout: 5))
        letsGoButton.tap()

        let startButton = app.buttons["Start practicing"]
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 30),
            "WelcomeSplashView should appear — ensure Supabase email confirmation is disabled"
        )
        startButton.tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20))
    }

    private func signIn(email: String, password: String) throws {
        let signInTab = app.buttons["signInTab"]
        XCTAssertTrue(signInTab.waitForExistence(timeout: 10))
        signInTab.tap()

        let emailField = app.textFields["emailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["passwordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["authSubmitButton"].tap()

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(
            homeTab.waitForExistence(timeout: 20),
            "Home tab should appear after signing in"
        )
        _ = Self.waitForHittable(homeTab, timeout: 15)
    }

    private func signOut() throws {
        tapTabBarButton("Profile")

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let signOutButton = app.buttons["signOutButton"]
        var attempts = 0
        while !signOutButton.exists && attempts < 5 {
            app.otherElements.containing(.navigationBar, identifier: "Settings")
                .scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(signOutButton.waitForExistence(timeout: 5))
        signOutButton.tap()

        let confirm = app.alerts["Sign Out"].buttons["Sign Out"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(
            app.textFields["emailField"].waitForExistence(timeout: 15),
            "AuthView should appear after sign out"
        )
    }

    private func deleteAccount() throws {
        tapTabBarButton("Profile")

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        let deleteButton = app.buttons["deleteAccountButton"]
        var attempts = 0
        while !deleteButton.exists && attempts < 5 {
            app.otherElements.containing(.navigationBar, identifier: "Settings")
                .scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let confirm = app.alerts["Delete Account"].buttons["Delete Account"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(
            app.textFields["emailField"].waitForExistence(timeout: 25),
            "AuthView should reappear after account deletion"
        )
    }

    private func navigateToFriendsTab() {
        tapTabBarButton("League")
        let friendsTab = app.buttons["socialTab_friends"]
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 10))
        friendsTab.tap()
    }

    private func sendFriendRequest(toUsername username: String) {
        navigateToFriendsTab()

        let searchField = app.textFields["friendSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(username)

        let resultRow = app.buttons["searchResult_\(username)"]
        XCTAssertTrue(resultRow.waitForExistence(timeout: 15))
        resultRow.tap()

        let addFriend = app.buttons["addFriendButton"]
        XCTAssertTrue(addFriend.waitForExistence(timeout: 10))
        addFriend.tap()

        XCTAssertTrue(app.staticTexts["requestSentLabel"].waitForExistence(timeout: 10))
        app.buttons["userProfileDoneButton"].tap()
    }

    private func acceptFriendRequest(fromUsername username: String) {
        navigateToFriendsTab()

        let banner = app.buttons["pendingRequestsBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        banner.tap()

        let acceptButton = app.buttons["friendRequestAcceptButton_\(username)"]
        XCTAssertTrue(acceptButton.waitForExistence(timeout: 10))
        acceptButton.tap()

        app.buttons["friendRequestsDoneButton"].tap()
    }
}
