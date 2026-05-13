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
        // Don't early-return on `keyboards.element.exists` — XCUI reports the
        // keyboard as non-existent transiently right after typeText, even
        // while it's still up. Just probe the buttons directly: the existence
        // check on each candidate is cheap and authoritative.
        for label in ["return", "Return", "Next", "Done", "Continue", "Go", "Search", "Send"] {
            let key = keyboards.buttons[label]
            if key.exists {
                key.tap()
                return
            }
        }
        // Fallback: type a newline at the app level. Empirically this dismisses
        // the keyboard / advances focus on iOS 26 simulators even though the
        // comment in older XCUITest sample code says it shouldn't on modern
        // SwiftUI. Only reached when no labeled key was found.
        typeText("\n")
    }

    /// Tap a text field and wait until *that specific field* has keyboard
    /// focus. Keyboard-existence alone is insufficient: when switching between
    /// adjacent SwiftUI TextFields the keyboard stays up, and a misfired tap
    /// can leave the previous field focused, causing `typeText` to fail with
    /// "Neither element nor any descendant has keyboard focus". Retries with
    /// a coordinate tap if focus doesn't land on the target element.
    ///
    /// Always uses a coordinate-based tap rather than `.tap()` — SwiftUI
    /// TextFields nested in padded containers can pass `isHittable` and then
    /// fail the synthesized event with "Not hittable" because their
    /// `accessibilityActivationPoint` reports as {-1, -1}. With
    /// `continueAfterFailure = false` that crashes the test before our retry
    /// loop can recover. Coordinate taps bypass the activation-point path.
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
        // Wait for the element to settle on-screen before tapping; the
        // scroll-to-focused-field animation can move the frame mid-tap.
        _ = field.waitForHittable(timeout: 5)
        for _ in 0..<maxAttempts {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let exp = XCTNSPredicateExpectation(predicate: focusPredicate, object: field)
            if XCTWaiter().wait(for: [exp], timeout: 2) == .completed {
                return
            }
        }
    }

    /// Advance keyboard focus from `currentField` to `nextField`. On some iOS
    /// 26 simulators (notably 393pt-wide devices) plain coordinate taps on the
    /// next field don't transfer focus while the keyboard is up and the
    /// previous field is still focused — `typeText` then fails with "Neither
    /// element nor any descendant has keyboard focus." This walks through a
    /// chain of strategies, verifying focus moved after each before giving up.
    func advanceFocus(from currentField: XCUIElement, to nextField: XCUIElement, timeout: TimeInterval = 6) {
        // Poll for focus rather than XCTNSPredicateExpectation, so we can
        // observe focus landing on either field without recording a system
        // failure on accessibilityActivationPoint == {-1,-1}.
        let focusPredicate = NSPredicate(format: "hasKeyboardFocus == true")
        func hasFocus(_ element: XCUIElement) -> Bool {
            element.exists && focusPredicate.evaluate(with: element)
        }
        func currentlyFocused() -> XCUIElement? {
            if hasFocus(nextField) { return nextField }
            if hasFocus(currentField) { return currentField }
            return nil
        }
        func waitForFocusOnNext(_ seconds: Double) -> Bool {
            let deadline = Date().addingTimeInterval(seconds)
            while Date() < deadline {
                if hasFocus(nextField) { return true }
                Thread.sleep(forTimeInterval: 0.1)
            }
            return false
        }

        // Strategy 1: tap a labeled keyboard key that fires SwiftUI's onSubmit
        // → onSubmit advances focus via @FocusState binding. SwiftUI's focus
        // propagation can lag the tap by a few hundred ms, so give it 2.5s
        // before deciding the tap missed.
        for label in ["Next", "next", "Return", "return", "Done", "done", "Continue", "Go", "go", "Search", "Send"] {
            let key = keyboards.buttons[label]
            if key.exists {
                key.tap()
                if waitForFocusOnNext(2.5) { return }
                break
            }
        }

        // Strategy 2: send a newline into whatever field currently holds
        // focus. Only safe if the *previous* field still has focus — if a
        // labeled-key tap above succeeded but our wait read it too early,
        // focus is already on nextField and typeText("\n") into currentField
        // would crash with "no keyboard focus."
        if let focused = currentlyFocused() {
            if focused == nextField { return }
            focused.typeText("\n")
            if waitForFocusOnNext(2.5) { return }
        }

        // Strategy 3: coordinate-tap nextField directly. Works on larger
        // sims where focus transfers cleanly via a fresh tap.
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            nextField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if waitForFocusOnNext(1.5) { return }
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
