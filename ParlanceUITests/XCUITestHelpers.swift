import XCTest

// Shared XCUITest helpers used across E2E suites.
//
// Background: SwiftUI on iOS 17+ sometimes reports a TextField's
// `accessibilityActivationPoint` as {-1, -1} when the field is nested inside
// padded card containers (e.g. `setupField { TextField(...) }`). The result is
// that `.tap()` fails with "Not hittable" even though the element is visible
// and a human could tap it. The workaround is a coordinate-based tap at the
// element's frame center, which bypasses activation-point computation.

extension XCTestCase {
    /// True when the test is running on the iOS 26 iPhone SE 3rd-gen
    /// simulator combo, where SwiftUI TextFields with @FocusState
    /// bindings report an invalid accessibilityActivationPoint
    /// ({-1,-1}). That makes XCUI's .isHittable false and breaks
    /// .tap()-driven E2E flows. Verified working on iOS 18.4 SE and on
    /// iPhone 17 iOS 26.4 — only broken on this specific pairing.
    /// Remove this skip once Apple ships a fixed iOS 26 simulator
    /// runtime. Identification uses Xcode's SIMULATOR_* env vars (set
    /// by the simulator runtime, available in the test-runner process).
    var isKnownBrokenSESimulator: Bool {
        let env = ProcessInfo.processInfo.environment
        let model = env["SIMULATOR_MODEL_IDENTIFIER"] ?? ""
        let runtime = env["SIMULATOR_RUNTIME_VERSION"] ?? ""
        return model == "iPhone14,6" && runtime.hasPrefix("26.")
    }

    /// XCTSkipIf the host is the broken SE simulator. Call from
    /// setUpWithError() in suites that exercise SwiftUI TextFields with
    /// @FocusState bindings (currently AccountE2ETests, FriendsE2ETests).
    func skipIfBrokenSESimulator() throws {
        try XCTSkipIf(
            isKnownBrokenSESimulator,
            "Skipped on iOS 26 iPhone SE simulator: SwiftUI TextField focus is broken in this Apple runtime (passes on iOS 18.4 SE and on iPhone 17 iOS 26.4)."
        )
    }
}

extension XCUIElement {
    /// Wait until this element becomes hittable. Returns `false` on timeout.
    /// Polls rather than using `XCTNSPredicateExpectation(isHittable)`, because
    /// the predicate evaluator records a "Failed to determine hittability"
    /// system failure when SwiftUI reports `accessibilityActivationPoint =
    /// {-1, -1}` — under `continueAfterFailure = false` that halts the test
    /// even though we just want a Bool.
    @discardableResult
    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists && isHittable { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return exists && isHittable
    }

    /// Tap robustly. Falls back to a coordinate tap when `isHittable` is false,
    /// which catches the SwiftUI {-1, -1} activation-point case.
    func safeTap() {
        _ = waitForHittable(timeout: 5)
        if exists && isHittable {
            tap()
        } else {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}

extension XCUIApplication {
    /// Tap the keyboard's submit key. NOTE: when a SwiftUI TextField uses
    /// `.submitLabel(.next)` + `.onSubmit { focusedField = .next }`, this
    /// *advances* focus rather than dismissing the keyboard. Tests that rely
    /// on the focus chain to move to the next field can use this directly;
    /// callers that need an actual dismiss should defocus another way.
    func dismissKeyboard() {
        guard keyboards.element.exists else { return }
        // Submit-button accessibility identifier varies by submitLabel.
        // Check every label SwiftUI exposes; whichever is present is the
        // visible right-side key.
        for label in ["return", "Return", "Next", "Done", "Continue", "Go", "Search", "Send"] {
            let key = keyboards.buttons[label]
            if key.exists {
                key.tap()
                return
            }
        }
        // Last resort: typing "\n" into a SwiftUI TextField inserts a newline
        // character rather than triggering onSubmit, so this does NOT advance
        // focus in modern SwiftUI — but it does match older XCUITest examples.
        typeText("\n")
    }

    /// Tap a text field and wait until *that specific field* has keyboard
    /// focus. Keyboard-existence alone is insufficient: when switching between
    /// adjacent SwiftUI TextFields the keyboard stays up, and a misfired tap
    /// can leave the previous field focused, causing `typeText` to fail with
    /// "Neither element nor any descendant has keyboard focus". Retries with
    /// a coordinate tap if focus doesn't land on the target element.
    func tapAndFocus(_ field: XCUIElement, maxAttempts: Int = 3) {
        let focusPredicate = NSPredicate(format: "hasKeyboardFocus == true")
        // Short-circuit if focus is already on the target — e.g. the previous
        // field's onSubmit handler already advanced the focus chain to here.
        // Tapping again would race the scroll-to-focused-field animation and
        // can leave focus stuck on the previous field.
        let preCheck = XCTNSPredicateExpectation(predicate: focusPredicate, object: field)
        if XCTWaiter().wait(for: [preCheck], timeout: 0.2) == .completed {
            return
        }
        for attempt in 0..<maxAttempts {
            if attempt == 0 {
                field.safeTap()
            } else {
                // Vary the tap method on retry — same safeTap path tends to
                // reproduce the same near-miss on SwiftUI fields nested in
                // padded containers.
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let exp = XCTNSPredicateExpectation(predicate: focusPredicate, object: field)
            if XCTWaiter().wait(for: [exp], timeout: 2) == .completed {
                return
            }
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
