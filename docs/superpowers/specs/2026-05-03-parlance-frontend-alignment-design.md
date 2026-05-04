# Parlance Frontend Alignment — Design Spec
**Date:** 2026-05-03  
**Scope:** Align app UI with parlance-site marketing aesthetic  
**Approach:** Shared components first, then screen-specific changes  

---

## Background

The parlance-site marketing website establishes a clear visual identity: Playfair Display + DM Sans typography, a warm gold (#E8A838) accent, beige/dark surfaces, and generous spacing. The app's design tokens already match the site closely. The gaps are in: (A) brand presence, (B) typography weight/visibility, (D) spacing, and specific screens — primarily Home and Results.

Profile screen was reviewed and kept as-is by user preference.

---

## Section 1 — Shared Components & Token Cleanup

### 1a. PillBadge — Emoji/Text Spacing
**File:** `Parlance/UI/Components/PillBadge.swift`

Add an optional `emoji: String?` parameter. When present, render an `HStack(spacing: 7)` with the emoji in a slightly smaller font alongside the label text. When absent, render text-only as before.

```swift
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

**Update all call sites** that currently pass emoji-prefixed strings:
- `RecordingView` — mode pill: `PillBadge(emoji: mode.emoji, text: mode.displayName, color: mode.accentColor, small: true)`
- `RecordingView` — duration pill: `PillBadge(emoji: "⏱", text: "\(question.targetDuration)s", color: mode.accentColor, small: true)`
- `ResultsView` — mode pill: `PillBadge(emoji: session.mode.emoji, text: session.mode.displayName, color: session.mode.accentColor, small: true)`
- `DailyChallengeCard` — mode pill: `PillBadge(emoji: mode.emoji, text: mode.displayName, color: mode.accentColor, small: true)`
- `ProfileView` — streak pill: `PillBadge(emoji: "🔥", text: "\(user.currentStreak)-day streak", color: AppColors.gold, small: true)`

Call sites with no emoji (e.g. `"LVL 3"`, `"Lv 3"`, `"Gold League"`) are unchanged — `emoji` defaults to `nil`.

### 1b. Streak Pill in HomeView — Spacing
**File:** `Parlance/Features/Home/HomeView.swift`

In `headerRow`, change the streak `HStack` spacing:
```swift
// Before
HStack(spacing: 4) {

// After  
HStack(spacing: 6) {
```

### 1c. SectionHeader — Weight & Visibility
**File:** `Parlance/UI/Components/SectionHeader.swift`

```swift
// Before
.font(AppFonts.bodyMedium(11))
.foregroundStyle(AppColors.dim)

// After
.font(AppFonts.bodyBold(11))
.foregroundStyle(AppColors.sub)
```

Effect: every section label across Home, Progress, Profile, League, and Results becomes slightly more readable. No structural change.

### 1d. Hardcoded Color Token Fixes
Replace raw hex/rgb values with the appropriate `AppColors` tokens:

| File | Location | Before | After |
|------|----------|--------|-------|
| `XPProgressBar.swift` | "X XP to [rank]" text | `Color(hex: "#333333")` | `AppColors.sub` |
| `RecordingView.swift` | Timer text (inactive state) | `Color(hex: "#252525")` | `AppColors.faint` |
| `ResultsView.swift` | AI coach feedback body text | `Color(red: 0.73, green: 0.73, blue: 0.73)` | `AppColors.dim` |
| `ResultsView.swift` | Moment quote text | `Color(red: 0.667, green: 0.667, blue: 0.667)` | `AppColors.dim` |
| `ProfileView.swift` | Footer "Parlance v1.0…" | `Color(hex: "#2A2A2A")` | `AppColors.dim` |

---

## Section 2 — Home Screen Header

**File:** `Parlance/Features/Home/HomeView.swift`

Replace the `headerRow` computed property. Remove the personalized greeting (greeting label + user display name). Replace with the "Parlance." wordmark in Playfair Display Bold, gold period.

```swift
// Before
VStack(alignment: .leading, spacing: 2) {
    Text(user.greeting.uppercased())
        .font(AppFonts.body(11))
        .foregroundStyle(AppColors.dim)
        .kerning(1.2)
    Text("\(user.displayName).")
        .font(AppFonts.display(28))
        .foregroundStyle(AppColors.text)
}

// After
HStack(spacing: 0) {
    Text("Parlance")
        .font(AppFonts.display(28))
        .foregroundStyle(AppColors.text)
    Text(".")
        .font(AppFonts.display(28))
        .foregroundStyle(AppColors.gold)
}
```

The streak pill on the right side of `headerRow` is unchanged and still wrapped in `if let user` (it needs `user.currentStreak`). The left side's `if let user` guard is removed — the wordmark is unconditional and needs no user data.

**No other changes** to HomeView — spacing, card layout, daily challenge card, difficulty slider, mode grid, and weekly stats are all working well.

---

## Section 3 — Profile Screen

**No changes.** Profile screen kept as-is per user preference.

---

## Section 4 — Results Screen (Minor)

**File:** `Parlance/Features/Results/ResultsView.swift`

The `questionRecapCard` is the only card on the Results screen without a border stroke overlay. All other cards (`aiCoachCard`, `transcriptCard`, moment cards, `upNextCard`) have one. Add the missing overlay:

```swift
// In questionRecapCard, after .clipShape(...)
.overlay(
    RoundedRectangle(cornerRadius: AppConstants.cardRadius)
        .stroke(AppColors.border, lineWidth: 1)
)
```

---

## Files Changed

| File | Change |
|------|--------|
| `UI/Components/PillBadge.swift` | Add `emoji` parameter, HStack(spacing: 7) |
| `UI/Components/SectionHeader.swift` | bodyBold, AppColors.sub |
| `UI/Components/XPProgressBar.swift` | Token fix |
| `Features/Home/HomeView.swift` | Wordmark header, streak spacing: 6 |
| `Features/Session/RecordingView.swift` | Token fix + PillBadge call site |
| `Features/Results/ResultsView.swift` | Token fixes + missing border + PillBadge call site |
| `Features/Home/DailyChallengeCard.swift` | PillBadge call site |
| `Features/Profile/ProfileView.swift` | Token fix + PillBadge call site |

---

## What Was Explicitly Kept

- Profile screen structure and header (user preference)
- All spacing values (VStack spacing: 20, card padding: 16, etc.)
- All color tokens (already aligned with marketing site)
- RecordingView layout (already closely matches marketing site mockup)
- Results screen layout except the one missing border
- DailyChallengeCard gradient (already premium)
- Mode card designs and tier pills
