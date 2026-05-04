# Parlance Frontend Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the Parlance iOS app's visual style with the parlance-site marketing website by upgrading shared components, fixing hardcoded color tokens, replacing the Home header with a brand wordmark, and adding a missing border to the Results recap card.

**Architecture:** Shared components first (PillBadge, SectionHeader) so all call-site updates compile cleanly, then isolated screen-level changes. All changes are pure SwiftUI view edits — no model, service, or data layer changes.

**Tech Stack:** SwiftUI, Swift, Xcode. Tests run via `⌘U` in Xcode using the Swift Testing framework (`ParlanceTests` target). UI changes verified by build success; visual correctness checked in Xcode Previews or Simulator.

**Spec:** `docs/superpowers/specs/2026-05-03-parlance-frontend-alignment-design.md`

---

## File Map

| File | What changes |
|------|-------------|
| `Parlance/UI/Components/PillBadge.swift` | Add optional `emoji` param; render HStack(spacing: 7) when present |
| `Parlance/UI/Components/SectionHeader.swift` | `bodyBold(11)` + `AppColors.sub` |
| `Parlance/UI/Components/XPProgressBar.swift` | `#333333` → `AppColors.sub` |
| `Parlance/Features/Home/HomeView.swift` | Wordmark header; streak HStack spacing 4 → 6; PillBadge call site (streak pill uses PillBadge via ProfileView only — HomeView uses a manual HStack, no PillBadge to update here) |
| `Parlance/Features/Home/DailyChallengeCard.swift` | Split emoji from text in PillBadge call |
| `Parlance/Features/Session/RecordingView.swift` | Split emoji in 2 PillBadge calls; `#252525` → `AppColors.faint` |
| `Parlance/Features/Results/ResultsView.swift` | Split emoji in PillBadge call; 2 token fixes; add border to `questionRecapCard` |
| `Parlance/Features/Profile/ProfileView.swift` | Split emoji in PillBadge call; `#2A2A2A` → `AppColors.dim` |

---

## Task 1: Refactor PillBadge to Support Separate Emoji

**Files:**
- Modify: `Parlance/UI/Components/PillBadge.swift`

- [ ] **Step 1: Replace PillBadge implementation**

Open `Parlance/UI/Components/PillBadge.swift` and replace the entire file contents:

```swift
import SwiftUI

struct PillBadge: View {
    let text: String
    var emoji: String? = nil
    var color: Color = AppColors.gold
    var small: Bool = false

    var body: some View {
        HStack(spacing: emoji != nil ? 7 : 0) {
            if let emoji {
                Text(emoji)
                    .font(.system(size: small ? 11 : 13))
            }
            Text(text)
                .font(AppFonts.bodyBold(small ? 10 : 12))
                .kerning(small ? 0.5 : 0)
        }
        .foregroundStyle(color)
        .padding(.horizontal, small ? 9 : 13)
        .padding(.vertical, small ? 3 : 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Build to confirm no regressions**

In Xcode: `⌘B`. Expected: Build Succeeded. Existing call sites still compile because `emoji` defaults to `nil` — the combined `"💼 Interview"` strings still work for now, they just won't get the new spacing until updated in the next task.

---

## Task 2: Update All PillBadge Call Sites

**Files:**
- Modify: `Parlance/Features/Home/DailyChallengeCard.swift:23`
- Modify: `Parlance/Features/Session/RecordingView.swift:53,84`
- Modify: `Parlance/Features/Results/ResultsView.swift:111`
- Modify: `Parlance/Features/Profile/ProfileView.swift:212`

- [ ] **Step 1: Update DailyChallengeCard**

In `DailyChallengeCard.swift` line 23, change the mode pill call:

```swift
// Before
PillBadge(text: "\(mode.emoji) \(mode.displayName)", color: mode.accentColor, small: true)

// After
PillBadge(emoji: mode.emoji, text: mode.displayName, color: mode.accentColor, small: true)
```

- [ ] **Step 2: Update RecordingView — mode pill**

In `RecordingView.swift` line 53, change the mode pill:

```swift
// Before
PillBadge(text: "\(mode.emoji) \(mode.displayName)", color: mode.accentColor, small: true)

