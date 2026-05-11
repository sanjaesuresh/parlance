# App Store Connect Submission Checklist — Parlance v1

Source of truth for every field in App Store Connect. Update this
file when you change a setting; do not let the source diverge from
what's live in Connect.

---

## 1. App Information

- **Bundle ID:** `org.Parlance` (TBD if renamed — see plan #18; bundle ID is permanent after first submission)
- **Name:** Parlance
- **Subtitle (≤30 chars):** `AI practice for public speaking`
  - Character count: 31 — trim to `AI coach for public speaking` (29 chars) if Connect rejects
- **Primary category:** Education
- **Secondary category:** Lifestyle (optional)
- **Age rating:** 12+

### Age rating questionnaire answers (recommended)

| Category | Answer | Rationale |
|---|---|---|
| Cartoon or fantasy violence | None | App has no animated violence of any kind |
| Realistic violence | None | No violent content; recording/coaching only |
| Sexual content or nudity | None | No sexual imagery, text, or user-generated nudity possible in current flows |
| Profanity or crude humor | Infrequent/Mild | User-generated display names and speech transcripts could contain profanity; a profanity filter is being added (Plan #1), but select Infrequent/Mild until filtering is live and verified |
| Alcohol, tobacco, or drugs | None | No consumption references; AI feedback prompts do not solicit or reward substance content |
| Simulated gambling | None | The league/XP system is skill-based, not randomised; no wagering mechanic |
| Horror or fear themes | None | App has no horror, jump-scares, or disturbing visual content |
| Mature or suggestive themes | None | Practice prompts (interview, pitch, keynote, daily convo) contain no mature or suggestive content; free-text UGC risk is low and filtered at submit |
| Unrestricted web access | None | App does not embed a general-purpose browser; any external links (privacy policy, support, terms) open a specific known URL in Safari |
| Gambling and contests | None | No real-money gambling; weekly league is a zero-cost skill leaderboard, not a contest with prizes |

---

## 2. Pricing & Availability

- **Price tier:** Free (monetised through an auto-renewable subscription IAP — see Section 6)
- **Available regions:** All (verify after submission; confirm subscription availability per region in the Subscriptions section)
- **Pre-order:** No

---

## 3. App Privacy

### Data types declared (Privacy Nutrition Label)

All declarations must match the rewritten privacy policy (Plan #5) before submission.

| Data type | Linked to user? | Tracking? | Purpose |
|---|---|---|---|
| Email Address | Yes | No | App Functionality — required for account creation and authentication |
| User ID (Apple identifier / Supabase UID) | Yes | No | App Functionality — links all server-side records to the account |
| Name (display name, username) | Yes | No | App Functionality — shown on leaderboards and friend profiles |
| Coarse Location (city string from profile setup) | Yes | No | App Functionality — optional profile field, stored in Supabase `profiles` |
| Other User Content (speech transcripts) | Yes | No | App Functionality — transcript sent to AI provider for post-session feedback |
| Audio Data | Yes | No | App Functionality — recorded on device, deleted after transcription; if Hume re-enabled, audio is transmitted (declare at that point) |
| Health & Fitness | No | No | Not collected |
| Product Interaction (analytics) | Not applicable — analytics removed for v1 (Plan #17) | — | If TelemetryDeck is added post-v1, declare "Usage Data → Product Interaction" |
| Crash Data | Not applicable — no crash SDK in v1 | — | If Sentry/Crashlytics added, declare at that time |

### Privacy policy URL

`https://theparlance.app/privacy`

The current live policy contains material inaccuracies (Plan #5). The policy **must be rewritten and republished** before submission. Key required corrections:
- Replace "Claude AI (Anthropic)" with the actual provider (Google Gemini via Cloudflare Worker)
- Remove the claim that data is stored on-device only; accurately describe Supabase storage
- Describe the "Delete Account" path (not "Reset All Data") as the data-deletion mechanism
- Add Supabase as a third-party data processor
- Add push token disclosure
- Remove Hume references until Hume is re-enabled
- Add data retention periods and GDPR/CCPA sections

---

## 4. Localized Listing (en-US)

### Description (paste-ready, ~250 words)

```
Parlance is the consumer-grade, habit-forming speech coach built for people with real stakes — job interviews, investor pitches, keynotes, and every high-pressure conversation in between. Pick a mode, get a prompt, record yourself, and receive AI coaching feedback in seconds. Repeat until the nerves are gone.

Four practice modes cover the situations that matter most. Job Interview coaches you through behavioral and situational questions with a focus on STAR structure, conciseness, and confidence signals. Pitch trains you on investor decks, cold outreach, and objection handling — hook strength and urgency over filler words. Keynote prepares you for TED-style talks, conference sessions, and toasts, sharpening your narrative arc and opening impact. Daily Convo builds the everyday skills that most coaches ignore: explaining a complex idea simply, holding a room's attention, debating on the fly.

After each session, you get a score across five metrics — filler words, pace, clarity, structure, and vocabulary strength — plus an AI coaching paragraph that knows the difference between an interview and a pitch. You'll see your best and worst moment from the recording, and exactly what to improve next time.

Parlance keeps you coming back through streaks, XP, weekly league leaderboards, and over 400 practice questions across five difficulty levels — all available offline, with zero loading time. Levels 7–10 and additional modes unlock with Parlance Pro.

This is not a corporate training tool. It's a private practice room in your pocket, built for the individual who wants to get genuinely better.
```

### Keywords (≤100 chars, comma-separated)

```
speech,coach,public speaking,interview,pitch,AI,toastmasters,presentation,vocabulary,confidence
```

Character count: 94 — within the 100-character limit. Verify with a character counter before submission.

### Promotional text (≤170 chars)

```
Your AI speech coach. Practice interviews, pitches, and presentations. Real feedback after every session. No fluff, no filler.
```

Character count: 126 — well within the 170-character limit.

### What's New (release notes)

```
v1.0: Initial release.
```

### Support URL

`https://theparlance.app/support`

Verify this returns a 200 before submission (confirmed 200 at time of mock review).

### Marketing URL

`https://theparlance.app`

### Copyright

`© 2026 Parlance`

---

## 5. Screenshots

### Required device sizes

| Device family | Required? | Notes |
|---|---|---|
| 6.7" or 6.9" iPhone (iPhone 15/16 Pro Max) | **Required** | Use the 6.9" (iPhone 16 Pro Max) frame if available — covers both sizes |
| iPad 13" | Required while `TARGETED_DEVICE_FAMILY = "1,2"` (universal) | See Plan #11 — if you drop to iPhone-only before submission, iPad screenshots are no longer required |
| 5.5" iPhone (iPhone 8 Plus) | Optional | Cover if you have time; Apple may request it for older device users |

### Recommended shots (6 total, in order)

1. **Home screen / mode grid** — show the four mode cards, daily challenge, and XP bar. Establishes the gamification loop immediately.
2. **Recording screen mid-session** — show the live waveform, timer, and practice prompt. Communicates the core mechanic.
3. **Results screen with AI feedback** — show the overall score, AI coach paragraph, and metric bars. This is the product's core value proposition.
4. **League / leaderboard** — show the weekly countdown and friend rankings. Communicates the social and retention layer.
5. **Paywall** — required by App Store Connect if a subscription IAP is present; also needed as the review screenshot for the IAP record.
6. **Achievement / Profile** — show unlocked achievements, streak counter, and level. Reinforces the habit loop.

---

## 6. In-App Purchase Configuration

- **Product ID:** `com.parlance.pro.monthly`
- **Type:** Auto-Renewable Subscription
- **Subscription group:** Pro
- **Localized display name:** `Parlance Pro Monthly`
- **Description:** `Unlocks all practice modes, difficulty levels 7–10, and unlimited daily sessions.`
- **Price:** $9.99/month tier
- **Intro offer:** None for v1 (TBD post-launch based on conversion data)
- **Review screenshot:** Required — capture the PaywallView with the subscription CTA visible; Apple requires this for every subscription product record

### Paywall compliance notes (must resolve before submission)

- Plan #2: Add Terms of Use and Privacy Policy links to `PaywallView`. Both URLs must return 200.
- Plan #4: Remove the "Tone & Emotion Analysis" benefit bullet from `PaywallView.benefits` until the Hume feature ships, or re-enable Hume and the `ToneAnalysisCard`.
- Plan #23: Remove the hardcoded `"$9.99"` fallback; show a `ProgressView` while the product loads; never render a CTA without a loaded StoreKit product.

---

## 7. EULA

Opt into **Apple's Standard EULA** in App Store Connect unless legal requires a custom EULA.

Apple Standard EULA link: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

If using the Standard EULA:
- Also ensure the Community Guidelines URL (`https://theparlance.app/guidelines`) is published before submission — Settings currently links to it (Plan #1).
- Reference the standard EULA URL in the Settings → Terms of Service link on the paywall so the Terms page returns 200 (Plan #2).

If a custom EULA is required:
- Publish it at `https://theparlance.app/terms` (currently 404 — Plan #2).
- Select "Custom EULA" in App Store Connect and paste the text.

---

## 8. Sign-in & Demo Account

| Field | Value |
|---|---|
| Sign in with Apple | Enabled (capability + entitlement confirmed) |
| Email + password | Enabled |
| Demo account email | `reviewer@parlance.app` — **replace with a real working account before submission** |
| Demo account password | `Parlance-Reviewer-2026!` — **replace before submission** |
| Note in review notes | "Sign in with Apple also works. After tapping 'Sign in with Apple,' complete the Apple ID prompt; the app then shows the one-time profile setup screen." |

The demo account must be pre-created in the production (or TestFlight) environment before you submit. App Review will use it in the live build, not sandbox.

---

## 9. Review Notes (paste-ready)

Replace placeholder credentials before submission. This is the exact text to paste into the App Review Notes field in App Store Connect.

---

**Parlance — AI Speech Coach**

Parlance is a public-speaking practice app. Users pick a mode (Interview / Pitch / Keynote / Daily Convo), receive a question, record themselves answering, and get AI-generated practice feedback. All AI feedback is framed as practice, not professional coaching, therapy, or medical advice.

**How to test the main flow:**
1. Sign in. The fastest path is "Sign in with Apple." A demo email account is also provided below.
2. Complete the brief profile setup (name + comfort level).
3. From the Home tab, tap any practice mode (e.g. "Interview").
4. The app shows a question, runs a 3-2-1 countdown, then prompts for Microphone and Speech Recognition permission. Please grant both.
5. Speak for at least 5 seconds (you can speak up to 3 minutes). Tap the red square to finish.
6. The app uploads the transcript (not the audio file) to our backend over HTTPS for AI feedback generation. The audio file is deleted from the device immediately after transcription.
7. The Results screen shows an overall score, AI coaching paragraph, best/worst moment, and metric breakdown.

**Demo account (replace before submission):**
Email: `reviewer@parlance.app`
Password: `Parlance-Reviewer-2026!`

**How to test the subscription:**
Profile → Settings → "Upgrade to Pro." Product is `com.parlance.pro.monthly` at $9.99/month. Pro unlocks levels 7–10 and additional practice modes. "Restore purchases" is in the same paywall.

**How to test account deletion:**
Profile → Settings → "Delete Account" → confirm. The auth user, all profile data, all session scores, friendships, push tokens, and user stats are deleted server-side. For Sign in with Apple users, Apple's revoke endpoint is called server-side.

**Privacy notes for reviewers:**
- Audio is recorded on device; only the transcript is sent to our AI provider for coaching feedback over an encrypted HTTPS connection. The audio file is deleted after processing.
- We use Sign in with Apple and email/password. Sign in with Apple revokes are honored on account deletion.
- The social layer (League → Friends) includes Report and Block on every user profile and on incoming friend requests. Display names and usernames are screened with a profanity filter at submit.

**Known reviewer concerns proactively addressed:**
- The app requires an account because AI feedback depends on per-user state (XP, streaks, history). A short profile setup follows sign-up.
- No payment is required to use the core practice loop on free modes and levels 1–6.
- All AI claims are framed as practice. No medical or therapeutic claims are made.

Backend endpoints: `https://parlance-api.parlance-app.workers.dev/{feedback, emotion, delete-user}`. Endpoints that operate on user data require a Supabase JWT Bearer token.

Contact: `parlance.app@gmail.com`

---

## 10. Export Compliance

- **Uses non-exempt encryption:** No
- `ITSAppUsesNonExemptEncryption = NO` is already set in the project's Release configuration.
- Rationale: The app uses only standard HTTPS/TLS (exempt under US BIS EAR). No custom encryption, no VPN, no additional cryptographic algorithms beyond the OS-provided TLS stack.

---

## 11. Capabilities & Entitlements

| Capability | Status | Notes |
|---|---|---|
| Sign in with Apple | Enabled | Confirmed in `ParlanceDebug.entitlements`; must be present in the Release entitlements file created for Plan #7 |
| Push Notifications | Enabled | Currently `aps-environment = development` in both Debug and Release — must be `production` in the Release entitlements file (Plan #7); upload the APNs production Auth Key in App Store Connect before submission |
| Background Modes | `remote-notification` only | Confirmed |
| App Sandbox | Not applicable (iOS) | — |
| App Groups | None | — |
| iCloud | None | — |
| Game Center | None | — |
| In-App Purchase | Enabled | Required for `com.parlance.pro.monthly` |

---

## 12. Pre-submission Checklist

Work through this list from top to bottom before pressing "Submit for Review."

### Blockers (must be closed — will cause rejection on first review)

- [ ] Plan #1 complete: Report and Block UI on user profiles; `blocked_users` / `user_reports` Supabase tables; profanity filter on free-text UGC fields; EULA or Community Guidelines link live
- [ ] Plan #2 complete: Terms of Use and Privacy Policy links in `PaywallView`; `/terms` URL returns 200 (or Apple Standard EULA selected in Connect and paywall links to it)
- [ ] Plan #3 complete: All four "on-device" copy locations rewritten to honestly describe transcript-only transmission
- [ ] Plan #4 complete: "Tone & Emotion Analysis" bullet removed from `PaywallView.benefits` (or Hume shipped and verified)
- [ ] Plan #5 complete: Privacy policy at `https://theparlance.app/privacy` rewritten and republished; all inaccuracies corrected
- [ ] Plan #6 complete: `PrivacyInfo.xcprivacy` added to the app bundle; App Store Connect upload accepted without manifest warning

### High priority (strongly recommended before submission)

- [ ] Plan #7 complete: Release entitlements file uses `aps-environment = production`; APNs production Auth Key uploaded to App Store Connect
- [ ] Plan #9 complete: Sign in with Apple revoke called server-side on account deletion; all deletion steps moved into Worker; post-delete confirmation shown
- [ ] Plan #10 complete: This checklist — every field in Section 1–11 verified in App Store Connect
- [ ] Plan #11 decided: Either `TARGETED_DEVICE_FAMILY = "1"` (iPhone-only) set before submission, or real iPad layouts shipped and iPad screenshots produced
- [ ] Demo account created and confirmed working in the production build
- [ ] Screenshots produced for the required device sizes (Section 5)
- [ ] All metadata fields in Sections 1–4 entered in App Store Connect
- [ ] IAP record for `com.parlance.pro.monthly` configured with review screenshot, localized description, and EULA selection
- [ ] Privacy Nutrition Label answers entered in App Store Connect, aligned with the rewritten privacy policy

### Medium priority (high rejection risk if missed)

- [ ] Plan #8 decided: Email signup path settled (confirm-off + auto-sign-in, or confirm-on + "check your email" screen)
- [ ] Plan #12 complete: Practice-only disclaimer added in onboarding, Results, and Settings
- [ ] Plan #13 complete: Dedicated alert for Speech Recognition denial
- [ ] Plan #22 addressed: Review Notes explain why account creation is required before any value is shown

### Low / cleanup (reduce risk; fix before v1 if possible)

- [ ] Plan #16 complete: `isPro = true` DEBUG bypass tightened to simulator-only
- [ ] Plan #17 decided: TelemetryDeck either wired + declared in Privacy Labels, or removed
- [ ] Plan #18 decided: Bundle ID finalised before first submission (permanent); Supabase anon key removed from `Info.plist`
- [ ] Plan #20 complete: App icon visual review at all sizes; 1024×1024 marketing icon present
- [ ] Plan #21 complete: `questions.json.bak` and `ParlanceApp/build/` removed from repo
- [ ] Plan #23 complete: Hardcoded `"$9.99"` fallback removed; paywall CTA disabled while product loads
- [ ] Plan #24 complete: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` confirmed against App Store Connect record

### URL smoke-test (run before final submission)

- [ ] `https://theparlance.app` → 200
- [ ] `https://theparlance.app/privacy` → 200 and content is the rewritten policy
- [ ] `https://theparlance.app/support` → 200
- [ ] `https://theparlance.app/terms` → 200 (or App Store Connect EULA = Standard EULA and no app link to `/terms`)
- [ ] `https://theparlance.app/guidelines` → 200
