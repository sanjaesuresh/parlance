import XCTest

// Shared XCUITest helpers used across E2E suites.
//
// Background: SwiftUI on iOS 17+ sometimes reports a TextField's
// `accessibilityActivationPoint` as {-1, -1} when the field is nested inside
// padded card containers (e.g. `setupField { TextField(...) }`). The result is
// that `.tap()` fails with "Not hittable" even though the element is visible
// and a human could tap it. The workaround is a coordinate-based tap at the
// element's frame center, which bypasses activation-point computation.

extension XCUIElement {
    /// Wait until this element becomes hittable. Returns `false` on timeout.
    @discardableResult
    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [exp], timeout: timeout) == .completed
    }

    /// Tap robustly. Falls back to a coordinate tap when `isHittable` is false,
    /// which catches the SwiftUI {-1, -1} activation-point case.
    func safeTap() {
        _ = waitForHittable(timeout: 5)
        if isHittable {
            tap()
        } else {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}

extension XCUIApplication {
    /// Send Return to the focused element to dismiss the SwiftUI keyboard.
    /// More reliable than swipeDown (which can trigger unintended scrolls).
    func dismissKeyboard() {
        guard keyboards.element.exists else { return }
        let returnKey = keyboards.buttons["return"]
        if returnKey.exists {
            returnKey.tap()
        } else {
            typeText("\n")
        }
    }

    /// Tap a text field and wait for the keyboard to appear. The coordinate-tap
    /// fallback occasionally lands without raising the keyboard immediately;
    /// retry once if focus didn't take. After this returns, `typeText` is safe.
    func tapAndFocus(_ field: XCUIElement) {
        field.safeTap()
        if !keyboards.element.waitForExistence(timeout: 2) {
            field.safeTap()
            _ = keyboards.element.waitForExistence(timeout: 3)
        }
    }

    /// Switch to a tab bar tab, verifying the switch actually took. On iOS 26
    /// SwiftUI tab bars sometimes drop the first tap (animation race), so we
    /// retry with a coordinate tap until a recognizable post-switch element
    /// appears.
    ///
    /// - Parameters:
    ///   - identifier: tab bar button's accessibility label (e.g. "Profile").
    ///   - postSwitchProbe: an element that's only present after the switch.
    ///   - maxAttempts: number of tap attempts before giving up.
    @discardableResult
    func switchTab(
        _ identifier: String,
        verifyVisible postSwitchProbe: XCUIElement,
        maxAttempts: Int = 4
    ) -> Bool {
        let tab = tabBars.buttons[identifier]
        guard tab.waitForExistence(timeout: 10) else { return false }
        _ = tab.waitForHittable(timeout: 10)

        for attempt in 0..<maxAttempts {
            if attempt == 0 {
                tab.tap()
            } else {
                tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            if postSwitchProbe.waitForExistence(timeout: 3) {
                return true
            }
        }
        return false
    }
}
