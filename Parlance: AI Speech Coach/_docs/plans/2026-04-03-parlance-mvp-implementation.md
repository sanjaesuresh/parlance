# Parlance MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Parlance iOS MVP — a gamified speech coaching app with 4 practice modes, real audio recording, on-device speech analysis, AI coach feedback via Claude Haiku, and full gamification (XP, ranks, streaks, daily challenge, achievements, weekly league tiers).

**Architecture:** SwiftUI app with SwiftData persistence, AVFoundation audio recording, SFSpeechRecognizer transcription, heuristic-based speech metrics, and a single Claude Haiku API call per session routed through a Cloudflare Worker proxy. Questions come from a static bundled JSON bank (400+ questions). All gamification is local-only. Dark theme, portrait-only, iOS 17+.

**Tech Stack:** SwiftUI, SwiftData, AVFoundation, Speech framework, URLSession, Cloudflare Workers (JS), TelemetryDeck SDK

**Source root:** `Parlance: AI Speech Coach/Parlance: AI Speech Coach/` (referred to as `$SRC` below for brevity)

**Test target:** `Parlance: AI Speech CoachTests/` (referred to as `$TEST` below)

---

## Phase 1: Design System & Theme Foundation

### Task 1: Color Tokens

**Files:**
- Create: `$SRC/UI/Theme/AppColors.swift`
- Create: `$SRC/UI/Extensions/Color+Hex.swift`
- Create: `$TEST/UI/Theme/AppColorsTests.swift`

- [ ] **Step 1: Write failing test for hex color initialization**

```swift
// $TEST/UI/Theme/AppColorsTests.swift
import XCTest
import SwiftUI
@testable import Parlance__AI_Speech_Coach

final class AppColorsTests: XCTestCase {
    func testHexInitialization() {
        let color = Color(hex: "#E8A838")
        XCTAssertNotNil(color)
    }

    func testAllColorTokensExist() {
        // Verify all design system tokens resolve to non-nil
        let tokens: [Color] = [
            AppColors.bg, AppColors.card, AppColors.border,
            AppColors.gold, AppColors.red, AppColors.purple,
            AppColors.teal, AppColors.text, AppColors.sub
        ]
        XCTAssertEqual(tokens.count, 9)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project "Parlance: AI Speech Coach.xcodeproj" -scheme "Parlance: AI Speech Coach" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"Parlance: AI Speech CoachTests/AppColorsTests" 2>&1 | tail -20`
Expected: FAIL — `Color+Hex.swift` and `AppColors.swift` don't exist

- [ ] **Step 3: Implement Color+Hex extension**

```swift
// $SRC/UI/Extensions/Color+Hex.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double((rgbValue & 0x0000FF)) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 4: Implement AppColors**

```swift
// $SRC/UI/Theme/AppColors.swift
import SwiftUI

enum AppColors {
    static let bg = Color(hex: "#0D0D0D")
    static let card = Color(hex: "#111111")
    static let border = Color(hex: "#1E1E1E")
    static let gold = Color(hex: "#E8A838")
    static let red = Color(hex: "#E05A4E")
    static let purple = Color(hex: "#7B68EE")
    static let teal = Color(hex: "#3BB5A0")
    static let text = Color.white
    static let sub = Color(hex: "#888888")
}
```

- [ ] **Step 5: Run tests and verify they pass**

Run: same xcodebuild command as Step 2
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "$SRC/UI/Theme/AppColors.swift" "$SRC/UI/Extensions/Color+Hex.swift" "$TEST/UI/Theme/AppColorsTests.swift"
git commit -m "feat: add color tokens and hex color extension"
```

---

### Task 2: Typography System

**Files:**
- Create: `$SRC/UI/Theme/AppFonts.swift`

- [ ] **Step 1: Add Playfair Display and DM Sans font files**

Download Playfair Display (Bold) and DM Sans (Regular, Medium, Bold) `.ttf` files. Add to `$SRC/Resources/Fonts/`. Register in Info.plist under `UIAppFonts`:
```xml
<key>UIAppFonts</key>
<array>
    <string>PlayfairDisplay-Bold.ttf</string>
    <string>DMSans-Regular.ttf</string>
    <string>DMSans-Medium.ttf</string>
    <string>DMSans-Bold.ttf</string>
</array>
```

Ensure all 4 files are added to the app target's "Copy Bundle Resources" build phase.

- [ ] **Step 2: Implement AppFonts**

```swift
// $SRC/UI/Theme/AppFonts.swift
import SwiftUI

enum AppFonts {
    // Display — scores, timer, headings
    static func display(_ size: CGFloat) -> Font {
        .custom("PlayfairDisplay-Bold", size: size)
    }

    // Body — labels, buttons, paragraphs
    static func body(_ size: CGFloat) -> Font {
        .custom("DMSans-Regular", size: size)
    }

    static func bodyMedium(_ size: CGFloat) -> Font {
        .custom("DMSans-Medium", size: size)
    }

    static func bodyBold(_ size: CGFloat) -> Font {
        .custom("DMSans-Bold", size: size)
    }
}
```

- [ ] **Step 3: Verify fonts load in a SwiftUI preview**

Create a temporary preview in `AppFonts.swift`:
```swift
#Preview {
    VStack(spacing: 12) {
        Text("Score: 87").font(AppFonts.display(32))
        Text("Body text").font(AppFonts.body(16))
        Text("Medium text").font(AppFonts.bodyMedium(16))
        Text("Bold text").font(AppFonts.bodyBold(16))
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColors.bg)
}
```

Build the preview in Xcode. Confirm all 4 fonts render correctly (not falling back to system font). Remove the preview after verification.

- [ ] **Step 4: Commit**

```bash
git add "$SRC/UI/Theme/AppFonts.swift" "$SRC/Resources/Fonts/" "Parlance: AI Speech Coach/Info.plist"
git commit -m "feat: add typography system with Playfair Display and DM Sans"
```

---

### Task 3: Design Constants & Card Style

**Files:**
- Create: `$SRC/UI/Theme/AppConstants.swift`
- Create: `$SRC/UI/Extensions/View+CardStyle.swift`

- [ ] **Step 1: Implement AppConstants**

```swift
// $SRC/UI/Theme/AppConstants.swift
import Foundation

enum AppConstants {
    static let cardRadius: CGFloat = 18
    static let maxRecordingDuration: TimeInterval = 180 // 3 minutes
    static let minRecordingDuration: TimeInterval = 5
    static let wrapUpWarningTime: TimeInterval = 165 // 2:45
    static let deliberateNudgeTime: TimeInterval = 8
    static let loadingMinDuration: TimeInterval = 0.5
    static let maxSessionsPerDay = 20
    static let maxNameLength = 30
    static let transcriptExcerptLength = 400 // words
    static let seenQuestionWindow = 50
    static let waveformBarCount = 38
    static let baseXP = 120
    static let dailyChallengeXP = 200
    static let feedbackTimeout: TimeInterval = 8
}
```

- [ ] **Step 2: Implement View+CardStyle**

```swift
// $SRC/UI/Extensions/View+CardStyle.swift
import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                    .stroke(AppColors.border, lineWidth: 1)
            )
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add "$SRC/UI/Theme/AppConstants.swift" "$SRC/UI/Extensions/View+CardStyle.swift"
git commit -m "feat: add design constants and card style modifier"
```

---

## Phase 2: Data Models

### Task 4: SessionMode Enum

**Files:**
- Create: `$SRC/Core/Models/SessionMode.swift`
- Create: `$TEST/Core/Models/SessionModeTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// $TEST/Core/Models/SessionModeTests.swift
import XCTest
@testable import Parlance__AI_Speech_Coach

final class SessionModeTests: XCTestCase {
    func testAllModesExist() {
        let modes: [SessionMode] = [.interview, .pitch, .keynote, .casual]
        XCTAssertEqual(modes.count, 4)
    }

    func testModeDisplayNames() {
        XCTAssertEqual(SessionMode.interview.displayName, "Job Interview")
        XCTAssertEqual(SessionMode.pitch.displayName, "Pitch / Sales")
        XCTAssertEqual(SessionMode.keynote.displayName, "Keynote / Talk")
        XCTAssertEqual(SessionMode.casual.displayName, "Daily Convo")
    }

    func testModeEmojis() {
        XCTAssertEqual(SessionMode.interview.emoji, "💼")
        XCTAssertEqual(SessionMode.pitch.emoji, "🚀")
        XCTAssertEqual(SessionMode.keynote.emoji, "🎤")
        XCTAssertEqual(SessionMode.casual.emoji, "💬")
    }

    func testModeAccentColors() {
        // Just verify they don't crash
        for mode in SessionMode.allCases {
            _ = mode.accentColor
        }
    }

    func testDailyChallengeRotation() {
        // Mon=Interview, Tue=Pitch, Wed=Keynote, Thu=Casual, Fri=Interview, Sat=Pitch, Sun=Keynote
        XCTAssertEqual(SessionMode.dailyChallengeMode(weekday: 2), .interview)  // Monday
        XCTAssertEqual(SessionMode.dailyChallengeMode(weekday: 3), .pitch)      // Tuesday
        XCTAssertEqual(SessionMode.dailyChallengeMode(weekday: 4), .keynote)    // Wednesday
        XCTAssertEqual(SessionMode.dailyChallengeMode(weekday: 5), .casual)     // Thursday
        XCTAssertEqual(SessionMode.dailyChallengeMode(weekday: 6), .interview)  // Friday
        XCTAssertEqual(SessionMode.dailyChallengeMode(weekday: 7), .pitch)      // Saturday
        XCTAssertEqual(SessionMode.dailyChallengeMode(weekday: 1), .keynote)    // Sunday
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `SessionMode` not defined

- [ ] **Step 3: Implement SessionMode**

```swift
// $SRC/Core/Models/SessionMode.swift
import SwiftUI

enum SessionMode: String, CaseIterable, Codable {
    case interview
    case pitch
    case keynote
    case casual

    var displayName: String {
        switch self {
        case .interview: "Job Interview"
        case .pitch: "Pitch / Sales"
        case .keynote: "Keynote / Talk"
        case .casual: "Daily Convo"
        }
    }

    var emoji: String {
        switch self {
        case .interview: "💼"
        case .pitch: "🚀"
        case .keynote: "🎤"
        case .casual: "💬"
        }
    }

    var accentColor: Color {
        switch self {
        case .interview: AppColors.gold
        case .pitch: Color(hex: "#E8A838") // orange-gold
        case .keynote: AppColors.purple
        case .casual: AppColors.teal
        }
    }