// After
PillBadge(emoji: mode.emoji, text: mode.displayName, color: mode.accentColor, small: true)
```

- [ ] **Step 3: Update RecordingView — duration pill**

In `RecordingView.swift` line 84, change the duration pill:

```swift
// Before
PillBadge(text: "⏱ \(question.targetDuration)s", color: mode.accentColor, small: true)

// After
PillBadge(emoji: "⏱", text: "\(question.targetDuration)s", color: mode.accentColor, small: true)
```

- [ ] **Step 4: Update ResultsView — mode pill**

In `ResultsView.swift` line 111, change the mode pill:

```swift
// Before
PillBadge(
    text: "\(session.mode.emoji) \(session.mode.displayName)",
    color: session.mode.accentColor,
    small: true
)

// After
PillBadge(
    emoji: session.mode.emoji,
    text: session.mode.displayName,
    color: session.mode.accentColor,
    small: true
)
```

- [ ] **Step 5: Update ProfileView — streak pill**

In `ProfileView.swift` line 212, change the streak pill:

```swift
// Before
PillBadge(text: "\u{1F525} \(user.currentStreak)-day streak", color: AppColors.gold, small: true)

// After
PillBadge(emoji: "🔥", text: "\(user.currentStreak)-day streak", color: AppColors.gold, small: true)
```

- [ ] **Step 6: Build to confirm all call sites compile**

`⌘B`. Expected: Build Succeeded.

---

## Task 3: Upgrade SectionHeader

**Files:**
- Modify: `Parlance/UI/Components/SectionHeader.swift`

- [ ] **Step 1: Update font and color**

Open `Parlance/UI/Components/SectionHeader.swift` and replace the file:

```swift
import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppFonts.bodyBold(11))
            .foregroundStyle(AppColors.sub)
            .kerning(1.2)
    }
}
```

- [ ] **Step 2: Build**

`⌘B`. Expected: Build Succeeded. This change propagates to Home, Progress, Profile, League, and Results automatically — all use `SectionHeader`.

---

## Task 4: Fix Hardcoded Color Tokens

**Files:**
- Modify: `Parlance/UI/Components/XPProgressBar.swift:41`
- Modify: `Parlance/Features/Session/RecordingView.swift:166`
- Modify: `Parlance/Features/Results/ResultsView.swift:223,253,391,429`
- Modify: `Parlance/Features/Profile/ProfileView.swift:567`

- [ ] **Step 1: Fix XPProgressBar — "XP to" text**

In `XPProgressBar.swift` around line 41, find:

```swift
Text(nextRank.name)
    .font(AppFonts.bodyBold(11))
    .foregroundStyle(AppColors.gold)
```

The line just above it (`Text("\(remaining) XP to")`) has the hardcoded color. Change it:

```swift
// Before
Text("\(remaining) XP to")
    .font(AppFonts.body(11))
    .foregroundStyle(Color(hex: "#333333"))

// After
Text("\(remaining) XP to")
    .font(AppFonts.body(11))
    .foregroundStyle(AppColors.sub)
```

- [ ] **Step 2: Fix RecordingView — inactive timer color**

In `RecordingView.swift` around line 166, find the timer Text and change its inactive color:

```swift
// Before
.foregroundStyle(recorder.isRecording ? AppColors.gold : Color(hex: "#252525"))

// After
.foregroundStyle(recorder.isRecording ? AppColors.gold : AppColors.faint)
```

- [ ] **Step 3: Fix ResultsView — AI feedback text color**

In `ResultsView.swift` in the `aiCoachCard` computed property, find the feedback body Text and change its color. There are two occurrences of `Color(red: 0.73, green: 0.73, blue: 0.73)` — one for the feedback text and one in `highlightedTranscript`. Change both:

```swift
// In aiCoachCard — feedback text
// Before
.foregroundStyle(Color(red: 0.73, green: 0.73, blue: 0.73)) // #BBB

// After
.foregroundStyle(AppColors.dim)
```

```swift
// In highlightedTranscript — base color
// Before
attr.foregroundColor = Color(red: 0.73, green: 0.73, blue: 0.73)