    /// Returns the daily challenge mode for a given weekday (1=Sun, 2=Mon, ..., 7=Sat)
    static func dailyChallengeMode(weekday: Int) -> SessionMode {
        switch weekday {
        case 2: .interview  // Monday
        case 3: .pitch      // Tuesday
        case 4: .keynote    // Wednesday
        case 5: .casual     // Thursday
        case 6: .interview  // Friday
        case 7: .pitch      // Saturday
        case 1: .keynote    // Sunday
        default: .interview
        }
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Core/Models/SessionMode.swift" "$TEST/Core/Models/SessionModeTests.swift"
git commit -m "feat: add SessionMode enum with display names, colors, daily rotation"
```

---

### Task 5: Difficulty & Rank Systems

**Files:**
- Create: `$SRC/Core/Models/DifficultyLevel.swift`
- Create: `$SRC/Core/Models/Rank.swift`
- Create: `$TEST/Core/Models/DifficultyLevelTests.swift`
- Create: `$TEST/Core/Models/RankTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// $TEST/Core/Models/DifficultyLevelTests.swift
import XCTest
@testable import Parlance__AI_Speech_Coach

final class DifficultyLevelTests: XCTestCase {
    func testLevelNames() {
        XCTAssertEqual(DifficultyLevel.name(for: 1), "Nervous Novice")
        XCTAssertEqual(DifficultyLevel.name(for: 5), "Confident Communicator")
        XCTAssertEqual(DifficultyLevel.name(for: 10), "Elite Orator")
    }

    func testTierNames() {
        XCTAssertEqual(DifficultyLevel.tier(for: 1), "Starter")
        XCTAssertEqual(DifficultyLevel.tier(for: 4), "Challenging")
        XCTAssertEqual(DifficultyLevel.tier(for: 6), "Intermediate")
        XCTAssertEqual(DifficultyLevel.tier(for: 8), "Advanced")
        XCTAssertEqual(DifficultyLevel.tier(for: 10), "Expert")
    }

    func testDifficultyBand() {
        XCTAssertEqual(DifficultyLevel.band(for: 1), "1-2")
        XCTAssertEqual(DifficultyLevel.band(for: 2), "1-2")
        XCTAssertEqual(DifficultyLevel.band(for: 5), "5-6")
        XCTAssertEqual(DifficultyLevel.band(for: 10), "9-10")
    }
}
```

```swift
// $TEST/Core/Models/RankTests.swift
import XCTest
@testable import Parlance__AI_Speech_Coach

final class RankTests: XCTestCase {
    func testRankForXP() {
        XCTAssertEqual(Rank.from(xp: 0).level, 1)
        XCTAssertEqual(Rank.from(xp: 499).level, 1)
        XCTAssertEqual(Rank.from(xp: 500).level, 2)
        XCTAssertEqual(Rank.from(xp: 1200).level, 3)
        XCTAssertEqual(Rank.from(xp: 30000).level, 10)
    }

    func testRankNames() {
        XCTAssertEqual(Rank.from(xp: 0).name, "Newcomer")
        XCTAssertEqual(Rank.from(xp: 30000).name, "Master")
    }

    func testXPForNextRank() {
        let rank = Rank.from(xp: 600)
        XCTAssertEqual(rank.level, 2)
        XCTAssertEqual(rank.xpForNextRank, 1200)
    }

    func testMaxRankHasNoNext() {
        let rank = Rank.from(xp: 30000)
        XCTAssertTrue(rank.isMaxRank)
        XCTAssertNil(rank.xpForNextRank)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL

- [ ] **Step 3: Implement DifficultyLevel**

```swift
// $SRC/Core/Models/DifficultyLevel.swift
import Foundation

enum DifficultyLevel {
    private static let names: [Int: String] = [
        1: "Nervous Novice", 2: "First-Timer",
        3: "Getting Warmed Up", 4: "Emerging Orator",
        5: "Confident Communicator", 6: "Polished Speaker",
        7: "Compelling Storyteller", 8: "Stage Commander",
        9: "Master Presenter", 10: "Elite Orator"
    ]

    static func name(for level: Int) -> String {
        names[level] ?? "Unknown"
    }

    static func tier(for level: Int) -> String {
        switch level {
        case 1...2: "Starter"
        case 3...4: "Challenging"
        case 5...6: "Intermediate"
        case 7...8: "Advanced"
        case 9...10: "Expert"
        default: "Unknown"
        }
    }

    static func band(for level: Int) -> String {
        switch level {
        case 1...2: "1-2"
        case 3...4: "3-4"
        case 5...6: "5-6"
        case 7...8: "7-8"
        case 9...10: "9-10"
        default: "1-2"
        }
    }
}
```

- [ ] **Step 4: Implement Rank**

```swift
// $SRC/Core/Models/Rank.swift
import Foundation

struct Rank {
    let level: Int
    let name: String
    let xpRequired: Int
    let xpForNextRank: Int?

    var isMaxRank: Bool { level == 10 }

    private static let thresholds: [(level: Int, name: String, xp: Int)] = [
        (1, "Newcomer", 0),
        (2, "Apprentice", 500),
        (3, "Practitioner", 1200),
        (4, "Communicator", 2500),
        (5, "Rhetorician", 4500),
        (6, "Debater", 7000),
        (7, "Presenter", 10500),
        (8, "Orator", 15000),
        (9, "Virtuoso", 21000),
        (10, "Master", 30000)
    ]

    static func from(xp: Int) -> Rank {
        var current = thresholds[0]
        var nextXP: Int? = thresholds[1].xp

        for i in 0..<thresholds.count {
            if xp >= thresholds[i].xp {
                current = thresholds[i]
                nextXP = i + 1 < thresholds.count ? thresholds[i + 1].xp : nil
            }
        }

        return Rank(level: current.level, name: current.name, xpRequired: current.xp, xpForNextRank: nextXP)
    }
}
```

- [ ] **Step 5: Run tests and verify they pass**

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add "$SRC/Core/Models/DifficultyLevel.swift" "$SRC/Core/Models/Rank.swift" \
  "$TEST/Core/Models/DifficultyLevelTests.swift" "$TEST/Core/Models/RankTests.swift"
git commit -m "feat: add difficulty level system and XP rank progression"
```

---

### Task 6: League Tier

**Files:**
- Create: `$SRC/Core/Models/LeagueTier.swift`
- Create: `$TEST/Core/Models/LeagueTierTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// $TEST/Core/Models/LeagueTierTests.swift
import XCTest
@testable import Parlance__AI_Speech_Coach

final class LeagueTierTests: XCTestCase {
    func testTierFromWeeklyXP() {
        XCTAssertEqual(LeagueTier.from(weeklyXP: 0), .bronze)
        XCTAssertEqual(LeagueTier.from(weeklyXP: 599), .bronze)
        XCTAssertEqual(LeagueTier.from(weeklyXP: 600), .silver)
        XCTAssertEqual(LeagueTier.from(weeklyXP: 1500), .gold)
        XCTAssertEqual(LeagueTier.from(weeklyXP: 3000), .platinum)
        XCTAssertEqual(LeagueTier.from(weeklyXP: 6000), .diamond)
    }

    func testTierXPForNext() {
        XCTAssertEqual(LeagueTier.bronze.xpForNextTier, 600)
        XCTAssertEqual(LeagueTier.diamond.xpForNextTier, nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement LeagueTier**

```swift
// $SRC/Core/Models/LeagueTier.swift
import SwiftUI

enum LeagueTier: String, CaseIterable {
    case bronze, silver, gold, platinum, diamond

    var displayName: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .bronze: Color(hex: "#CD7F32")
        case .silver: Color(hex: "#C0C0C0")
        case .gold: AppColors.gold
        case .platinum: Color(hex: "#E5E4E2")
        case .diamond: Color(hex: "#B9F2FF")
        }
    }

    var minXP: Int {
        switch self {
        case .bronze: 0
        case .silver: 600
        case .gold: 1500
        case .platinum: 3000
        case .diamond: 6000
        }
    }

    var xpForNextTier: Int? {
        switch self {
        case .bronze: 600
        case .silver: 1500
        case .gold: 3000
        case .platinum: 6000
        case .diamond: nil
        }
    }

    static func from(weeklyXP: Int) -> LeagueTier {
        if weeklyXP >= 6000 { return .diamond }
        if weeklyXP >= 3000 { return .platinum }
        if weeklyXP >= 1500 { return .gold }
        if weeklyXP >= 600 { return .silver }
        return .bronze
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Core/Models/LeagueTier.swift" "$TEST/Core/Models/LeagueTierTests.swift"
git commit -m "feat: add weekly league tier system"
```

---

### Task 7: SwiftData Models — User, Session, Achievement, SeenQuestion

**Files:**
- Create: `$SRC/Core/Models/User.swift`
- Create: `$SRC/Core/Models/Session.swift`
- Create: `$SRC/Core/Models/Achievement.swift`
- Create: `$SRC/Core/Models/SeenQuestion.swift`

- [ ] **Step 1: Implement User model**

```swift
// $SRC/Core/Models/User.swift
import Foundation
import SwiftData

@Model
final class User {
    var displayName: String
    var avatarEmoji: String
    var joinDate: Date
    var xp: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastSessionDate: Date?
    var practiceLevel: Int
    var hasCompletedSetup: Bool
    var dailySessionCount: Int
    var lastDailySessionDate: Date?
    var dailyChallengeLevelLock: Int?
    var dailyChallengeLockDate: Date?

    init(
        displayName: String,
        avatarEmoji: String,
        joinDate: Date = .now,
        xp: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastSessionDate: Date? = nil,
        practiceLevel: Int = 1,
        hasCompletedSetup: Bool = false,
        dailySessionCount: Int = 0,
        lastDailySessionDate: Date? = nil,
        dailyChallengeLevelLock: Int? = nil,
        dailyChallengeLockDate: Date? = nil
    ) {
        self.displayName = displayName
        self.avatarEmoji = avatarEmoji
        self.joinDate = joinDate
        self.xp = xp
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastSessionDate = lastSessionDate
        self.practiceLevel = practiceLevel
        self.hasCompletedSetup = hasCompletedSetup
        self.dailySessionCount = dailySessionCount
        self.lastDailySessionDate = lastDailySessionDate
        self.dailyChallengeLevelLock = dailyChallengeLevelLock
        self.dailyChallengeLockDate = dailyChallengeLockDate
    }

    var rank: Rank { Rank.from(xp: xp) }

    var isAtDailyLimit: Bool { dailySessionCount >= AppConstants.maxSessionsPerDay }

    /// Returns the greeting based on current hour
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
```

- [ ] **Step 2: Implement Session model**

```swift
// $SRC/Core/Models/Session.swift
import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var date: Date
    var modeRaw: String
    var difficultyLevel: Int
    var duration: TimeInterval
    var transcript: String
    var overallScore: Int
    var fillerCount: Int
    var paceScore: Int
    var clarityScore: Int
    var structureScore: Int
    var vocabularyScore: Int
    var question: String
    var aiCoachFeedback: String?
    var bestMomentTimestamp: TimeInterval
    var bestMomentText: String
    var worstMomentTimestamp: TimeInterval
    var worstMomentText: String
    var xpEarned: Int
    var wasDailyChallenge: Bool

    var mode: SessionMode {
        get { SessionMode(rawValue: modeRaw) ?? .interview }
        set { modeRaw = newValue.rawValue }
    }

    /// Returns true if transcription was unavailable (metrics show as "—")
    var hasTranscript: Bool { !transcript.isEmpty }

    init(
        mode: SessionMode,
        difficultyLevel: Int,
        duration: TimeInterval,
        transcript: String,
        overallScore: Int,
        fillerCount: Int,
        paceScore: Int,
        clarityScore: Int,
        structureScore: Int,
        vocabularyScore: Int,
        question: String,
        aiCoachFeedback: String? = nil,
        bestMomentTimestamp: TimeInterval = 0,
        bestMomentText: String = "",
        worstMomentTimestamp: TimeInterval = 0,
        worstMomentText: String = "",
        xpEarned: Int,
        wasDailyChallenge: Bool
    ) {
        self.id = UUID()
        self.date = .now
        self.modeRaw = mode.rawValue
        self.difficultyLevel = difficultyLevel
        self.duration = duration
        self.transcript = transcript
        self.overallScore = overallScore
        self.fillerCount = fillerCount
        self.paceScore = paceScore
        self.clarityScore = clarityScore
        self.structureScore = structureScore
        self.vocabularyScore = vocabularyScore
        self.question = question
        self.aiCoachFeedback = aiCoachFeedback
        self.bestMomentTimestamp = bestMomentTimestamp
        self.bestMomentText = bestMomentText
        self.worstMomentTimestamp = worstMomentTimestamp
        self.worstMomentText = worstMomentText
        self.xpEarned = xpEarned
        self.wasDailyChallenge = wasDailyChallenge
    }
}
```

- [ ] **Step 3: Implement Achievement model**

```swift
// $SRC/Core/Models/Achievement.swift
import Foundation
import SwiftData

@Model
final class Achievement {
    @Attribute(.unique) var id: String
    var name: String
    var descriptionText: String
    var iconName: String
    var isUnlocked: Bool
    var unlockedDate: Date?
    var progress: Int
    var goal: Int

    var progressFraction: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(progress) / Double(goal))
    }

    init(id: String, name: String, descriptionText: String, iconName: String, goal: Int) {
        self.id = id
        self.name = name
        self.descriptionText = descriptionText
        self.iconName = iconName
        self.isUnlocked = false
        self.unlockedDate = nil
        self.progress = 0
        self.goal = goal
    }

    static let definitions: [(id: String, name: String, description: String, icon: String, goal: Int)] = [
        ("first_session", "First Session", "Complete your first session", "mic.fill", 1),
        ("streak_7", "7-Day Streak", "Practice 7 days in a row", "flame.fill", 7),
        ("interview_pro", "Interview Pro", "Complete 10 interview sessions", "briefcase.fill", 10),
        ("score_80", "Score 80+", "Achieve an overall score of 80 or higher", "star.fill", 1),
        ("zero_fillers", "Zero Fillers", "Complete a session with 0 filler words", "checkmark.seal.fill", 1),
        ("rank_5", "Rank 5", "Reach Rank 5 (Rhetorician)", "trophy.fill", 1),
        ("sessions_30", "30 Sessions", "Complete 30 total sessions", "repeat", 30),
        ("master", "Master", "Reach Rank 10", "crown.fill", 1)
    ]
}
```

- [ ] **Step 4: Implement SeenQuestion model**

```swift
// $SRC/Core/Models/SeenQuestion.swift
import Foundation
import SwiftData

@Model
final class SeenQuestion {
    var questionId: String
    var modeRaw: String
    var difficultyBand: String
    var seenAt: Date

    var mode: SessionMode {
        SessionMode(rawValue: modeRaw) ?? .interview
    }

    init(questionId: String, mode: SessionMode, difficultyBand: String) {
        self.questionId = questionId
        self.modeRaw = mode.rawValue
        self.difficultyBand = difficultyBand
        self.seenAt = .now
    }
}
```

- [ ] **Step 5: Build the project to verify models compile**

Run: `xcodebuild build -project "Parlance: AI Speech Coach.xcodeproj" -scheme "Parlance: AI Speech Coach" -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add "$SRC/Core/Models/User.swift" "$SRC/Core/Models/Session.swift" \
  "$SRC/Core/Models/Achievement.swift" "$SRC/Core/Models/SeenQuestion.swift"
git commit -m "feat: add SwiftData models — User, Session, Achievement, SeenQuestion"
```

---

### Task 8: Question Bank Data Model

**Files:**
- Create: `$SRC/Core/Models/Question.swift`
- Create: `$TEST/Core/Models/QuestionTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// $TEST/Core/Models/QuestionTests.swift
import XCTest
@testable import Parlance__AI_Speech_Coach

final class QuestionTests: XCTestCase {
    func testDecodeFromJSON() throws {
        let json = """
        {
            "id": "interview_1_1",
            "mode": "interview",
            "difficultyBand": "1-2",
            "question": "Tell me about yourself.",
            "tips": ["Keep it under 90 seconds", "Focus on relevance", "End with why you're here"],
            "targetDuration": 90,
            "difficultyNote": "Starter — broad personal question"
        }
        """.data(using: .utf8)!

        let question = try JSONDecoder().decode(Question.self, from: json)
        XCTAssertEqual(question.id, "interview_1_1")
        XCTAssertEqual(question.mode, .interview)
        XCTAssertEqual(question.difficultyBand, "1-2")
        XCTAssertEqual(question.tips.count, 3)
        XCTAssertEqual(question.targetDuration, 90)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement Question**

```swift
// $SRC/Core/Models/Question.swift
import Foundation

struct Question: Codable, Identifiable {
    let id: String
    let mode: SessionMode
    let difficultyBand: String
    let question: String
    let tips: [String]
    let targetDuration: Int
    let difficultyNote: String
}
```

- [ ] **Step 4: Run tests and verify they pass**

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Core/Models/Question.swift" "$TEST/Core/Models/QuestionTests.swift"
git commit -m "feat: add Question model with JSON decoding"
```

---

## Phase 3: Core Services

### Task 9: Persistence Service

**Files:**
- Create: `$SRC/Core/Services/PersistenceService.swift`

- [ ] **Step 1: Implement PersistenceService**

```swift
// $SRC/Core/Services/PersistenceService.swift
import Foundation
import SwiftData

@MainActor
final class PersistenceService {
    static let shared = PersistenceService()

    let container: ModelContainer

    private init() {
        let schema = Schema([User.self, Session.self, Achievement.self, SeenQuestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// For testing — in-memory container
    static func inMemory() -> ModelContainer {
        let schema = Schema([User.self, Session.self, Achievement.self, SeenQuestion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    var context: ModelContext { container.mainContext }

    // MARK: - User

    func getUser() -> User? {
        let descriptor = FetchDescriptor<User>()
        return try? context.fetch(descriptor).first
    }

    func createUser(name: String, avatar: String) -> User {
        let user = User(displayName: name, avatarEmoji: avatar, hasCompletedSetup: true)
        context.insert(user)
        try? context.save()
        return user
    }

    // MARK: - Sessions

    func saveSesssion(_ session: Session) {
        context.insert(session)
        try? context.save()
    }

    func recentSessions(limit: Int = 16) -> [Session] {
        var descriptor = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func sessionsThisWeek() -> [Session] {
        let calendar = Calendar.current
        let now = Date.now
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let predicate = #Predicate<Session> { $0.date >= weekStart }
        let descriptor = FetchDescriptor<Session>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func totalSessionCount() -> Int {
        let descriptor = FetchDescriptor<Session>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func interviewSessionCount() -> Int {
        let modeRaw = SessionMode.interview.rawValue
        let predicate = #Predicate<Session> { $0.modeRaw == modeRaw }
        let descriptor = FetchDescriptor<Session>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Achievements

    func getAchievements() -> [Achievement] {
        let descriptor = FetchDescriptor<Achievement>(sortBy: [SortDescriptor(\.id)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func seedAchievementsIfNeeded() {
        let existing = getAchievements()
        guard existing.isEmpty else { return }
        for def in Achievement.definitions {
            let achievement = Achievement(
                id: def.id, name: def.name,
                descriptionText: def.description, iconName: def.icon, goal: def.goal
            )
            context.insert(achievement)
        }
        try? context.save()
    }

    func unlockAchievement(id: String) {
        let achievements = getAchievements()
        guard let achievement = achievements.first(where: { $0.id == id }),
              !achievement.isUnlocked else { return }
        achievement.isUnlocked = true
        achievement.unlockedDate = .now
        achievement.progress = achievement.goal
        try? context.save()
    }

    func updateAchievementProgress(id: String, progress: Int) {
        let achievements = getAchievements()
        guard let achievement = achievements.first(where: { $0.id == id }) else { return }
        achievement.progress = min(progress, achievement.goal)
        if achievement.progress >= achievement.goal && !achievement.isUnlocked {
            achievement.isUnlocked = true
            achievement.unlockedDate = .now
        }
        try? context.save()
    }

    // MARK: - Seen Questions

    func markQuestionSeen(questionId: String, mode: SessionMode, band: String) {
        let seen = SeenQuestion(questionId: questionId, mode: mode, difficultyBand: band)
        context.insert(seen)
        try? context.save()
    }

    func seenQuestionIds(mode: SessionMode, band: String) -> Set<String> {
        let modeRaw = mode.rawValue
        let predicate = #Predicate<SeenQuestion> {
            $0.modeRaw == modeRaw && $0.difficultyBand == band
        }
        var descriptor = FetchDescriptor<SeenQuestion>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.seenAt, order: .reverse)]
        )
        descriptor.fetchLimit = AppConstants.seenQuestionWindow
        let results = (try? context.fetch(descriptor)) ?? []
        return Set(results.map(\.questionId))
    }

    // MARK: - Reset

    func resetAllData() {
        try? context.delete(model: Session.self)
        try? context.delete(model: Achievement.self)
        try? context.delete(model: SeenQuestion.self)
        try? context.delete(model: User.self)
        try? context.save()
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add "$SRC/Core/Services/PersistenceService.swift"
git commit -m "feat: add PersistenceService with SwiftData CRUD for all models"
```

---

### Task 10: Question Bank Service

**Files:**
- Create: `$SRC/Core/Services/QuestionBankService.swift`
- Create: `$TEST/Core/Services/QuestionBankServiceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// $TEST/Core/Services/QuestionBankServiceTests.swift
import XCTest
@testable import Parlance__AI_Speech_Coach

final class QuestionBankServiceTests: XCTestCase {
    func testLoadQuestionsFromBundle() throws {
        let service = QuestionBankService()
        let questions = service.allQuestions
        XCTAssertGreaterThanOrEqual(questions.count, 400, "Must have at least 400 questions")
    }

    func testQuestionsExistForAllModeBands() {
        let service = QuestionBankService()
        let modes: [SessionMode] = [.interview, .pitch, .keynote, .casual]
        let bands = ["1-2", "3-4", "5-6", "7-8", "9-10"]

        for mode in modes {
            for band in bands {
                let filtered = service.questions(for: mode, band: band)
                XCTAssertGreaterThanOrEqual(
                    filtered.count, 20,
                    "Need ≥20 questions for \(mode.rawValue) band \(band), got \(filtered.count)"
                )
            }
        }
    }

    func testSelectQuestionExcludesSeen() {
        let service = QuestionBankService()
        let allInterview = service.questions(for: .interview, band: "1-2")
        let allIds = Set(allInterview.map(\.id))
        // Exclude all but one
        let excludeIds = Set(allIds.dropLast())
        let selected = service.selectQuestion(mode: .interview, band: "1-2", excludingIds: excludeIds)
        XCTAssertNotNil(selected)
        XCTAssertFalse(excludeIds.contains(selected!.id))
    }

    func testSelectQuestionResetsWhenAllSeen() {
        let service = QuestionBankService()
        let allInterview = service.questions(for: .interview, band: "1-2")
        let allIds = Set(allInterview.map(\.id))
        // Exclude all — should still return a question (pool reset)
        let selected = service.selectQuestion(mode: .interview, band: "1-2", excludingIds: allIds)
        XCTAssertNotNil(selected)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement QuestionBankService**

```swift
// $SRC/Core/Services/QuestionBankService.swift
import Foundation

final class QuestionBankService {
    let allQuestions: [Question]

    init() {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let questions = try? JSONDecoder().decode([Question].self, from: data) else {
            fatalError("Failed to load questions.json from bundle. This should never happen in production.")
        }
        self.allQuestions = questions
    }

    /// For testing with injected data
    init(questions: [Question]) {
        self.allQuestions = questions
    }

    func questions(for mode: SessionMode, band: String) -> [Question] {
        allQuestions.filter { $0.mode == mode && $0.difficultyBand == band }
    }

    func selectQuestion(mode: SessionMode, band: String, excludingIds: Set<String>) -> Question? {
        let eligible = questions(for: mode, band: band)
        let unseen = eligible.filter { !excludingIds.contains($0.id) }

        if unseen.isEmpty {
            // All questions seen — reset: pick randomly from full pool
            return eligible.randomElement()
        }
        return unseen.randomElement()
    }
}
```

- [ ] **Step 4: Create a minimal placeholder `questions.json` for tests to pass**

Create `$SRC/Resources/questions.json` — a valid JSON array. This will be replaced with the full 400+ question bank in Task 30. For now, generate a minimal valid set with exactly 20 questions per mode per band (400 total) so the unit test constraint is satisfied. The structure per entry:

```json
[
  {
    "id": "interview_1-2_001",
    "mode": "interview",
    "difficultyBand": "1-2",
    "question": "Tell me about yourself.",
    "tips": ["Keep it under 90 seconds", "Focus on relevance to the role", "End with why you're here"],
    "targetDuration": 90,
    "difficultyNote": "Starter — broad personal question"
  }
]
```

Generate all 400 entries following the naming convention `{mode}_{band}_{NNN}`. Use placeholder question text like "Placeholder question for {mode} band {band} #{n}" for entries beyond the first few per band. These will be replaced with real, curated questions in Task 30.

Ensure `questions.json` is added to the app target's "Copy Bundle Resources" build phase.

- [ ] **Step 5: Run tests and verify they pass**

- [ ] **Step 6: Commit**

```bash
git add "$SRC/Core/Services/QuestionBankService.swift" "$SRC/Resources/questions.json" \
  "$TEST/Core/Services/QuestionBankServiceTests.swift"
git commit -m "feat: add QuestionBankService with selection, dedup, and placeholder bank"
```

---

### Task 11: Speech Analyzer Service

**Files:**
- Create: `$SRC/Core/Services/SpeechAnalyzer.swift`
- Create: `$TEST/Core/Services/SpeechAnalyzerTests.swift`

- [ ] **Step 1: Write failing tests for all 5 metrics**

```swift
// $TEST/Core/Services/SpeechAnalyzerTests.swift
import XCTest
@testable import Parlance__AI_Speech_Coach

final class SpeechAnalyzerTests: XCTestCase {

    // MARK: - Filler Words

    func testFillerCountZero() {
        let result = SpeechAnalyzer.analyzeFillers(in: "I built a system that increased revenue by thirty percent")
        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(result.score, 10)
    }

    func testFillerCountMultiple() {
        let result = SpeechAnalyzer.analyzeFillers(in: "Um so like I basically um did the thing you know")
        XCTAssertEqual(result.count, 5) // um, like, basically, um, you know
        XCTAssertEqual(result.score, 5)
    }

    func testFillerCountCapped() {
        // 12 fillers should still score 0
        let text = "Um uh um uh like basically um uh like sort of kind of literally done"
        let result = SpeechAnalyzer.analyzeFillers(in: text)
        XCTAssertEqual(result.score, 0)
    }

    // MARK: - Pace

    func testPaceIdeal() {
        // 150 words in 60s = 150 WPM (ideal)
        let score = SpeechAnalyzer.analyzePace(wordCount: 150, duration: 60)
        XCTAssertEqual(score.score, 10)
    }

    func testPaceTooSlow() {
        // 50 words in 60s = 50 WPM
        let score = SpeechAnalyzer.analyzePace(wordCount: 50, duration: 60)
        XCTAssertEqual(score.score, 4)
    }

    func testPaceBorderline() {
        // 120 words in 60s = 120 WPM
        let score = SpeechAnalyzer.analyzePace(wordCount: 120, duration: 60)
        XCTAssertEqual(score.score, 7)
    }

    // MARK: - Clarity

    func testClarityPerfect() {
        let text = "I led the project. We delivered on time. The client was satisfied. Revenue grew by twenty percent."
        let score = SpeechAnalyzer.analyzeClarity(in: text)
        XCTAssertEqual(score.score, 10)
    }

    func testClarityLongSentences() {
        // One sentence >25 words
        let text = "I led the project and we had to coordinate with multiple teams across different time zones which made it really challenging but we still delivered on time. Done."
        let score = SpeechAnalyzer.analyzeClarity(in: text)
        XCTAssertLessThan(score.score, 10)
    }

    // MARK: - Structure

    func testStructureFullMarks() {
        let text = "Let me start by saying the key insight. I built a comprehensive system that handled all requirements and delivered the project successfully across multiple phases. So in summary the results were excellent."
        let score = SpeechAnalyzer.analyzeStructure(in: text, mode: .pitch)
        XCTAssertEqual(score.score, 10)
    }

    func testStructureMissingOpening() {
        let text = "I built a comprehensive system that handled all requirements and delivered successfully. So in summary the results were excellent."
        let score = SpeechAnalyzer.analyzeStructure(in: text, mode: .pitch)
        XCTAssertEqual(score.score, 7) // -3 for missing opening
    }

    func testStructureSTARBonus() {
        let text = "Let me start with a situation. When I was at my previous company I was responsible for the sales pipeline. I decided to rebuild the outreach system. As a result we increased conversion by forty percent. To wrap up it was a great outcome."
        let score = SpeechAnalyzer.analyzeStructure(in: text, mode: .interview)
        XCTAssertEqual(score.score, 10) // full marks + STAR bonus capped at 10
    }

    // MARK: - Vocabulary Strength

    func testVocabularyStrengthBase() {
        // No strong verbs, no weak words, decent TTR
        let text = "The approach was clear and the team moved forward with the plan"
        let score = SpeechAnalyzer.analyzeVocabulary(in: text)
        XCTAssertGreaterThanOrEqual(score.score, 5)
        XCTAssertLessThanOrEqual(score.score, 10)
    }

    func testVocabularyWithWeakWords() {
        let text = "I did stuff and things were very bad and we just got a lot of things done basically"
        let score = SpeechAnalyzer.analyzeVocabulary(in: text)
        XCTAssertLessThan(score.score, 7) // Penalized for weak words
    }

    // MARK: - Overall Score

    func testOverallScore() {
        let metrics = SpeechAnalyzer.Metrics(
            fillerScore: 8, fillerCount: 2,
            paceScore: 10, wpm: 145,
            clarityScore: 9,
            structureScore: 7,
            vocabularyScore: 8
        )
        // mean(8,10,9,7,8) = 8.4 × 10 = 84
        XCTAssertEqual(metrics.overallScore, 84)
    }

    // MARK: - Best/Worst Moments

    func testBestWorstMoments() {
        // 30+ second transcript split into segments
        let text = "Um um uh like basically I um struggled here. I built and launched a system that reduced costs by thirty percent and grew the team significantly. Um uh like you know sort of."
        let moments = SpeechAnalyzer.detectMoments(in: text, duration: 30)
        XCTAssertFalse(moments.bestText.isEmpty)
    }

    func testShortRecordingOnlyBestMoment() {
        let text = "I built a great system"
        let moments = SpeechAnalyzer.detectMoments(in: text, duration: 15)
        XCTAssertFalse(moments.bestText.isEmpty)
        XCTAssertTrue(moments.worstText.isEmpty) // <20s, no worst moment
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement SpeechAnalyzer**

```swift
// $SRC/Core/Services/SpeechAnalyzer.swift
import Foundation

enum SpeechAnalyzer {

    struct FillerResult {
        let count: Int
        let score: Int
        let mostFrequent: String?
    }

    struct PaceResult {
        let score: Int
        let wpm: Int
        let tip: String
    }

    struct ClarityResult {
        let score: Int
        let tip: String
    }

    struct StructureResult {
        let score: Int
        let tip: String
    }

    struct VocabularyResult {
        let score: Int
        let tip: String
    }

    struct Metrics {
        let fillerScore: Int
        let fillerCount: Int
        let paceScore: Int
        let wpm: Int
        let clarityScore: Int
        let structureScore: Int
        let vocabularyScore: Int

        var overallScore: Int {
            let mean = Double(fillerScore + paceScore + clarityScore + structureScore + vocabularyScore) / 5.0
            return Int((mean * 10).rounded())
        }
    }

    struct Moments {
        let bestTimestamp: TimeInterval
        let bestText: String
        let worstTimestamp: TimeInterval
        let worstText: String
    }

    // MARK: - Filler Words

    private static let fillerPatterns: [(pattern: String, label: String)] = [
        ("\\byou know\\b", "you know"),
        ("\\bsort of\\b", "sort of"),
        ("\\bkind of\\b", "kind of"),
        ("\\bbasically\\b", "basically"),
        ("\\bliterally\\b", "literally"),
        ("\\b(?:um|umm)\\b", "um"),
        ("\\b(?:uh|uhh)\\b", "uh"),
        ("\\blike\\b", "like")
    ]

    static func analyzeFillers(in text: String) -> FillerResult {
        let lower = text.lowercased()
        var totalCount = 0
        var frequency: [String: Int] = [:]

        for (pattern, label) in fillerPatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let matches = regex?.numberOfMatches(in: lower, range: NSRange(lower.startIndex..., in: lower)) ?? 0
            totalCount += matches
            if matches > 0 {
                frequency[label, default: 0] += matches
            }
        }

        let score = max(0, 10 - totalCount)
        let mostFrequent = frequency.max(by: { $0.value < $1.value })?.key
        return FillerResult(count: totalCount, score: score, mostFrequent: mostFrequent)
    }

    // MARK: - Pace

    static func analyzePace(wordCount: Int, duration: TimeInterval) -> PaceResult {
        guard duration > 0 else { return PaceResult(score: 0, wpm: 0, tip: "No recording detected.") }
        let wpm = Int(Double(wordCount) / (duration / 60.0))
        let score: Int
        let tip: String

        switch wpm {
        case 130...160:
            score = 10
            tip = "Great pace — natural and easy to follow."
        case 110..<130:
            score = 7
            tip = "Slightly slow — increase energy and vary your pace."
        case 161...185:
            score = 7
            tip = "Slightly fast — slow down and let your points land."
        case ..<110:
            score = 4
            tip = "Too slow — increase energy and vary your pace."
        default:
            score = 4
            tip = "Too fast — slow down and breathe between points."
        }

        return PaceResult(score: score, wpm: wpm, tip: tip)
    }

    // MARK: - Clarity

    static func analyzeClarity(in text: String) -> ClarityResult {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var longPenalty = 0
        var fragmentPenalty: Double = 0

        for sentence in sentences {
            let wordCount = sentence.split(separator: " ").count
            if wordCount > 25 { longPenalty += 1 }
            if wordCount < 5 { fragmentPenalty += 0.5 }
        }

        let score = max(0, 10 - longPenalty - Int(fragmentPenalty))
        let tip: String
        if longPenalty > Int(fragmentPenalty) {
            tip = "Your sentences are running long — aim for under 20 words per idea."
        } else if fragmentPenalty > 0 {
            tip = "Some of your responses were cut short — try developing each point fully."
        } else {
            tip = "Clear and well-paced sentences — easy to follow."
        }

        return ClarityResult(score: score, tip: tip)
    }

    // MARK: - Structure

    private static let openingSignals = [
        "the key thing", "what i'd say", "to answer that", "let me start",
        "the short answer", "first and foremost", "to begin"
    ]

    private static let closingSignals = [
        "so in summary", "the bottom line", "to wrap up", "in conclusion",
        "overall", "to summarize", "the takeaway"
    ]

    private static let starPatterns: [String: [String]] = [
        "situation": ["when i", "at my previous", "in that role", "at"],
        "task": ["i was responsible for", "my goal was", "i needed to", "i had to"],
        "action": ["i decided", "i then", "what i did", "i reached out", "i built", "i led"],
        "result": ["as a result", "this led to", "the outcome was", "we achieved", "it resulted in", "by the end"]
    ]

    static func analyzeStructure(in text: String, mode: SessionMode) -> StructureResult {
        let lower = text.lowercased()
        var score = 10

        let hasOpening = openingSignals.contains { lower.contains($0) }
        let hasClosing = closingSignals.contains { lower.contains($0) }

        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let bodyWords = sentences.dropFirst().joined(separator: " ").split(separator: " ").count
        let hasMidBody = bodyWords >= 30

        if !hasOpening { score -= 3 }
        if !hasClosing { score -= 3 }
        if !hasMidBody { score -= 2 }

        // STAR bonus for interview mode
        if mode == .interview {
            var starComponents = 0
            for (_, signals) in starPatterns {
                if signals.contains(where: { lower.contains($0) }) {
                    starComponents += 1
                }
            }
            if starComponents == 4 {
                score += 1
            }
        }

        score = min(10, max(0, score))

        var tip = ""
        if !hasOpening { tip = "Start with a clear framing statement to orient your listener." }
        else if !hasClosing { tip = "Wrap up with a summary — leave them with a clear takeaway." }
        else if !hasMidBody { tip = "Develop your middle section more — add examples or detail." }
        else { tip = "Well-structured response with a clear beginning, middle, and end." }

        return StructureResult(score: score, tip: tip)
    }

    // MARK: - Vocabulary Strength

    private static let weakWords: Set<String> = [
        "stuff", "things", "whatever", "kind of", "sort of", "a lot",
        "very", "really", "basically", "just", "good", "bad", "big", "nice",
        "get", "got", "thing"
    ]

    private static let strongVerbs: Set<String> = [
        "built", "launched", "reduced", "increased", "negotiated", "convinced",
        "designed", "led", "delivered", "solved", "implemented", "grew", "cut",
        "pitched", "drove"
    ]

    private static let genericVerbs: Set<String> = [
        "did", "made", "got", "went", "had", "was", "said"
    ]

    static func analyzeVocabulary(in text: String) -> VocabularyResult {
        let lower = text.lowercased()
        let words = lower.split(separator: " ").map(String.init)
        let totalWords = words.count
        guard totalWords > 0 else {
            return VocabularyResult(score: 0, tip: "No words detected.")
        }

        var score = 7

        // Strong verb ratio
        let strongCount = words.filter { strongVerbs.contains($0) }.count
        let allVerbCount = words.filter { strongVerbs.contains($0) || genericVerbs.contains($0) }.count
        if allVerbCount > 0 && Double(strongCount) / Double(allVerbCount) > 0.15 {
            score += 1
        }

        // Type-token ratio
        let uniqueWords = Set(words)
        let ttr = Double(uniqueWords.count) / Double(totalWords)
        if ttr > 0.60 {
            score += 1
        }

        // Weak words penalty
        var uniqueWeakWordsUsed = 0
        for weak in weakWords {
            if lower.contains(weak) { uniqueWeakWordsUsed += 1 }
        }

        if uniqueWeakWordsUsed == 0 {
            score += 1
        }
        score -= min(4, uniqueWeakWordsUsed)

        // Repeated content word penalty
        let contentWords = words.filter { $0.count > 3 }
        let contentFreq = Dictionary(grouping: contentWords, by: { $0 }).mapValues(\.count)
        if contentFreq.values.contains(where: { $0 > 3 }) {
            score -= 1
        }

        // Passive construction penalty
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let passiveCount = sentences.filter { sentence in
            let s = sentence.lowercased()
            return s.contains("was ") || s.contains("were ")
        }.count
        if sentences.count > 0 && Double(passiveCount) / Double(sentences.count) > 0.25 {
            score -= 1
        }

        score = min(10, max(0, score))

        let tip: String
        if uniqueWeakWordsUsed > 2 {
            tip = "Replace vague words like 'things' and 'stuff' with specific nouns."
        } else if strongCount == 0 {
            tip = "Use stronger action verbs — 'drove' instead of 'did', 'built' instead of 'made'."
        } else if ttr <= 0.60 {
            tip = "Vary your word choice — you're reusing the same terms frequently."
        } else {
            tip = "Strong vocabulary — specific and varied word choices."
        }

        return VocabularyResult(score: score, tip: tip)
    }

    // MARK: - Full Analysis

    static func analyze(transcript: String, duration: TimeInterval, mode: SessionMode) -> Metrics {
        let wordCount = transcript.split(separator: " ").count
        let filler = analyzeFillers(in: transcript)
        let pace = analyzePace(wordCount: wordCount, duration: duration)
        let clarity = analyzeClarity(in: transcript)
        let structure = analyzeStructure(in: transcript, mode: mode)
        let vocabulary = analyzeVocabulary(in: transcript)

        return Metrics(
            fillerScore: filler.score, fillerCount: filler.count,
            paceScore: pace.score, wpm: pace.wpm,
            clarityScore: clarity.score,
            structureScore: structure.score,
            vocabularyScore: vocabulary.score
        )
    }

    // MARK: - Best/Worst Moments

    static func detectMoments(in text: String, duration: TimeInterval) -> Moments {
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty, duration > 0 else {
            return Moments(bestTimestamp: 0, bestText: "", worstTimestamp: 0, worstText: "")
        }

        let wordsPerSecond = Double(words.count) / duration
        let segmentDuration: TimeInterval = 10
        let segmentWordCount = max(1, Int(wordsPerSecond * segmentDuration))

        var segments: [(timestamp: TimeInterval, text: String)] = []
        var index = 0
        var segmentIndex = 0

        while index < words.count {
            let end = min(index + segmentWordCount, words.count)
            let segmentWords = words[index..<end]
            let segmentText = segmentWords.joined(separator: " ")
            let timestamp = Double(segmentIndex) * segmentDuration
            segments.append((timestamp, segmentText))
            index = end
            segmentIndex += 1
        }

        if duration < 20 || segments.count < 2 {
            // Short recording — best only
            let best = segments.first ?? (0, "")
            return Moments(bestTimestamp: best.timestamp, bestText: best.text, worstTimestamp: 0, worstText: "")
        }

        // Score each segment: strong verbs - fillers
        var bestScore = Int.min
        var worstScore = Int.max
        var bestSeg = segments[0]
        var worstSeg = segments[0]

        for seg in segments {
            let lower = seg.text.lowercased()
            let segWords = lower.split(separator: " ").map(String.init)
            let strongCount = segWords.filter { strongVerbs.contains($0) }.count
            let fillerResult = analyzeFillers(in: seg.text)
            let score = strongCount - fillerResult.count

            if score > bestScore {
                bestScore = score
                bestSeg = seg
            }
            if score < worstScore {
                worstScore = score
                worstSeg = seg
            }
        }

        return Moments(
            bestTimestamp: bestSeg.timestamp, bestText: bestSeg.text,
            worstTimestamp: worstSeg.timestamp, worstText: worstSeg.text
        )
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Core/Services/SpeechAnalyzer.swift" "$TEST/Core/Services/SpeechAnalyzerTests.swift"
git commit -m "feat: add SpeechAnalyzer with all 5 metrics and moment detection"
```

---

### Task 12: Audio Recorder Service

**Files:**
- Create: `$SRC/Core/Services/AudioRecorder.swift`

- [ ] **Step 1: Implement AudioRecorder**

```swift
// $SRC/Core/Services/AudioRecorder.swift
import AVFoundation
import Combine

@MainActor
final class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: AppConstants.waveformBarCount)

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private(set) var recordingURL: URL?

    var canStop: Bool { elapsedTime >= AppConstants.minRecordingDuration }
    var shouldShowNudge: Bool { elapsedTime >= AppConstants.deliberateNudgeTime && elapsedTime < AppConstants.deliberateNudgeTime + 3 }
    var shouldShowWrapUp: Bool { elapsedTime >= AppConstants.wrapUpWarningTime }

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()

        isRecording = true
        startTime = .now

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMeters()
            }
        }
    }

    func stopRecording() -> URL? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return recordingURL
    }

    func deleteRecording() {
        guard let url = recordingURL else { return }
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
    }

    private func updateMeters() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()

        if let startTime {
            elapsedTime = Date.now.timeIntervalSince(startTime)
        }

        // Auto-stop at max duration
        if elapsedTime >= AppConstants.maxRecordingDuration {
            _ = stopRecording()
            return
        }

        let power = recorder.averagePower(forChannel: 0)
        // Normalize: -160...0 dB → 0...1
        let normalizedPower = max(0, (power + 50) / 50)

        // Shift levels left and add new level
        var newLevels = audioLevels
        newLevels.removeFirst()
        newLevels.append(normalizedPower)
        audioLevels = newLevels
    }
}
```

- [ ] **Step 2: Build to verify compilation**

- [ ] **Step 3: Commit**

```bash
git add "$SRC/Core/Services/AudioRecorder.swift"
git commit -m "feat: add AudioRecorder with AVFoundation, metering, and auto-stop"
```

---

### Task 13: Speech Transcriber Service

**Files:**
- Create: `$SRC/Core/Services/SpeechTranscriber.swift`

- [ ] **Step 1: Implement SpeechTranscriber**

```swift
// $SRC/Core/Services/SpeechTranscriber.swift
import Speech

final class SpeechTranscriber {
    enum TranscriptionError: Error {
        case notAvailable
        case recognitionFailed(String)
    }

    static func transcribe(url: URL) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.notAvailable
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error.localizedDescription))
                    return
                }
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

- [ ] **Step 3: Commit**

```bash
git add "$SRC/Core/Services/SpeechTranscriber.swift"
git commit -m "feat: add SpeechTranscriber with on-device SFSpeechRecognizer"
```

---

### Task 14: Permissions Service

**Files:**
- Create: `$SRC/Core/Services/PermissionsService.swift`

- [ ] **Step 1: Implement PermissionsService**

```swift
// $SRC/Core/Services/PermissionsService.swift
import AVFoundation
import Speech

@MainActor
final class PermissionsService: ObservableObject {
    @Published var microphoneStatus: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission
    @Published var speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()

    var microphoneGranted: Bool { microphoneStatus == .granted }
    var speechGranted: Bool { speechStatus == .authorized }

    func requestMicrophone() async -> Bool {
        let granted = await AVAudioSession.sharedInstance().requestRecordPermission()
        microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        return granted
    }

    func requestSpeechRecognition() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.speechStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

- [ ] **Step 3: Commit**

```bash
git add "$SRC/Core/Services/PermissionsService.swift"
git commit -m "feat: add PermissionsService for microphone and speech recognition"
```

---

### Task 15: Gamification Service

**Files:**
- Create: `$SRC/Core/Services/GamificationService.swift`
- Create: `$TEST/Core/Services/GamificationServiceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// $TEST/Core/Services/GamificationServiceTests.swift
import XCTest
import SwiftData
@testable import Parlance__AI_Speech_Coach

@MainActor
final class GamificationServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        container = PersistenceService.inMemory()
        context = container.mainContext
    }

    func testXPAwarded() {
        let user = User(displayName: "Test", avatarEmoji: "🎤", hasCompletedSetup: true)
        context.insert(user)

        GamificationService.awardXP(to: user, wasDailyChallenge: false)
        XCTAssertEqual(user.xp, 120)
    }

    func testDailyChallengeXP() {
        let user = User(displayName: "Test", avatarEmoji: "🎤", hasCompletedSetup: true)
        context.insert(user)

        GamificationService.awardXP(to: user, wasDailyChallenge: true)
        XCTAssertEqual(user.xp, 320) // 120 + 200
    }

    func testStreakIncrementsOnNewDay() {
        let user = User(displayName: "Test", avatarEmoji: "🎤", hasCompletedSetup: true)
        user.lastSessionDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        user.currentStreak = 3
        context.insert(user)

        GamificationService.updateStreak(for: user)
        XCTAssertEqual(user.currentStreak, 4)
    }

    func testStreakResetsAfterMissedDay() {
        let user = User(displayName: "Test", avatarEmoji: "🎤", hasCompletedSetup: true)
        user.lastSessionDate = Calendar.current.date(byAdding: .day, value: -3, to: .now)
        user.currentStreak = 5
        context.insert(user)

        GamificationService.updateStreak(for: user)
        XCTAssertEqual(user.currentStreak, 1)
    }

    func testStreakStaysSameOnSameDay() {
        let user = User(displayName: "Test", avatarEmoji: "🎤", hasCompletedSetup: true)
        user.lastSessionDate = .now
        user.currentStreak = 3
        context.insert(user)

        GamificationService.updateStreak(for: user)
        XCTAssertEqual(user.currentStreak, 3)
    }

    func testDailySessionCountResets() {
        let user = User(displayName: "Test", avatarEmoji: "🎤", hasCompletedSetup: true)
        user.dailySessionCount = 15
        user.lastDailySessionDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        context.insert(user)

        GamificationService.incrementDailySessionCount(for: user)
        XCTAssertEqual(user.dailySessionCount, 1) // Reset + 1
    }

    func testLongestStreakUpdated() {
        let user = User(displayName: "Test", avatarEmoji: "🎤", hasCompletedSetup: true)
        user.lastSessionDate = Calendar.current.date(byAdding: .day, value: -1, to: .now)
        user.currentStreak = 10
        user.longestStreak = 8
        context.insert(user)

        GamificationService.updateStreak(for: user)
        XCTAssertEqual(user.longestStreak, 11)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

- [ ] **Step 3: Implement GamificationService**

```swift
// $SRC/Core/Services/GamificationService.swift
import Foundation

enum GamificationService {

    static func awardXP(to user: User, wasDailyChallenge: Bool) {
        user.xp += AppConstants.baseXP
        if wasDailyChallenge {
            user.xp += AppConstants.dailyChallengeXP
        }
    }

    static func updateStreak(for user: User) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        guard let lastDate = user.lastSessionDate else {
            // First ever session
            user.currentStreak = 1
            user.longestStreak = max(user.longestStreak, 1)
            return
        }

        let lastDay = calendar.startOfDay(for: lastDate)

        if lastDay == today {
            // Already completed a session today — no change
            return
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        if lastDay == calendar.startOfDay(for: yesterday) {
            // Consecutive day
            user.currentStreak += 1
        } else {
            // Missed one or more days
            user.currentStreak = 1
        }

        user.longestStreak = max(user.longestStreak, user.currentStreak)
    }

    static func incrementDailySessionCount(for user: User) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let lastDate = user.lastDailySessionDate,
           calendar.startOfDay(for: lastDate) == today {
            user.dailySessionCount += 1
        } else {
            // New day — reset counter
            user.dailySessionCount = 1
            user.lastDailySessionDate = .now
        }
    }

    static func headlineVerdict(for score: Int) -> String {
        switch score {
        case 80...100: "Strong performance."
        case 60..<80: "Getting there."
        default: "Room to grow."
        }
    }

    /// Returns the XP earned for a session (before adding to user)
    static func xpForSession(wasDailyChallenge: Bool) -> Int {
        AppConstants.baseXP + (wasDailyChallenge ? AppConstants.dailyChallengeXP : 0)
    }
}
```

- [ ] **Step 4: Run tests and verify they pass**

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Core/Services/GamificationService.swift" "$TEST/Core/Services/GamificationServiceTests.swift"
git commit -m "feat: add GamificationService — XP, streaks, daily limits, verdicts"
```

---

## Phase 4: AI Integration

### Task 16: Claude Client & Feedback Generator

**Files:**
- Create: `$SRC/Core/AI/ClaudeClient.swift`
- Create: `$SRC/Core/AI/FeedbackGenerator.swift`

- [ ] **Step 1: Implement ClaudeClient**

```swift
// $SRC/Core/AI/ClaudeClient.swift
import Foundation

final class ClaudeClient {
    private let baseURL: URL

    init() {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlanceAPIBaseURL") as? String,
              let url = URL(string: urlString) else {
            fatalError("ParlanceAPIBaseURL not set in Info.plist")
        }
        self.baseURL = url
    }

    /// For testing
    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    struct FeedbackResponse: Decodable {
        let feedback: String
    }

    func fetchFeedback(prompt: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("feedback")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConstants.feedbackTimeout

        let body: [String: Any] = [
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        return decoded.feedback
    }
}
```

- [ ] **Step 2: Implement FeedbackGenerator**

```swift
// $SRC/Core/AI/FeedbackGenerator.swift
import Foundation

enum FeedbackGenerator {

    static func buildPrompt(
        mode: SessionMode,
        level: Int,
        question: String,
        duration: TimeInterval,
        overallScore: Int,
        fillerCount: Int,
        paceScore: Int,
        clarityScore: Int,
        structureScore: Int,
        vocabularyScore: Int,
        transcript: String
    ) -> String {
        let levelName = DifficultyLevel.name(for: level)
        let excerptWords = transcript.split(separator: " ").prefix(AppConstants.transcriptExcerptLength)
        let excerpt = excerptWords.joined(separator: " ")

        return """
        You are a direct, no-nonsense speech coach. A user just completed a \(mode.displayName) speaking session at level \(level) (\(levelName)).

        They were asked: "\(question)"
        Their recording lasted \(Int(duration)) seconds.
        Overall score: \(overallScore)/100

        Metrics:
        - Filler words: \(fillerCount) instances
        - Pace: \(paceScore)/10
        - Clarity: \(clarityScore)/10
        - Structure: \(structureScore)/10
        - Vocabulary Strength: \(vocabularyScore)/10

        Transcript excerpt: "\(excerpt)"

        Return ONLY valid JSON in this exact format:
        {
          "feedback": "One paragraph of specific, actionable coaching feedback."
        }

        Your feedback must:
        - Reference the actual question they were answering
        - Acknowledge one specific strength from their performance
        - Identify the most important area to improve
        - Be direct and coaching-oriented — no cheerful filler phrases like "Great job!" or "Keep it up!"
        - Be calibrated to level \(level): gentler for levels 1-4, rigorous for levels 7-10
        - Be mode-aware: \(mode.displayName) context affects what "good" looks like
        """
    }

    static func fetchFeedback(
        client: ClaudeClient,
        mode: SessionMode,
        level: Int,
        question: String,
        duration: TimeInterval,
        overallScore: Int,
        fillerCount: Int,
        paceScore: Int,
        clarityScore: Int,
        structureScore: Int,
        vocabularyScore: Int,
        transcript: String
    ) async -> String? {
        let prompt = buildPrompt(
            mode: mode, level: level, question: question,
            duration: duration, overallScore: overallScore,
            fillerCount: fillerCount, paceScore: paceScore,
            clarityScore: clarityScore, structureScore: structureScore,
            vocabularyScore: vocabularyScore, transcript: transcript
        )

        do {
            return try await client.fetchFeedback(prompt: prompt)
        } catch {
            return nil
        }
    }
}
```

- [ ] **Step 3: Add `ParlanceAPIBaseURL` to Info.plist**

Add to `Info.plist`:
```xml
<key>ParlanceAPIBaseURL</key>
<string>https://parlance-api.yourdomain.workers.dev</string>
```

- [ ] **Step 4: Build to verify compilation**

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Core/AI/ClaudeClient.swift" "$SRC/Core/AI/FeedbackGenerator.swift" \
  "Parlance: AI Speech Coach/Info.plist"
git commit -m "feat: add ClaudeClient and FeedbackGenerator for AI coach feedback"
```

---

## Phase 5: Reusable UI Components

### Task 17: Animated Waveform View

**Files:**
- Create: `$SRC/UI/Components/AnimatedWaveformView.swift`

- [ ] **Step 1: Implement AnimatedWaveformView**

```swift
// $SRC/UI/Components/AnimatedWaveformView.swift
import SwiftUI

struct AnimatedWaveformView: View {
    let levels: [Float]
    let isActive: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? accentColor : AppColors.sub.opacity(0.3))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
        .frame(height: 60)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = CGFloat(levels[index])
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 60
        return isActive ? max(minHeight, level * maxHeight) : minHeight
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "$SRC/UI/Components/AnimatedWaveformView.swift"
git commit -m "feat: add AnimatedWaveformView with 38-bar audio visualization"
```

---

### Task 18: XP Progress Bar

**Files:**
- Create: `$SRC/UI/Components/XPProgressBar.swift`

- [ ] **Step 1: Implement XPProgressBar**

```swift
// $SRC/UI/Components/XPProgressBar.swift
import SwiftUI

struct XPProgressBar: View {
    let currentXP: Int
    let rank: Rank

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if rank.isMaxRank {
                // Max rank — static gold bar
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.gold)
                        .frame(width: geo.size.width, height: 10)
                }
                .frame(height: 10)

                Text("Rank 10 · Master · MAX")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.gold)
            } else {
                let nextXP = rank.xpForNextRank ?? currentXP
                let progress = Double(currentXP - rank.xpRequired) / Double(nextXP - rank.xpRequired)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.border)
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.gold)
                            .frame(width: max(0, geo.size.width * progress), height: 10)
                            .animation(.easeOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 10)

                Text("Rank \(rank.level) — \(rank.name) · \(currentXP) / \(nextXP) XP")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.sub)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "$SRC/UI/Components/XPProgressBar.swift"
git commit -m "feat: add XPProgressBar with rank display and max rank state"
```

---

### Task 19: Score Ring View

**Files:**
- Create: `$SRC/Features/Results/ScoreRingView.swift`

- [ ] **Step 1: Implement ScoreRingView**

```swift
// $SRC/Features/Results/ScoreRingView.swift
import SwiftUI

struct ScoreRingView: View {
    let score: Int
    @State private var animatedProgress: Double = 0

    private var ringColor: Color {
        if score >= 80 { return AppColors.teal }
        if score >= 60 { return AppColors.gold }
        return AppColors.red
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(AppColors.border, lineWidth: 12)

            // Animated progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Score text
            Text("\(score)")
                .font(AppFonts.display(48))
                .foregroundStyle(ringColor)
        }
        .frame(width: 160, height: 160)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animatedProgress = Double(score) / 100.0
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "$SRC/Features/Results/ScoreRingView.swift"
git commit -m "feat: add animated ScoreRingView with color thresholds"
```

---

### Task 20: Pill Badge & Metric Card

**Files:**
- Create: `$SRC/UI/Components/PillBadge.swift`
- Create: `$SRC/Features/Results/MetricCardView.swift`
- Create: `$SRC/Features/Results/XPToastView.swift`

- [ ] **Step 1: Implement PillBadge**

```swift
// $SRC/UI/Components/PillBadge.swift
import SwiftUI

struct PillBadge: View {
    let text: String
    var color: Color = AppColors.gold

    var body: some View {
        Text(text)
            .font(AppFonts.bodyMedium(12))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Implement MetricCardView**

```swift
// $SRC/Features/Results/MetricCardView.swift
import SwiftUI

struct MetricCardView: View {
    let name: String
    let score: Int // 0-10 or -1 if unavailable
    let tip: String

    private var scoreColor: Color {
        if score < 0 { return AppColors.sub }
        if score >= 8 { return AppColors.teal }
        if score >= 5 { return AppColors.gold }
        return AppColors.red
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.text)

                Text(tip)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                    .lineLimit(2)
            }

            Spacer()

            if score >= 0 {
                Text("\(score)/10")
                    .font(AppFonts.display(20))
                    .foregroundStyle(scoreColor)
            } else {
                Text("—")
                    .font(AppFonts.display(20))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .cardStyle()
    }
}
```

- [ ] **Step 3: Implement XPToastView**

```swift
// $SRC/Features/Results/XPToastView.swift
import SwiftUI

struct XPToastView: View {
    let xpEarned: Int
    @State private var isVisible = false
    @State private var offset: CGFloat = 100

    var body: some View {
        if isVisible {
            Text("+\(xpEarned) XP")
                .font(AppFonts.bodyBold(18))
                .foregroundStyle(AppColors.gold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.gold.opacity(0.3), lineWidth: 1))
                .offset(y: offset)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        offset = 0
                    }
                    // Auto-dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isVisible = false
                        }
                    }
                }
        }
    }

    func show() -> XPToastView {
        var view = self
        view._isVisible = State(initialValue: true)
        return view
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add "$SRC/UI/Components/PillBadge.swift" "$SRC/Features/Results/MetricCardView.swift" \
  "$SRC/Features/Results/XPToastView.swift"
git commit -m "feat: add PillBadge, MetricCardView, and XPToastView"
```

---

## Phase 6: App Shell & Navigation

### Task 21: App Entry Point & Root Navigation

**Files:**
- Modify: `$SRC/Parlance__AI_Speech_CoachApp.swift`
- Modify: `$SRC/ContentView.swift`

- [ ] **Step 1: Update app entry point with SwiftData container**

```swift
// $SRC/Parlance__AI_Speech_CoachApp.swift
import SwiftUI
import SwiftData

@main
struct Parlance__AI_Speech_CoachApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceService.shared.container)
    }
}
```

- [ ] **Step 2: Implement root ContentView with tab bar and session overlay**

```swift
// $SRC/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @StateObject private var permissionsService = PermissionsService()
    @State private var activeSession: ActiveSessionState?

    private var currentUser: User? { users.first }
    private var hasCompletedSetup: Bool { currentUser?.hasCompletedSetup ?? false }

    var body: some View {
        ZStack {
            if !hasCompletedSetup {
                FirstLaunchSetupView()
            } else if let session = activeSession {
                SessionCoordinator(
                    state: session,
                    onDismiss: { activeSession = nil }
                )
                .transition(.move(edge: .bottom))
            } else {
                mainTabView
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.font, AppFonts.body(16))
        .environmentObject(permissionsService)
        .onAppear {
            PersistenceService.shared.seedAchievementsIfNeeded()
        }
    }

    private var mainTabView: some View {
        TabView {
            HomeView(onStartSession: { state in
                withAnimation(.easeInOut(duration: 0.3)) {
                    activeSession = state
                }
            })
            .tabItem {
                Label("Home", systemImage: "house")
            }

            ProgressTabView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar")
                }

            LeagueView()
                .tabItem {
                    Label("League", systemImage: "trophy")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .tint(AppColors.gold)
    }
}

/// Represents the configuration for starting a new session
struct ActiveSessionState {
    let mode: SessionMode
    let difficultyLevel: Int
    let question: Question
    let wasDailyChallenge: Bool
}
```

- [ ] **Step 3: Build to verify compilation**

Note: This will have compile errors until Feature views are created. Those are created in the next tasks. For now, create placeholder stubs.

- [ ] **Step 4: Create placeholder feature views so the app compiles**

Create minimal stub files (these will be fully implemented in subsequent tasks):

```swift
// $SRC/Features/Setup/FirstLaunchSetupView.swift
import SwiftUI
struct FirstLaunchSetupView: View {
    var body: some View { Text("Setup").frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.bg) }
}
```

```swift
// $SRC/Features/Home/HomeView.swift
import SwiftUI
struct HomeView: View {
    let onStartSession: (ActiveSessionState) -> Void
    var body: some View { Text("Home").frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.bg) }
}
```

```swift
// $SRC/Features/Session/SessionCoordinator.swift
import SwiftUI
struct SessionCoordinator: View {
    let state: ActiveSessionState
    let onDismiss: () -> Void
    var body: some View { Text("Session").frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.bg) }
}
```

```swift
// $SRC/Features/Progress/ProgressTabView.swift
import SwiftUI
struct ProgressTabView: View {
    var body: some View { Text("Progress").frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.bg) }
}
```

```swift
// $SRC/Features/League/LeagueView.swift
import SwiftUI
struct LeagueView: View {
    var body: some View { Text("League").frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.bg) }
}
```

```swift
// $SRC/Features/Profile/ProfileView.swift
import SwiftUI
struct ProfileView: View {
    var body: some View { Text("Profile").frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColors.bg) }
}
```

- [ ] **Step 5: Build and run — app should launch with 4 tabs + setup screen**

- [ ] **Step 6: Commit**

```bash
git add "$SRC/Parlance__AI_Speech_CoachApp.swift" "$SRC/ContentView.swift" \
  "$SRC/Features/Setup/FirstLaunchSetupView.swift" \
  "$SRC/Features/Home/HomeView.swift" \
  "$SRC/Features/Session/SessionCoordinator.swift" \
  "$SRC/Features/Progress/ProgressTabView.swift" \
  "$SRC/Features/League/LeagueView.swift" \
  "$SRC/Features/Profile/ProfileView.swift"
git commit -m "feat: add app shell with tab navigation and session overlay routing"
```

---

## Phase 7: First Launch Setup

### Task 22: First Launch Setup View

**Files:**
- Modify: `$SRC/Features/Setup/FirstLaunchSetupView.swift`

- [ ] **Step 1: Implement full FirstLaunchSetupView**

```swift
// $SRC/Features/Setup/FirstLaunchSetupView.swift
import SwiftUI
import SafariServices

struct FirstLaunchSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var selectedAvatar = "🎤"
    @State private var showPrivacyPolicy = false

    private let avatars = ["🎤", "🧠", "🚀", "💼", "🦁", "🔥", "⚡", "🎯", "🏆", "💡", "🌟", "🎭"]

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo area
            VStack(spacing: 12) {
                Text("Parlance")
                    .font(AppFonts.display(36))
                    .foregroundStyle(AppColors.text)

                Text("Your personal speech coach.")
                    .font(AppFonts.body(16))
                    .foregroundStyle(AppColors.sub)
            }

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?")
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.sub)

                TextField("Your name", text: $name)
                    .font(AppFonts.body(18))
                    .foregroundStyle(AppColors.text)
                    .padding(14)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .onChange(of: name) { _, newValue in
                        if newValue.count > AppConstants.maxNameLength {
                            name = String(newValue.prefix(AppConstants.maxNameLength))
                        }
                    }
            }
            .padding(.horizontal, 24)

            // Avatar picker
            VStack(spacing: 12) {
                Text("Pick your avatar")
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.sub)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(avatars, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 36))
                                .frame(width: 56, height: 56)
                                .background(selectedAvatar == emoji ? AppColors.gold.opacity(0.2) : AppColors.card)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(
                                        selectedAvatar == emoji ? AppColors.gold : AppColors.border,
                                        lineWidth: selectedAvatar == emoji ? 2 : 1
                                    )
                                )
                                .onTapGesture { selectedAvatar = emoji }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            // CTA
            Button {
                createUser()
            } label: {
                Text("Let's go")
                    .font(AppFonts.bodyBold(18))
                    .foregroundStyle(isValid ? AppColors.bg : AppColors.sub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isValid ? AppColors.gold : AppColors.border)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isValid)
            .padding(.horizontal, 24)

            Spacer()

            // Privacy footer
            Button {
                showPrivacyPolicy = true
            } label: {
                Text("Your voice data stays private. Privacy Policy")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
                    .underline()
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .sheet(isPresented: $showPrivacyPolicy) {
            SafariView(url: privacyPolicyURL)
        }
    }

    private var privacyPolicyURL: URL {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlancePrivacyPolicyURL") as? String ?? "https://example.com/privacy"
        return URL(string: urlString) ?? URL(string: "https://example.com/privacy")!
    }

    private func createUser() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let _ = PersistenceService.shared.createUser(name: trimmedName, avatar: selectedAvatar)
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
```

- [ ] **Step 2: Add `ParlancePrivacyPolicyURL` to Info.plist**

```xml
<key>ParlancePrivacyPolicyURL</key>
<string>https://example.com/privacy</string>
```

- [ ] **Step 3: Build and run — first launch should show setup screen**

- [ ] **Step 4: Commit**

```bash
git add "$SRC/Features/Setup/FirstLaunchSetupView.swift" "Parlance: AI Speech Coach/Info.plist"
git commit -m "feat: implement first launch setup — name, avatar, privacy link"
```

---

## Phase 8: Home Tab

### Task 23: Home View Model

**Files:**
- Create: `$SRC/Features/Home/HomeViewModel.swift`

- [ ] **Step 1: Implement HomeViewModel**

```swift
// $SRC/Features/Home/HomeViewModel.swift
import SwiftUI
import SwiftData

@MainActor
final class HomeViewModel: ObservableObject {
    private let questionBank: QuestionBankService
    @Published var showRateLimitAlert = false

    init(questionBank: QuestionBankService = QuestionBankService()) {
        self.questionBank = questionBank
    }

    func startSession(
        mode: SessionMode,
        user: User,
        persistence: PersistenceService,
        wasDailyChallenge: Bool
    ) -> ActiveSessionState? {
        // Check daily rate limit
        guard !user.isAtDailyLimit else {
            showRateLimitAlert = true
            return nil
        }

        // Lock daily challenge difficulty on first Home load of the day
        let level = effectiveDifficultyLevel(for: user, wasDailyChallenge: wasDailyChallenge)
        let band = DifficultyLevel.band(for: level)
        let seenIds = persistence.seenQuestionIds(mode: mode, band: band)

        guard let question = questionBank.selectQuestion(mode: mode, band: band, excludingIds: seenIds) else {
            return nil
        }

        return ActiveSessionState(
            mode: mode,
            difficultyLevel: level,
            question: question,
            wasDailyChallenge: wasDailyChallenge
        )
    }

    func dailyChallengeMode() -> SessionMode {
        let weekday = Calendar.current.component(.weekday, from: .now)
        return SessionMode.dailyChallengeMode(weekday: weekday)
    }

    func lockDailyChallengeLevel(for user: User) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let lockDate = user.dailyChallengeLockDate,
           calendar.startOfDay(for: lockDate) == today {
            // Already locked today
            return
        }

        user.dailyChallengeLevelLock = user.practiceLevel
        user.dailyChallengeLockDate = .now
    }

    private func effectiveDifficultyLevel(for user: User, wasDailyChallenge: Bool) -> Int {
        if wasDailyChallenge, let locked = user.dailyChallengeLevelLock {
            return locked
        }
        return user.practiceLevel
    }

    func weeklyStats(sessions: [Session]) -> (count: Int, avgScore: Int, bestScore: Int, fillerTotal: Int) {
        guard !sessions.isEmpty else { return (0, 0, 0, 0) }
        let count = sessions.count
        let avgScore = sessions.map(\.overallScore).reduce(0, +) / count
        let bestScore = sessions.map(\.overallScore).max() ?? 0
        let fillerTotal = sessions.map(\.fillerCount).reduce(0, +)
        return (count, avgScore, bestScore, fillerTotal)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "$SRC/Features/Home/HomeViewModel.swift"
git commit -m "feat: add HomeViewModel with session start, daily challenge, weekly stats"
```

---

### Task 24: Home View, Daily Challenge Card, Mode Grid

**Files:**
- Modify: `$SRC/Features/Home/HomeView.swift`
- Create: `$SRC/Features/Home/DailyChallengeCard.swift`
- Create: `$SRC/Features/Home/ModeGridView.swift`

- [ ] **Step 1: Implement DailyChallengeCard**

```swift
// $SRC/Features/Home/DailyChallengeCard.swift
import SwiftUI

struct DailyChallengeCard: View {
    let mode: SessionMode
    let level: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Daily Challenge")
                        .font(AppFonts.bodyBold(18))
                        .foregroundStyle(.white)

                    Spacer()

                    PillBadge(text: "+\(AppConstants.dailyChallengeXP) XP", color: .white)
                }

                Text("\(mode.displayName) · Level \(level)")
                    .font(AppFonts.body(14))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppColors.gold, AppColors.gold.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        }
    }
}
```

- [ ] **Step 2: Implement ModeGridView**

```swift
// $SRC/Features/Home/ModeGridView.swift
import SwiftUI

struct ModeGridView: View {
    let onSelect: (SessionMode) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(SessionMode.allCases, id: \.self) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    VStack(spacing: 8) {
                        Text(mode.emoji)
                            .font(.system(size: 32))
                        Text(mode.displayName)
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                            .stroke(mode.accentColor.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 3: Implement full HomeView**

```swift
// $SRC/Features/Home/HomeView.swift
import SwiftUI
import SwiftData

struct HomeView: View {
    let onStartSession: (ActiveSessionState) -> Void

    @Query private var users: [User]
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @StateObject private var viewModel = HomeViewModel()

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerRow
                    xpBar
                    dailyChallengeCard
                    difficultySlider
                    modeGrid
                    weeklyStatsRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .onAppear {
                if let user {
                    viewModel.lockDailyChallengeLevel(for: user)
                }
            }
            .alert("Daily Limit Reached", isPresented: $viewModel.showRateLimitAlert) {
                Button("OK") {}
            } message: {
                Text("You've hit your daily limit — come back tomorrow to keep your streak going.")
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            if let user {
                Text("\(user.greeting), \(user.displayName)")
                    .font(AppFonts.bodyBold(20))
                    .foregroundStyle(AppColors.text)
            }

            Spacer()

            if let user {
                HStack(spacing: 6) {
                    Text("🔥")
                    Text("\(user.currentStreak)")
                        .font(AppFonts.bodyBold(16))
                        .foregroundStyle(AppColors.gold)

                    Text(user.avatarEmoji)
                        .font(.system(size: 24))
                }
            }
        }
    }

    // MARK: - XP Bar

    private var xpBar: some View {
        Group {
            if let user {
                XPProgressBar(currentXP: user.xp, rank: user.rank)
            }
        }
    }

    // MARK: - Daily Challenge

    private var dailyChallengeCard: some View {
        Group {
            if let user {
                let mode = viewModel.dailyChallengeMode()
                let level = user.dailyChallengeLevelLock ?? user.practiceLevel
                DailyChallengeCard(mode: mode, level: level) {
                    if let state = viewModel.startSession(
                        mode: mode,
                        user: user,
                        persistence: .shared,
                        wasDailyChallenge: true
                    ) {
                        onStartSession(state)
                    }
                }
            }
        }
    }

    // MARK: - Difficulty Slider

    @State private var sliderLevel: Double = 1

    private var difficultySlider: some View {
        VStack(spacing: 8) {
            if let user {
                Slider(value: $sliderLevel, in: 1...10, step: 1)
                    .tint(AppColors.gold)
                    .onAppear { sliderLevel = Double(user.practiceLevel) }
                    .onChange(of: sliderLevel) { _, newValue in
                        user.practiceLevel = Int(newValue)
                    }

                Text("Level \(Int(sliderLevel)) — \(DifficultyLevel.name(for: Int(sliderLevel)))")
                    .font(AppFonts.bodyMedium(13))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Mode Grid

    private var modeGrid: some View {
        ModeGridView { mode in
            guard let user else { return }
            if let state = viewModel.startSession(
                mode: mode,
                user: user,
                persistence: .shared,
                wasDailyChallenge: false
            ) {
                onStartSession(state)
            }
        }
    }

    // MARK: - Weekly Stats

    private var weeklyStatsRow: some View {
        let weekSessions = PersistenceService.shared.sessionsThisWeek()
        let stats = viewModel.weeklyStats(sessions: weekSessions)

        return HStack(spacing: 0) {
            statItem(value: "\(stats.count)", label: "Sessions")
            statItem(value: "\(stats.avgScore)", label: "Avg Score")
            statItem(value: "\(stats.bestScore)", label: "Best Score")
            statItem(value: "\(stats.fillerTotal)", label: "Fillers")
        }
        .cardStyle()
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.display(20))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.sub)
        }
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 4: Build and run — Home tab should render with all sections**

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Features/Home/HomeView.swift" "$SRC/Features/Home/DailyChallengeCard.swift" \
  "$SRC/Features/Home/ModeGridView.swift"
git commit -m "feat: implement Home tab — greeting, XP bar, daily challenge, modes, stats"
```

---

## Phase 9: Session Flow

### Task 25: Session Coordinator (State Machine)

**Files:**
- Modify: `$SRC/Features/Session/SessionCoordinator.swift`

- [ ] **Step 1: Implement full SessionCoordinator**

```swift
// $SRC/Features/Session/SessionCoordinator.swift
import SwiftUI

struct SessionCoordinator: View {
    let state: ActiveSessionState
    let onDismiss: () -> Void

    @State private var phase: SessionPhase = .loading
    @StateObject private var recorder = AudioRecorder()
    @EnvironmentObject private var permissionsService: PermissionsService

    enum SessionPhase {
        case loading
        case recording
        case processing
        case results(Session)
    }

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            switch phase {
            case .loading:
                LoadingView(
                    mode: state.mode,
                    levelName: DifficultyLevel.name(for: state.difficultyLevel),
                    tier: DifficultyLevel.tier(for: state.difficultyLevel)
                ) {
                    phase = .recording
                }

            case .recording:
                RecordingView(
                    question: state.question,
                    mode: state.mode,
                    level: state.difficultyLevel,
                    recorder: recorder,
                    permissionsService: permissionsService
                ) {
                    phase = .processing
                    Task { await processSession() }
                }

            case .processing:
                processingView

            case .results(let session):
                ResultsView(
                    session: session,
                    question: state.question,
                    onTryAgain: { onDismiss() },
                    onGoHome: { onDismiss() }
                )
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppColors.gold)
                .scaleEffect(1.5)
            Text("Analyzing your performance…")
                .font(AppFonts.body(16))
                .foregroundStyle(AppColors.sub)
        }
    }

    private func processSession() async {
        guard let audioURL = recorder.stopRecording() else {
            onDismiss()
            return
        }

        let duration = recorder.elapsedTime

        // Transcribe
        var transcript = ""
        do {
            transcript = try await SpeechTranscriber.transcribe(url: audioURL)
        } catch {
            // Transcription failed — continue with empty transcript
        }

        // Delete audio file immediately
        recorder.deleteRecording()

        // Analyze metrics
        let metrics: SpeechAnalyzer.Metrics
        if transcript.isEmpty {
            metrics = SpeechAnalyzer.Metrics(
                fillerScore: -1, fillerCount: -1,
                paceScore: -1, wpm: 0,
                clarityScore: -1, structureScore: -1, vocabularyScore: -1
            )
        } else {
            metrics = SpeechAnalyzer.analyze(transcript: transcript, duration: duration, mode: state.mode)
        }

        let overallScore = transcript.isEmpty ? 0 : metrics.overallScore

        // Best/worst moments
        let moments = transcript.isEmpty
            ? SpeechAnalyzer.Moments(bestTimestamp: 0, bestText: "", worstTimestamp: 0, worstText: "")
            : SpeechAnalyzer.detectMoments(in: transcript, duration: duration)

        // Calculate XP
        let xpEarned = GamificationService.xpForSession(wasDailyChallenge: state.wasDailyChallenge)

        // Create session record
        let session = Session(
            mode: state.mode,
            difficultyLevel: state.difficultyLevel,
            duration: duration,
            transcript: transcript,
            overallScore: overallScore,
            fillerCount: metrics.fillerCount,
            paceScore: metrics.paceScore,
            clarityScore: metrics.clarityScore,
            structureScore: metrics.structureScore,
            vocabularyScore: metrics.vocabularyScore,
            question: state.question.question,
            bestMomentTimestamp: moments.bestTimestamp,
            bestMomentText: moments.bestText,
            worstMomentTimestamp: moments.worstTimestamp,
            worstMomentText: moments.worstText,
            xpEarned: xpEarned,
            wasDailyChallenge: state.wasDailyChallenge
        )

        // Persist
        await MainActor.run {
            let persistence = PersistenceService.shared
            persistence.saveSesssion(session)

            // Mark question seen
            persistence.markQuestionSeen(
                questionId: state.question.id,
                mode: state.mode,
                band: state.question.difficultyBand
            )

            // Update user gamification
            if let user = persistence.getUser() {
                GamificationService.awardXP(to: user, wasDailyChallenge: state.wasDailyChallenge)
                GamificationService.updateStreak(for: user)
                GamificationService.incrementDailySessionCount(for: user)
                user.lastSessionDate = .now

                // Check achievements
                checkAchievements(user: user, session: session, persistence: persistence)
            }
        }

        // Fire AI feedback async (non-blocking)
        if !transcript.isEmpty {
            Task {
                let feedback = await FeedbackGenerator.fetchFeedback(
                    client: ClaudeClient(),
                    mode: state.mode,
                    level: state.difficultyLevel,
                    question: state.question.question,
                    duration: duration,
                    overallScore: overallScore,
                    fillerCount: metrics.fillerCount,
                    paceScore: metrics.paceScore,
                    clarityScore: metrics.clarityScore,
                    structureScore: metrics.structureScore,
                    vocabularyScore: metrics.vocabularyScore,
                    transcript: transcript
                )
                await MainActor.run {
                    session.aiCoachFeedback = feedback
                    try? PersistenceService.shared.context.save()
                }
            }
        }

        await MainActor.run {
            phase = .results(session)
        }
    }

    private func checkAchievements(user: User, session: Session, persistence: PersistenceService) {
        let totalSessions = persistence.totalSessionCount()

        // First Session
        if totalSessions >= 1 { persistence.unlockAchievement(id: "first_session") }

        // 30 Sessions
        persistence.updateAchievementProgress(id: "sessions_30", progress: totalSessions)

        // 7-Day Streak
        if user.currentStreak >= 7 { persistence.unlockAchievement(id: "streak_7") }

        // Score 80+
        if session.overallScore >= 80 { persistence.unlockAchievement(id: "score_80") }

        // Zero Fillers
        if session.fillerCount == 0 && session.hasTranscript { persistence.unlockAchievement(id: "zero_fillers") }

        // Interview Pro
        let interviewCount = persistence.interviewSessionCount()
        persistence.updateAchievementProgress(id: "interview_pro", progress: interviewCount)

        // Rank 5
        if user.rank.level >= 5 { persistence.unlockAchievement(id: "rank_5") }

        // Master (Rank 10)
        if user.rank.level >= 10 { persistence.unlockAchievement(id: "master") }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "$SRC/Features/Session/SessionCoordinator.swift"
git commit -m "feat: implement SessionCoordinator state machine with full pipeline"
```

---

### Task 26: Loading View

**Files:**
- Create: `$SRC/Features/Session/LoadingView.swift`

- [ ] **Step 1: Implement LoadingView**

```swift
// $SRC/Features/Session/LoadingView.swift
import SwiftUI

struct LoadingView: View {
    let mode: SessionMode
    let levelName: String
    let tier: String
    let onReady: () -> Void

    @State private var statusIndex = 0
    @State private var pulseScale: CGFloat = 0.8

    private let statuses = [
        "Calibrating to your level…",
        "Selecting your challenge…",
        "Loading tips…",
        "Almost ready…"
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Pulsing orbs
            ZStack {
                Circle()
                    .fill(mode.accentColor.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulseScale)

                Circle()
                    .fill(mode.accentColor.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulseScale * 1.1)

                Circle()
                    .fill(mode.accentColor.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale * 1.2)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            }

            Text(statuses[statusIndex])
                .font(AppFonts.body(16))
                .foregroundStyle(AppColors.sub)
                .animation(.easeInOut, value: statusIndex)

            VStack(spacing: 4) {
                Text(levelName)
                    .font(AppFonts.bodyMedium(14))
                    .foregroundStyle(AppColors.text)
                Text(tier)
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .onAppear {
            // Cycle status text every 1.5s
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
                statusIndex = (statusIndex + 1) % statuses.count
            }

            // Transition after minimum loading duration
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.loadingMinDuration) {
                onReady()
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add "$SRC/Features/Session/LoadingView.swift"
git commit -m "feat: add LoadingView with pulsing orbs and status cycling"
```

---

### Task 27: Recording View & View Model

**Files:**
- Create: `$SRC/Features/Session/RecordingView.swift`
- Create: `$SRC/Features/Session/RecordingViewModel.swift`

- [ ] **Step 1: Implement RecordingViewModel**

```swift
// $SRC/Features/Session/RecordingViewModel.swift
import SwiftUI

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var showMicPrePrompt = false
    @Published var showSpeechPrePrompt = false
    @Published var showPermissionDenied = false
    @Published var permissionDeniedMessage = ""

    func handleRecordTap(
        recorder: AudioRecorder,
        permissions: PermissionsService
    ) async {
        if recorder.isRecording {
            guard recorder.canStop else { return }
            return // Will be handled by onStop callback
        }

        // Check microphone permission
        if !permissions.microphoneGranted {
            if permissions.microphoneStatus == .undetermined {
                showMicPrePrompt = true
                return
            } else {
                permissionDeniedMessage = "Microphone access is required to record. Go to Settings → Privacy → Microphone to enable it."
                showPermissionDenied = true
                return
            }
        }

        // Check speech recognition permission
        if !permissions.speechGranted {
            if permissions.speechStatus == .notDetermined {
                showSpeechPrePrompt = true
                return
            }
            // If denied, we still allow recording — just no transcript
        }

        do {
            try recorder.startRecording()
        } catch {
            // Handle recording error
        }
    }

    func requestMicPermission(permissions: PermissionsService) async -> Bool {
        let granted = await permissions.requestMicrophone()
        if granted {
            // Immediately request speech recognition
            showSpeechPrePrompt = true
        }
        return granted
    }

    func requestSpeechPermission(permissions: PermissionsService) async {
        _ = await permissions.requestSpeechRecognition()
    }
}
```

- [ ] **Step 2: Implement RecordingView**

```swift
// $SRC/Features/Session/RecordingView.swift
import SwiftUI

struct RecordingView: View {
    let question: Question
    let mode: SessionMode
    let level: Int
    @ObservedObject var recorder: AudioRecorder
    let permissionsService: PermissionsService
    let onStop: () -> Void

    @StateObject private var viewModel = RecordingViewModel()
    @State private var showNudge = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Prompt card
                    VStack(spacing: 12) {
                        Text(question.question)
                            .font(AppFonts.display(22))
                            .foregroundStyle(AppColors.text)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 8) {
                            PillBadge(text: "~\(question.targetDuration)s", color: mode.accentColor)
                            PillBadge(text: DifficultyLevel.name(for: level), color: AppColors.sub)
                        }
                    }
                    .padding(20)

                    // Coaching tips
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(question.tips.enumerated()), id: \.offset) { index, tip in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(AppFonts.bodyMedium(14))
                                    .foregroundStyle(mode.accentColor)
                                Text(tip)
                                    .font(AppFonts.body(14))
                                    .foregroundStyle(AppColors.sub)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Nudge
                    if showNudge {
                        Text("Stay deliberate — don't rush to fill silence")
                            .font(AppFonts.body(13))
                            .foregroundStyle(AppColors.gold.opacity(0.8))
                            .transition(.opacity)
                    }

                    // Wrap-up warning
                    if recorder.shouldShowWrapUp {
                        Text("Wrapping up in \(Int(AppConstants.maxRecordingDuration - recorder.elapsedTime))s…")
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.red)
                    }
                }
            }

            Spacer()

            // Waveform
            AnimatedWaveformView(
                levels: recorder.audioLevels,
                isActive: recorder.isRecording,
                accentColor: mode.accentColor
            )
            .padding(.horizontal, 24)

            // Timer
            Text(formatTime(recorder.elapsedTime))
                .font(AppFonts.display(48))
                .foregroundStyle(recorder.isRecording ? AppColors.gold : AppColors.sub.opacity(0.5))
                .padding(.top, 12)

            // Mic button
            Button {
                if recorder.isRecording && recorder.canStop {
                    let _ = recorder.stopRecording()
                    onStop()
                } else if !recorder.isRecording {
                    Task {
                        await viewModel.handleRecordTap(recorder: recorder, permissions: permissionsService)
                        if permissionsService.microphoneGranted {
                            try? recorder.startRecording()
                        }
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? AppColors.red : AppColors.gold)
                        .frame(width: 72, height: 72)

                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColors.bg)
                    }
                }
            }
            .disabled(recorder.isRecording && !recorder.canStop)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
        .onChange(of: recorder.elapsedTime) { _, newValue in
            showNudge = recorder.shouldShowNudge
            if !recorder.isRecording && newValue > 0 {
                // Auto-stopped at max duration
                onStop()
            }
        }
        // Permission pre-prompts
        .alert("Microphone Access", isPresented: $viewModel.showMicPrePrompt) {
            Button("Continue") {
                Task { let _ = await viewModel.requestMicPermission(permissions: permissionsService) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Parlance needs your microphone to record your practice sessions. Your audio is processed on-device.")
        }
        .alert("Speech Recognition", isPresented: $viewModel.showSpeechPrePrompt) {
            Button("Enable") {
                Task { await viewModel.requestSpeechPermission(permissions: permissionsService) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To analyze your speech, Parlance uses on-device transcription. Your transcript is never stored beyond your session.")
        }
        .alert("Permission Required", isPresented: $viewModel.showPermissionDenied) {
            Button("Open Settings") { permissionsService.openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.permissionDeniedMessage)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

- [ ] **Step 3: Build to verify compilation**

- [ ] **Step 4: Commit**

```bash
git add "$SRC/Features/Session/RecordingView.swift" "$SRC/Features/Session/RecordingViewModel.swift"
git commit -m "feat: implement RecordingView with waveform, timer, permissions, and coaching tips"
```

---

## Phase 10: Results Screen

### Task 28: Results View & View Model

**Files:**
- Create: `$SRC/Features/Results/ResultsView.swift`
- Create: `$SRC/Features/Results/ResultsViewModel.swift`

- [ ] **Step 1: Implement ResultsViewModel**

```swift
// $SRC/Features/Results/ResultsViewModel.swift
import SwiftUI

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var isRetryingFeedback = false

    func retryFeedback(for session: Session, question: Question) async {
        isRetryingFeedback = true
        let feedback = await FeedbackGenerator.fetchFeedback(
            client: ClaudeClient(),
            mode: session.mode,
            level: session.difficultyLevel,
            question: question.question,
            duration: session.duration,
            overallScore: session.overallScore,
            fillerCount: session.fillerCount,
            paceScore: session.paceScore,
            clarityScore: session.clarityScore,
            structureScore: session.structureScore,
            vocabularyScore: session.vocabularyScore,
            transcript: session.transcript
        )
        session.aiCoachFeedback = feedback
        try? PersistenceService.shared.context.save()
        isRetryingFeedback = false
    }

    func fillerTip(for session: Session) -> String {
        let filler = SpeechAnalyzer.analyzeFillers(in: session.transcript)
        if let most = filler.mostFrequent {
            return "Try to reduce your use of '\(most)' — it appeared most often."
        }
        return session.fillerCount == 0 ? "No filler words detected — excellent!" : "Work on reducing filler words."
    }

    func paceTip(for session: Session) -> String {
        let wordCount = session.transcript.split(separator: " ").count
        return SpeechAnalyzer.analyzePace(wordCount: wordCount, duration: session.duration).tip
    }

    func clarityTip(for session: Session) -> String {
        SpeechAnalyzer.analyzeClarity(in: session.transcript).tip
    }

    func structureTip(for session: Session) -> String {
        SpeechAnalyzer.analyzeStructure(in: session.transcript, mode: session.mode).tip
    }

    func vocabularyTip(for session: Session) -> String {
        SpeechAnalyzer.analyzeVocabulary(in: session.transcript).tip
    }
}
```

- [ ] **Step 2: Implement ResultsView**

```swift
// $SRC/Features/Results/ResultsView.swift
import SwiftUI

struct ResultsView: View {
    @ObservedObject var session: Session
    let question: Question
    let onTryAgain: () -> Void
    let onGoHome: () -> Void

    @StateObject private var viewModel = ResultsViewModel()
    @State private var showXPToast = true

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    // Score Ring
                    ScoreRingView(score: session.overallScore)
                        .padding(.top, 24)

                    // Headline verdict
                    Text(GamificationService.headlineVerdict(for: session.overallScore))
                        .font(AppFonts.bodyBold(18))
                        .foregroundStyle(AppColors.text)

                    // Question recap
                    Text(""\(session.question)"")
                        .font(AppFonts.body(14))
                        .italic()
                        .foregroundStyle(AppColors.sub)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // AI Coach Feedback
                    aiCoachCard

                    // Best/Worst Moments
                    momentsSection

                    // Metric Breakdown
                    metricsSection

                    // Up Next
                    upNextSection
                        .padding(.bottom, 60)
                }
                .padding(.horizontal, 16)
            }
            .background(AppColors.bg)

            // XP Toast overlay
            if showXPToast {
                xpToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showXPToast = false }
                        }
                    }
            }
        }
    }

    // MARK: - AI Coach Card

    private var aiCoachCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Coach")
                    .font(AppFonts.bodyBold(16))
                    .foregroundStyle(AppColors.gold)
                Spacer()

                if session.aiCoachFeedback == nil {
                    Button {
                        Task { await viewModel.retryFeedback(for: session, question: question) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppColors.sub)
                    }
                    .disabled(viewModel.isRetryingFeedback)
                }
            }

            if let feedback = session.aiCoachFeedback {
                Text(feedback)
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.text)
            } else if viewModel.isRetryingFeedback {
                // Shimmer skeleton
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.border)
                    .frame(height: 60)
                    .shimmering()
            } else {
                Text("Coach feedback unavailable right now. Your scores and metrics are still saved.")
                    .font(AppFonts.body(14))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.cardRadius)
                .stroke(AppColors.gold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Moments

    private var momentsSection: some View {
        HStack(spacing: 12) {
            if !session.bestMomentText.isEmpty {
                momentCard(
                    title: "Best Moment",
                    timestamp: formatTimestamp(session.bestMomentTimestamp),
                    text: session.bestMomentText,
                    color: AppColors.teal
                )
            }

            if !session.worstMomentText.isEmpty {
                momentCard(
                    title: "Worst Moment",
                    timestamp: formatTimestamp(session.worstMomentTimestamp),
                    text: session.worstMomentText,
                    color: AppColors.red
                )
            }
        }
    }

    private func momentCard(title: String, timestamp: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(AppFonts.bodyMedium(12))
                    .foregroundStyle(color)
                Spacer()
                Text(timestamp)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.sub)
            }
            Text(text)
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.text)
                .lineLimit(3)
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Metrics

    private var metricsSection: some View {
        VStack(spacing: 10) {
            MetricCardView(name: "Filler Words", score: session.fillerCount >= 0 ? max(0, 10 - session.fillerCount) : -1, tip: viewModel.fillerTip(for: session))
            MetricCardView(name: "Pace", score: session.paceScore, tip: viewModel.paceTip(for: session))
            MetricCardView(name: "Clarity", score: session.clarityScore, tip: viewModel.clarityTip(for: session))
            MetricCardView(name: "Structure", score: session.structureScore, tip: viewModel.structureTip(for: session))
            MetricCardView(name: "Vocabulary", score: session.vocabularyScore, tip: viewModel.vocabularyTip(for: session))
        }
    }

    // MARK: - Up Next

    private var upNextSection: some View {
        VStack(spacing: 12) {
            Button(action: onTryAgain) {
                Text("Try Again")
                    .font(AppFonts.bodyBold(16))
                    .foregroundStyle(AppColors.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onGoHome) {
                Text("Home")
                    .font(AppFonts.bodyMedium(16))
                    .foregroundStyle(AppColors.sub)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
    }

    // MARK: - XP Toast

    private var xpToast: some View {
        Text("+\(session.xpEarned) XP")
            .font(AppFonts.bodyBold(18))
            .foregroundStyle(AppColors.gold)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppColors.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.gold.opacity(0.3), lineWidth: 1))
            .padding(.bottom, 24)
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Shimmer Modifier

extension View {
    func shimmering() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.1), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 300
                    }
                }
            )
            .clipped()
    }
}
```

- [ ] **Step 3: Build to verify compilation**

- [ ] **Step 4: Commit**

```bash
git add "$SRC/Features/Results/ResultsView.swift" "$SRC/Features/Results/ResultsViewModel.swift"
git commit -m "feat: implement ResultsView with score ring, AI feedback, metrics, moments"
```

---

## Phase 11: Progress Tab

### Task 29: Progress Tab View & View Model

**Files:**
- Modify: `$SRC/Features/Progress/ProgressTabView.swift`
- Create: `$SRC/Features/Progress/ProgressViewModel.swift`

- [ ] **Step 1: Implement ProgressViewModel**

```swift
// $SRC/Features/Progress/ProgressViewModel.swift
import SwiftUI
import SwiftData

@MainActor
final class ProgressViewModel: ObservableObject {

    func scoreHistory(from sessions: [Session]) -> [Int] {
        Array(sessions.suffix(16).map(\.overallScore))
    }

    func weeklyActivity(from sessions: [Session]) -> [Int] {
        let calendar = Calendar.current
        var counts = Array(repeating: 0, count: 7) // Mon-Sun

        for session in sessions {
            let weekday = calendar.component(.weekday, from: session.date)
            // Convert to Mon=0, Tue=1, ..., Sun=6
            let index = (weekday + 5) % 7
            counts[index] += 1
        }
        return counts
    }

    struct SkillTrend {
        let name: String
        let current: Double
        let previous: Double
        var delta: Double { current - previous }
    }

    func skillTrends(currentWeek: [Session], previousWeek: [Session]) -> [SkillTrend] {
        func avg(_ sessions: [Session], _ keyPath: KeyPath<Session, Int>) -> Double {
            guard !sessions.isEmpty else { return 0 }
            let valid = sessions.filter { $0[keyPath: keyPath] >= 0 }
            guard !valid.isEmpty else { return 0 }
            return Double(valid.map { $0[keyPath: keyPath] }.reduce(0, +)) / Double(valid.count)
        }

        return [
            SkillTrend(name: "Filler Words", current: avg(currentWeek, \.fillerCount), previous: avg(previousWeek, \.fillerCount)),
            SkillTrend(name: "Pace", current: avg(currentWeek, \.paceScore), previous: avg(previousWeek, \.paceScore)),
            SkillTrend(name: "Clarity", current: avg(currentWeek, \.clarityScore), previous: avg(previousWeek, \.clarityScore)),
            SkillTrend(name: "Structure", current: avg(currentWeek, \.structureScore), previous: avg(previousWeek, \.structureScore)),
            SkillTrend(name: "Vocabulary", current: avg(currentWeek, \.vocabularyScore), previous: avg(previousWeek, \.vocabularyScore))
        ]
    }

    struct ModeBreakdown {
        let mode: SessionMode
        let count: Int
        let bestScore: Int
    }

    func modeBreakdown(from sessions: [Session]) -> [ModeBreakdown] {
        SessionMode.allCases.map { mode in
            let modeSessions = sessions.filter { $0.mode == mode }
            return ModeBreakdown(
                mode: mode,
                count: modeSessions.count,
                bestScore: modeSessions.map(\.overallScore).max() ?? 0
            )
        }
    }
}
```

- [ ] **Step 2: Implement full ProgressTabView**

```swift
// $SRC/Features/Progress/ProgressTabView.swift
import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query private var achievements: [Achievement]
    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 20) {
                        scoreHistoryChart
                        weeklyActivityChart
                        skillTrendsSection
                        modeBreakdownSection
                        milestonesSection
                        recentSessionsList
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(AppColors.bg)
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.sub)
            Text("Complete your first session to see your progress")
                .font(AppFonts.body(16))
                .foregroundStyle(AppColors.sub)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Score History

    private var scoreHistoryChart: some View {
        let scores = viewModel.scoreHistory(from: sessions)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Score History")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            GeometryReader { geo in
                let width = geo.size.width
                let height: CGFloat = 120
                let stepX = scores.count > 1 ? width / CGFloat(scores.count - 1) : width
                Path { path in
                    for (i, score) in scores.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = height - (CGFloat(score) / 100.0 * height)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(AppColors.teal, lineWidth: 2)
            }
            .frame(height: 120)
        }
        .cardStyle()
    }

    // MARK: - Weekly Activity

    private var weeklyActivityChart: some View {
        let weekSessions = PersistenceService.shared.sessionsThisWeek()
        let counts = viewModel.weeklyActivity(from: weekSessions)
        let maxCount = max(1, counts.max() ?? 1)
        let days = ["M", "T", "W", "T", "F", "S", "S"]

        return VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(counts[i] > 0 ? AppColors.gold : AppColors.border)
                            .frame(width: 30, height: max(4, CGFloat(counts[i]) / CGFloat(maxCount) * 60))

                        Text(days[i])
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.sub)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .cardStyle()
    }

    // MARK: - Skill Trends

    private var skillTrendsSection: some View {
        let currentWeek = PersistenceService.shared.sessionsThisWeek()
        // For previous week, just use sessions not in this week from recent
        let previousWeek = sessions.filter { !currentWeek.contains(where: { c in c.id == $0.id }) }.prefix(20).map { $0 }
        let trends = viewModel.skillTrends(currentWeek: currentWeek, previousWeek: previousWeek)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Skill Trends")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            ForEach(trends, id: \.name) { trend in
                HStack {
                    Text(trend.name)
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text(String(format: "%.1f", trend.current))
                        .font(AppFonts.bodyMedium(14))
                        .foregroundStyle(AppColors.text)
                    Image(systemName: trend.delta >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10))
                        .foregroundStyle(trend.delta >= 0 ? AppColors.teal : AppColors.red)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Mode Breakdown

    private var modeBreakdownSection: some View {
        let breakdown = viewModel.modeBreakdown(from: Array(sessions))

        return VStack(alignment: .leading, spacing: 8) {
            Text("Mode Breakdown")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            ForEach(breakdown, id: \.mode) { item in
                HStack {
                    Text(item.mode.emoji)
                    Text(item.mode.displayName)
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text("\(item.count) sessions")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                    Text("Best: \(item.bestScore)")
                        .font(AppFonts.bodyMedium(12))
                        .foregroundStyle(AppColors.teal)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        let inProgress = achievements.filter { !$0.isUnlocked && $0.progress > 0 }

        return Group {
            if !inProgress.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Milestones")
                        .font(AppFonts.bodyBold(16))
                        .foregroundStyle(AppColors.text)

                    ForEach(inProgress, id: \.id) { achievement in
                        HStack {
                            Image(systemName: achievement.iconName)
                                .foregroundStyle(AppColors.sub)
                            Text(achievement.name)
                                .font(AppFonts.body(14))
                                .foregroundStyle(AppColors.text)
                            Spacer()
                            Text("\(achievement.progress)/\(achievement.goal)")
                                .font(AppFonts.bodyMedium(12))
                                .foregroundStyle(AppColors.gold)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            ForEach(sessions.prefix(10), id: \.id) { session in
                HStack {
                    Text(session.mode.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.mode.displayName)
                            .font(AppFonts.bodyMedium(14))
                            .foregroundStyle(AppColors.text)
                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                            .font(AppFonts.body(11))
                            .foregroundStyle(AppColors.sub)
                    }
                    Spacer()
                    Text("\(session.overallScore)")
                        .font(AppFonts.display(18))
                        .foregroundStyle(session.overallScore >= 80 ? AppColors.teal : session.overallScore >= 60 ? AppColors.gold : AppColors.red)
                }
                .padding(.vertical, 4)

                if session.id != sessions.prefix(10).last?.id {
                    Divider().background(AppColors.border)
                }
            }
        }
        .cardStyle()
    }
}
```

- [ ] **Step 3: Build to verify compilation**

- [ ] **Step 4: Commit**

```bash
git add "$SRC/Features/Progress/ProgressTabView.swift" "$SRC/Features/Progress/ProgressViewModel.swift"
git commit -m "feat: implement Progress tab — charts, trends, modes, milestones, recents"
```

---

## Phase 12: League Tab

### Task 30: League View & View Model

**Files:**
- Modify: `$SRC/Features/League/LeagueView.swift`
- Create: `$SRC/Features/League/LeagueViewModel.swift`

- [ ] **Step 1: Implement LeagueViewModel**

```swift
// $SRC/Features/League/LeagueViewModel.swift
import SwiftUI

@MainActor
final class LeagueViewModel: ObservableObject {

    func timeUntilReset() -> String {
        let calendar = Calendar.current
        let now = Date.now

        // Find next Monday midnight local time
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Monday
        guard let nextMonday = calendar.nextDate(after: now, matching: DateComponents(weekday: 2, hour: 0, minute: 0), matchingPolicy: .nextTime) else {
            return "—"
        }

        let diff = calendar.dateComponents([.day, .hour, .minute], from: now, to: nextMonday)
        let days = diff.day ?? 0
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0

        return "Resets in \(days)d \(hours)h \(minutes)m"
    }

    func weeklyXP(from sessions: [Session]) -> Int {
        sessions.map(\.xpEarned).reduce(0, +)
    }

    func weeklyBestScore(from sessions: [Session]) -> Int {
        sessions.map(\.overallScore).max() ?? 0
    }
}
```

- [ ] **Step 2: Implement full LeagueView**

```swift
// $SRC/Features/League/LeagueView.swift
import SwiftUI
import SwiftData

struct LeagueView: View {
    @Query(sort: \Session.date, order: .reverse) private var allSessions: [Session]
    @StateObject private var viewModel = LeagueViewModel()

    private var weekSessions: [Session] {
        PersistenceService.shared.sessionsThisWeek()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weeklyStatsCard
                    countdownTimer
                    leaderboardSection
                    tierInfoCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("League")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Weekly Stats

    private var weeklyStatsCard: some View {
        let sessions = weekSessions
        let weeklyXP = viewModel.weeklyXP(from: sessions)
        let tier = LeagueTier.from(weeklyXP: weeklyXP)

        return VStack(spacing: 12) {
            // Tier badge
            HStack {
                Text(tier.displayName + " Tier")
                    .font(AppFonts.display(24))
                    .foregroundStyle(tier.color)
                Spacer()
            }

            HStack(spacing: 0) {
                statItem(value: "\(weeklyXP)", label: "Weekly XP")
                statItem(value: "\(sessions.count)", label: "Sessions")
                statItem(value: "\(viewModel.weeklyBestScore(from: sessions))", label: "Best Score")
            }

            // XP to next tier
            if let nextXP = tier.xpForNextTier {
                let remaining = nextXP - weeklyXP
                Text("\(remaining) XP to \(LeagueTier.allCases[LeagueTier.allCases.firstIndex(of: tier)! + 1].displayName)")
                    .font(AppFonts.body(12))
                    .foregroundStyle(AppColors.sub)
            }
        }
        .cardStyle()
    }

    // MARK: - Countdown

    private var countdownTimer: some View {
        Text(viewModel.timeUntilReset())
            .font(AppFonts.bodyMedium(14))
            .foregroundStyle(AppColors.sub)
            .frame(maxWidth: .infinity)
            .cardStyle()
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.sub)

            Text("Compete with friends — invite someone to unlock the leaderboard")
                .font(AppFonts.body(14))
                .foregroundStyle(AppColors.sub)
                .multilineTextAlignment(.center)

            ShareLink(item: URL(string: "https://apps.apple.com/app/parlance")!) {
                Text("Invite Friends")
                    .font(AppFonts.bodyBold(14))
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.gold.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Tier Info

    private var tierInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tier Thresholds")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            ForEach(LeagueTier.allCases, id: \.self) { tier in
                HStack {
                    Circle()
                        .fill(tier.color)
                        .frame(width: 10, height: 10)
                    Text(tier.displayName)
                        .font(AppFonts.body(14))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text("\(tier.minXP)+ XP")
                        .font(AppFonts.body(12))
                        .foregroundStyle(AppColors.sub)
                }
            }
        }
        .cardStyle()
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.display(20))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(AppFonts.body(11))
                .foregroundStyle(AppColors.sub)
        }
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add "$SRC/Features/League/LeagueView.swift" "$SRC/Features/League/LeagueViewModel.swift"
git commit -m "feat: implement League tab — weekly stats, tier badge, countdown, invite"
```

---

## Phase 13: Profile Tab

### Task 31: Profile View & View Model

**Files:**
- Modify: `$SRC/Features/Profile/ProfileView.swift`
- Create: `$SRC/Features/Profile/ProfileViewModel.swift`

- [ ] **Step 1: Implement ProfileViewModel**

```swift
// $SRC/Features/Profile/ProfileViewModel.swift
import SwiftUI
import UserNotifications

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var dailyReminderEnabled = false
    @Published var soundEffectsEnabled = true
    @Published var autoAdvanceEnabled = false
    @Published var showResetConfirmation = false

    func loadSettings() {
        dailyReminderEnabled = UserDefaults.standard.bool(forKey: "dailyReminderEnabled")
        soundEffectsEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
        autoAdvanceEnabled = UserDefaults.standard.bool(forKey: "autoAdvanceEnabled")
    }

    func toggleDailyReminder(_ enabled: Bool) {
        dailyReminderEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "dailyReminderEnabled")

        if enabled {
            requestNotificationPermission()
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    func toggleSoundEffects(_ enabled: Bool) {
        soundEffectsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "soundEffectsEnabled")
    }

    func toggleAutoAdvance(_ enabled: Bool) {
        autoAdvanceEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "autoAdvanceEnabled")
    }

    func resetAllData() {
        PersistenceService.shared.resetAllData()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                if granted {
                    self.scheduleDailyReminder()
                } else {
                    self.dailyReminderEnabled = false
                    UserDefaults.standard.set(false, forKey: "dailyReminderEnabled")
                }
            }
        }
    }

    private func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Parlance"
        content.body = "Your daily challenge is waiting 🎤"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().add(request)
    }
}
```

- [ ] **Step 2: Implement full ProfileView**

```swift
// $SRC/Features/Profile/ProfileView.swift
import SwiftUI
import SwiftData
import SafariServices

struct ProfileView: View {
    @Query private var users: [User]
    @Query(sort: \Achievement.id) private var achievements: [Achievement]
    @StateObject private var viewModel = ProfileViewModel()

    private var user: User? { users.first }

    private let achievementColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    xpSection
                    achievementGrid
                    settingsSection
                    menuSection
                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(AppColors.bg)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.loadSettings() }
            .alert("Reset All Data", isPresented: $viewModel.showResetConfirmation) {
                Button("Reset", role: .destructive) { viewModel.resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your sessions, XP, streaks, and achievements. This cannot be undone.")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            if let user {
                Text(user.avatarEmoji)
                    .font(.system(size: 60))

                Text(user.displayName)
                    .font(AppFonts.bodyBold(22))
                    .foregroundStyle(AppColors.text)

                Text("Joined \(user.joinDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppFonts.body(13))
                    .foregroundStyle(AppColors.sub)

                PillBadge(text: "Rank \(user.rank.level) · \(user.rank.name)")

                HStack(spacing: 12) {
                    Text("🔥 \(user.currentStreak)-day streak")
                        .font(AppFonts.bodyMedium(13))
                        .foregroundStyle(AppColors.gold)

                    Text("Best: \(user.longestStreak) days")
                        .font(AppFonts.body(13))
                        .foregroundStyle(AppColors.sub)
                }
            }
        }
    }

    // MARK: - XP

    private var xpSection: some View {
        Group {
            if let user {
                XPProgressBar(currentXP: user.xp, rank: user.rank)
            }
        }
    }

    // MARK: - Achievements

    private var achievementGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(AppFonts.bodyBold(16))
                .foregroundStyle(AppColors.text)

            LazyVGrid(columns: achievementColumns, spacing: 12) {
                ForEach(achievements, id: \.id) { achievement in
                    VStack(spacing: 6) {
                        Image(systemName: achievement.iconName)
                            .font(.system(size: 24))
                            .foregroundStyle(achievement.isUnlocked ? AppColors.gold : AppColors.sub.opacity(0.4))

                        Text(achievement.name)
                            .font(AppFonts.bodyMedium(12))
                            .foregroundStyle(achievement.isUnlocked ? AppColors.text : AppColors.sub)
                            .multilineTextAlignment(.center)

                        if !achievement.isUnlocked && achievement.goal > 1 {
                            Text("\(achievement.progress)/\(achievement.goal)")
                                .font(AppFonts.body(10))
                                .foregroundStyle(AppColors.sub)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(achievement.isUnlocked ? AppColors.gold.opacity(0.08) : AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(achievement.isUnlocked ? AppColors.gold.opacity(0.3) : AppColors.border, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            Toggle(isOn: Binding(
                get: { viewModel.dailyReminderEnabled },
                set: { viewModel.toggleDailyReminder($0) }
            )) {
                Text("Daily Reminder")
                    .font(AppFonts.body(15))
                    .foregroundStyle(AppColors.text)
            }
            .tint(AppColors.gold)
            .padding(.vertical, 12)

            Divider().background(AppColors.border)

            Toggle(isOn: Binding(
                get: { viewModel.soundEffectsEnabled },
                set: { viewModel.toggleSoundEffects($0) }
            )) {
                Text("Sound Effects")
                    .font(AppFonts.body(15))
                    .foregroundStyle(AppColors.text)
            }
            .tint(AppColors.gold)
            .padding(.vertical, 12)

            Divider().background(AppColors.border)

            Toggle(isOn: Binding(
                get: { viewModel.autoAdvanceEnabled },
                set: { viewModel.toggleAutoAdvance($0) }
            )) {
                Text("Auto-Advance After Results")
                    .font(AppFonts.body(15))
                    .foregroundStyle(AppColors.text)
            }
            .tint(AppColors.gold)
            .padding(.vertical, 12)
        }
        .cardStyle()
    }

    // MARK: - Menu

    @State private var showPrivacyPolicy = false

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "bell", title: "Notification Preferences") {
                PermissionsService().openSettings()
            }

            Divider().background(AppColors.border)

            menuRow(icon: "lock.shield", title: "Privacy Policy") {
                showPrivacyPolicy = true
            }

            Divider().background(AppColors.border)

            Button {
                viewModel.showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(AppColors.red)
                    Text("Reset All Data")
                        .font(AppFonts.body(15))
                        .foregroundStyle(AppColors.red)
                    Spacer()
                }
                .padding(.vertical, 12)
            }
        }
        .cardStyle()
        .sheet(isPresented: $showPrivacyPolicy) {
            let urlString = Bundle.main.object(forInfoDictionaryKey: "ParlancePrivacyPolicyURL") as? String ?? "https://example.com/privacy"
            SafariView(url: URL(string: urlString)!)
        }
    }

    private func menuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.sub)
                Text(title)
                    .font(AppFonts.body(15))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.sub)
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("Parlance v1.0 · Made with 🎤")
            .font(AppFonts.body(12))
            .foregroundStyle(AppColors.sub)
    }
}
```

- [ ] **Step 3: Build to verify compilation**

- [ ] **Step 4: Commit**

```bash
git add "$SRC/Features/Profile/ProfileView.swift" "$SRC/Features/Profile/ProfileViewModel.swift"
git commit -m "feat: implement Profile tab — achievements, settings, reminders, reset"
```

---

## Phase 14: Question Bank Generation

### Task 32: Generate Full Question Bank (400+ Questions)

**Files:**
- Modify: `$SRC/Resources/questions.json`

- [ ] **Step 1: Generate the complete question bank**

Replace the placeholder `questions.json` with 400+ real, curated questions. Use Claude to generate them in a batch. The structure:

```json
[
  {
    "id": "{mode}_{band}_{NNN}",
    "mode": "interview|pitch|keynote|casual",
    "difficultyBand": "1-2|3-4|5-6|7-8|9-10",
    "question": "The actual prompt text",
    "tips": ["Tip 1", "Tip 2", "Tip 3"],
    "targetDuration": 60|90|120,
    "difficultyNote": "Brief note about what makes this level appropriate"
  }
]
```

Requirements:
- 4 modes × 5 bands × 20 questions = 400 minimum
- Use the example prompts from §8 of the spec as starting points
- Each tip should be specific and actionable (not generic)
- Target durations: 60s for L1-2, 90s for L3-6, 120s for L7-10
- IDs follow pattern: `interview_1-2_001`, `pitch_3-4_015`, etc.

This is a one-time generation task. Generate the full JSON file and add it to the bundle.

- [ ] **Step 2: Run the QuestionBankService test to verify 400+ questions load correctly**

Run: `xcodebuild test -project "Parlance: AI Speech Coach.xcodeproj" -scheme "Parlance: AI Speech Coach" -destination "platform=iOS Simulator,name=iPhone 16" -only-testing:"Parlance: AI Speech CoachTests/QuestionBankServiceTests" 2>&1 | tail -20`
Expected: PASS — all questions load, all mode/band combos have ≥20

- [ ] **Step 3: Commit**

```bash
git add "$SRC/Resources/questions.json"
git commit -m "feat: add complete question bank — 400+ curated questions across all modes and bands"
```

---

## Phase 15: Cloudflare Worker Proxy

### Task 33: Cloudflare Worker Implementation

**Files:**
- Create: `cloudflare-worker/wrangler.toml`
- Create: `cloudflare-worker/src/index.js`

- [ ] **Step 1: Create wrangler.toml**

```toml
# cloudflare-worker/wrangler.toml
name = "parlance-api"
main = "src/index.js"
compatibility_date = "2024-01-01"

[vars]
CLAUDE_MODEL = "claude-haiku-4-5-20251001"
```

- [ ] **Step 2: Implement the Worker**

```javascript
// cloudflare-worker/src/index.js
export default {
  async fetch(request, env) {
    // CORS headers
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const url = new URL(request.url);
    if (url.pathname !== "/feedback") {
      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    try {
      const body = await request.json();
      const messages = body.messages;

      if (!messages || !Array.isArray(messages)) {
        return new Response(JSON.stringify({ error: "Invalid request body" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: env.CLAUDE_MODEL,
          max_tokens: 300,
          messages: messages,
        }),
      });

      if (!anthropicResponse.ok) {
        const errorText = await anthropicResponse.text();
        return new Response(JSON.stringify({ error: "Upstream API error", details: errorText }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const result = await anthropicResponse.json();
      const content = result.content?.[0]?.text || "";

      // Parse the JSON response from Claude
      let feedback;
      try {
        const parsed = JSON.parse(content);
        feedback = parsed.feedback;
      } catch {
        feedback = content;
      }

      return new Response(JSON.stringify({ feedback }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: "Internal server error" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  },
};
```

- [ ] **Step 3: Deploy the worker**

```bash
cd cloudflare-worker
npx wrangler secret put ANTHROPIC_API_KEY
# (paste your Anthropic API key when prompted)
npx wrangler deploy
```

- [ ] **Step 4: Update Info.plist with the deployed Worker URL**

Replace `https://parlance-api.yourdomain.workers.dev` with the actual deployed URL.

- [ ] **Step 5: Commit**

```bash
git add cloudflare-worker/
git commit -m "feat: add Cloudflare Worker proxy for Claude API — single /feedback endpoint"
```

---

## Phase 16: Analytics (TelemetryDeck)

### Task 34: TelemetryDeck Integration

**Files:**
- Create: `$SRC/Core/Services/AnalyticsService.swift`
- Modify: `$SRC/Parlance__AI_Speech_CoachApp.swift`

- [ ] **Step 1: Add TelemetryDeck Swift Package**

In Xcode: File → Add Package Dependencies → `https://github.com/TelemetryDeck/SwiftSDK`

- [ ] **Step 2: Implement AnalyticsService**

```swift
// $SRC/Core/Services/AnalyticsService.swift
import TelemetryDeck

enum AnalyticsService {
    static func initialize() {
        let config = TelemetryDeck.Config(appID: "YOUR_TELEMETRYDECK_APP_ID")
        TelemetryDeck.initialize(config: config)
    }

    static func sessionStarted(mode: SessionMode, level: Int) {
        TelemetryDeck.signal("sessionStarted", parameters: [
            "mode": mode.rawValue,
            "level": "\(level)"
        ])
    }

    static func sessionCompleted(mode: SessionMode, level: Int, overallScore: Int, duration: TimeInterval, wasDailyChallenge: Bool) {
        TelemetryDeck.signal("sessionCompleted", parameters: [
            "mode": mode.rawValue,
            "level": "\(level)",
            "overallScore": "\(overallScore)",
            "duration": "\(Int(duration))",
            "wasDailyChallenge": "\(wasDailyChallenge)"
        ])
    }

    static func dailyChallengeCompleted(mode: SessionMode, level: Int) {
        TelemetryDeck.signal("dailyChallengeCompleted", parameters: [
            "mode": mode.rawValue,
            "level": "\(level)"
        ])
    }

    static func rankUp(newRank: Int, rankName: String) {
        TelemetryDeck.signal("rankUp", parameters: [
            "newRank": "\(newRank)",
            "rankName": rankName
        ])
    }

    static func achievementUnlocked(id: String, name: String) {
        TelemetryDeck.signal("achievementUnlocked", parameters: [
            "achievementId": id,
            "achievementName": name
        ])
    }
}
```

- [ ] **Step 3: Initialize TelemetryDeck in app entry point**

Add to `Parlance__AI_Speech_CoachApp.swift`'s `init()`:

```swift
@main
struct Parlance__AI_Speech_CoachApp: App {
    init() {
        AnalyticsService.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceService.shared.container)
    }
}
```

- [ ] **Step 4: Wire up analytics calls in SessionCoordinator**

In `SessionCoordinator.processSession()`, add after session creation:

```swift
AnalyticsService.sessionCompleted(
    mode: state.mode, level: state.difficultyLevel,
    overallScore: overallScore, duration: duration,
    wasDailyChallenge: state.wasDailyChallenge
)
if state.wasDailyChallenge {
    AnalyticsService.dailyChallengeCompleted(mode: state.mode, level: state.difficultyLevel)
}
```

And at the start of the session (in the `.loading` → `.recording` transition or in `startSession`):

```swift
AnalyticsService.sessionStarted(mode: state.mode, level: state.difficultyLevel)
```

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Core/Services/AnalyticsService.swift" "$SRC/Parlance__AI_Speech_CoachApp.swift" \
  "$SRC/Features/Session/SessionCoordinator.swift"
git commit -m "feat: add TelemetryDeck analytics — session, challenge, rank, achievement events"
```

---

## Phase 17: App Configuration & Polish

### Task 35: Info.plist & Project Configuration

**Files:**
- Modify: `Info.plist`

- [ ] **Step 1: Set portrait-only orientation**

```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>
```

- [ ] **Step 2: Add microphone and speech recognition usage descriptions**

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Parlance needs your microphone to record your practice sessions.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Parlance uses on-device speech recognition to analyze your speaking performance.</string>
```

- [ ] **Step 3: Set minimum deployment target to iOS 17.0**

In Xcode project settings: General → Minimum Deployments → iOS 17.0

- [ ] **Step 4: Commit**

```bash
git add "Parlance: AI Speech Coach/Info.plist" "Parlance: AI Speech Coach.xcodeproj/"
git commit -m "chore: configure Info.plist — portrait lock, permissions, API URLs"
```

---

### Task 36: Accessibility & Reduce Motion

**Files:**
- Modify: `$SRC/Features/Results/ScoreRingView.swift`
- Modify: `$SRC/Features/Session/LoadingView.swift`
- Modify: `$SRC/UI/Components/AnimatedWaveformView.swift`

- [ ] **Step 1: Add Reduce Motion support to ScoreRingView**

```swift
// Add to ScoreRingView
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Change the onAppear:
.onAppear {
    if reduceMotion {
        animatedProgress = Double(score) / 100.0
    } else {
        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
            animatedProgress = Double(score) / 100.0
        }
    }
}
```

- [ ] **Step 2: Add Reduce Motion support to LoadingView**

Replace the pulsing animation `onAppear` with:
```swift
.onAppear {
    if !UIAccessibility.isReduceMotionEnabled {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
    }
}
```

- [ ] **Step 3: Add VoiceOver labels to ScoreRingView**

```swift
.accessibilityElement()
.accessibilityLabel("Overall score \(score) out of 100")
```

- [ ] **Step 4: Add VoiceOver labels to key interactive elements**

Add `.accessibilityLabel()` modifiers to:
- Recording mic button: "Start recording" / "Stop recording"
- Mode grid cards: "{mode name} practice mode"
- Daily challenge card: "Daily challenge, {mode}, level {level}, plus {xp} XP"

- [ ] **Step 5: Commit**

```bash
git add "$SRC/Features/Results/ScoreRingView.swift" "$SRC/Features/Session/LoadingView.swift" \
  "$SRC/UI/Components/AnimatedWaveformView.swift" "$SRC/Features/Session/RecordingView.swift" \
  "$SRC/Features/Home/DailyChallengeCard.swift" "$SRC/Features/Home/ModeGridView.swift"
git commit -m "feat: add Reduce Motion support and VoiceOver labels for accessibility"
```

---

## Phase 18: Final Integration Tests

### Task 37: Question Bank Build-Time Validation Test

**Files:**
- Create: `$TEST/Core/Services/QuestionBankValidationTests.swift`

- [ ] **Step 1: Write the build-time validation test**

```swift
// $TEST/Core/Services/QuestionBankValidationTests.swift
import XCTest
@testable import Parlance__AI_Speech_Coach

final class QuestionBankValidationTests: XCTestCase {
    func testQuestionBankParsesAndMeetsMinimumCount() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "questions", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let questions = try JSONDecoder().decode([Question].self, from: data)

        // Must have at least 400 questions total
        XCTAssertGreaterThanOrEqual(questions.count, 400, "Question bank must have ≥400 questions")

        // Verify minimum 20 per mode per band
        let modes: [SessionMode] = [.interview, .pitch, .keynote, .casual]
        let bands = ["1-2", "3-4", "5-6", "7-8", "9-10"]

        for mode in modes {
            for band in bands {
                let count = questions.filter { $0.mode == mode && $0.difficultyBand == band }.count
                XCTAssertGreaterThanOrEqual(count, 20,
                    "\(mode.rawValue) band \(band) needs ≥20 questions, found \(count)")
            }
        }

        // Verify all questions have valid data
        for q in questions {
            XCTAssertFalse(q.id.isEmpty, "Question ID must not be empty")
            XCTAssertFalse(q.question.isEmpty, "Question text must not be empty")
            XCTAssertEqual(q.tips.count, 3, "Question \(q.id) must have exactly 3 tips")
            XCTAssertGreaterThan(q.targetDuration, 0, "Question \(q.id) must have a positive targetDuration")
        }

        // Verify no duplicate IDs
        let ids = questions.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "Question IDs must be unique")
    }
}
```

- [ ] **Step 2: Run the test**

Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add "$TEST/Core/Services/QuestionBankValidationTests.swift"
git commit -m "test: add build-time question bank validation — structure, count, uniqueness"
```

---

### Task 38: Run Full Test Suite

- [ ] **Step 1: Run all tests**

Run: `xcodebuild test -project "Parlance: AI Speech Coach.xcodeproj" -scheme "Parlance: AI Speech Coach" -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 | tail -30`
Expected: ALL PASS

- [ ] **Step 2: Fix any failures**

Address any compilation or test failures.

- [ ] **Step 3: Final build verification**

Run: `xcodebuild build -project "Parlance: AI Speech Coach.xcodeproj" -scheme "Parlance: AI Speech Coach" -destination "platform=iOS Simulator,name=iPhone 16" 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve test and build issues for full MVP integration"
```

---

## Summary

| Phase | Tasks | What It Delivers |
|-------|-------|------------------|
| 1 — Design System | 1-3 | Color tokens, typography, constants, card style |
| 2 — Data Models | 4-8 | SessionMode, DifficultyLevel, Rank, LeagueTier, SwiftData models, Question |
| 3 — Core Services | 9-15 | Persistence, QuestionBank, SpeechAnalyzer, AudioRecorder, SpeechTranscriber, Permissions, Gamification |
| 4 — AI Integration | 16 | ClaudeClient, FeedbackGenerator |
| 5 — UI Components | 17-20 | Waveform, XP bar, score ring, pill badge, metric card, XP toast |
| 6 — App Shell | 21 | Entry point, tab bar, session overlay, stub views |
| 7 — First Launch | 22 | Setup screen with name, avatar, privacy link |
| 8 — Home Tab | 23-24 | Home view with daily challenge, mode grid, difficulty slider, weekly stats |
| 9 — Session Flow | 25-27 | Session coordinator state machine, loading view, recording view |
| 10 — Results | 28 | Results view with score ring, AI feedback, moments, metrics |
| 11 — Progress | 29 | Progress tab with charts, trends, modes, milestones, recents |
| 12 — League | 30 | League tab with weekly stats, tier badge, countdown, invite |
| 13 — Profile | 31 | Profile tab with achievements, settings, reminders, reset |
| 14 — Question Bank | 32 | 400+ curated questions across all modes and difficulty bands |
| 15 — Cloudflare Worker | 33 | Proxy endpoint for Claude API calls |
| 16 — Analytics | 34 | TelemetryDeck event tracking |
| 17 — Configuration | 35-36 | Info.plist, portrait lock, accessibility, Reduce Motion |
| 18 — Validation | 37-38 | Question bank validation test, full test suite pass |