// After
attr.foregroundColor = AppColors.dim
```

- [ ] **Step 4: Fix ResultsView — moment quote text colors**

In `ResultsView.swift` in `aiMomentCard` and `momentCard`, find the quote/timestamp text colors:

```swift
// In aiMomentCard — quote text
// Before
.foregroundStyle(Color(red: 0.73, green: 0.73, blue: 0.73))

// After
.foregroundStyle(AppColors.dim)
```

```swift
// In momentCard — timestamp+text
// Before
.foregroundStyle(Color(red: 0.667, green: 0.667, blue: 0.667)) // #AAA

// After
.foregroundStyle(AppColors.dim)
```

- [ ] **Step 5: Fix ProfileView — footer text**

In `ProfileView.swift` in `footerSection`, find:

```swift
// Before
.foregroundStyle(Color(hex: "#2A2A2A"))

// After
.foregroundStyle(AppColors.dim)
```

- [ ] **Step 6: Build**

`⌘B`. Expected: Build Succeeded.

---

## Task 5: Home Screen — Wordmark Header + Streak Spacing

**Files:**
- Modify: `Parlance/Features/Home/HomeView.swift`

- [ ] **Step 1: Replace headerRow**

In `HomeView.swift`, replace the entire `// MARK: - Header` section and `headerRow` computed property:

```swift
// MARK: - Header

private var headerRow: some View {
    HStack(alignment: .center) {
        HStack(spacing: 0) {
            Text("Parlance")
                .font(AppFonts.display(28))
                .foregroundStyle(AppColors.text)
            Text(".")
                .font(AppFonts.display(28))
                .foregroundStyle(AppColors.gold)
        }

        Spacer()

        if let user {
            HStack(spacing: 6) {
                Text("🔥")
                    .font(.system(size: 13))
                Text("\(user.currentStreak)")
                    .font(AppFonts.bodyBold(13))
                    .foregroundStyle(AppColors.gold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppColors.card)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }
}
```

Key changes from before:
- Left side: `HStack(spacing: 0)` with `"Parlance"` (white) + `"."` (gold), no `if let user` guard
- Right side: streak pill `HStack` spacing changed from `4` → `6`, `if let user` guard retained

- [ ] **Step 2: Build**

`⌘B`. Expected: Build Succeeded.

---

## Task 6: Results — Add Missing Border to Recap Card

**Files:**
- Modify: `Parlance/Features/Results/ResultsView.swift`

- [ ] **Step 1: Add border overlay to questionRecapCard**

In `ResultsView.swift`, find the `questionRecapCard` computed property. It ends with `.clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))`. Add the border overlay immediately after:

```swift
// Before (end of questionRecapCard)
.frame(maxWidth: .infinity, alignment: .leading)
.padding(15)
.background(AppColors.card)
.clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))

// After
.frame(maxWidth: .infinity, alignment: .leading)
.padding(15)
.background(AppColors.card)
.clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
.overlay(
    RoundedRectangle(cornerRadius: AppConstants.cardRadius)
        .stroke(AppColors.border, lineWidth: 1)
)
```

- [ ] **Step 2: Build and run tests**

`⌘B` then `⌘U`. Expected: Build Succeeded, all existing tests pass.

---

## Task 7: Final Verification

- [ ] **Step 1: Run the full test suite**

`⌘U`. Expected: All tests in `ParlanceTests` pass.

- [ ] **Step 2: Smoke-check in Simulator**

Run the app (`⌘R`) on any iPhone simulator. Verify:
- Home tab shows `"Parlance."` wordmark (white + gold period) in the header, no greeting
- Streak pill (🔥 + number) has visible breathing room between emoji and digit
- Mode pills in Recording screen show `"💼  Job Interview"` with clear spacing between emoji and text
- Duration pill in Recording shows `"⏱  60s"` with spacing
- Section headers (Today's Challenge, Practice Modes, etc.) are visibly bolder
- Results screen: "You Spoke On" recap card has a visible border matching the other cards
- Profile footer "Parlance v1.0" is visible (was near-invisible before in dark mode)
- XP bar "X XP to [rank]" text is legible

- [ ] **Step 3: Check light mode**

In Simulator: Settings → Developer → Appearance → Light. Re-run and verify the token-fixed colors (footer, XP bar sub-text) look correct in light mode too.
