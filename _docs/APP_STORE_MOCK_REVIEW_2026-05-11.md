# App Store Mock Review: Production Submission Readiness
**Date:** 2026-05-11
**App:** Parlance — AI Speech Coach (`org.Parlance`, v1.0 build 1, iOS 18.0+, universal)
**Mode:** Analysis-only. No production source, project, plist, entitlements, assets, or migrations were modified during this review.

---

## A. Executive Summary

Parlance is well-architected for a v1: a clean SwiftUI structure, working Sign in with Apple, in-app account deletion, an audio recording + transcription pipeline, an AI scoring pipeline via Cloudflare Worker, Supabase-backed sync, a paywall, and gamification. The product story is coherent.

However, the app is **not ready to submit** as-is. The review surfaced several issues that Apple would almost certainly catch on first review, and a few that App Store Connect would reject at upload (privacy manifest, push entitlement environment). The most common rejection-trigger categories are all present: missing UGC controls, a paywall that is missing required disclosure links, false on-device privacy claims that contradict the actual implementation, a Pro paywall bullet for a feature that is commented-out in code, and a privacy policy with multiple inaccuracies.

- **Production code changed:** none. Analysis-only.
- **Plan file:** `_docs/plans/APP_REVIEW_PLAN_consolidated.md` (24 items).
- **Most likely rejection drivers (top 5):**
  1. UGC report/block/EULA missing (Guideline 1.2)
  2. Paywall missing Terms of Use and Privacy Policy links + broken `/terms` URL (3.1.2(a))
  3. "On-device" privacy claims that contradict server-side processing (5.1.1)
  4. Pro paywall advertises an emotion-analysis feature that is disabled in code (2.3.1)
  5. Privacy policy contains multiple statements that do not match the code (5.1.1 / 5.1.2)

## B. Final Verdict

**NOT READY: HIGH REJECTION RISK.**

Six blocker-class items and several high-priority items must be resolved before submission. None of the blockers are architectural — most are 1- to 3-day fixes (copy rewrites, two Supabase tables, a privacy manifest XML file, a Worker change, and one entitlements file). Once these are closed, a re-review at the "Ready After Minor Fixes" verdict is realistic.

## C. Reviewer Simulation Result

A reviewer who walks the app fresh from TestFlight will:
1. **Launch → Splash → Auth.** Acceptable. They will likely use Sign in with Apple.
2. **Profile setup → Home.** Acceptable.
3. **Start a session.** Mic and Speech Recognition pre-prompts present. Both alerts claim "on-device" — a reviewer who cross-references the privacy policy (which lists Anthropic and Hume as third parties) will see the contradiction.
4. **Record → Results.** Works. Best/worst moments shown. AI feedback is server-generated via Gemini (despite the policy saying Anthropic). Score is reasonable.
5. **Open Paywall.** Reviewer notices no Terms of Use link and no Privacy Policy link → flag.
6. **Tap "Tone & Emotion Analysis" Pro bullet expectation.** After purchasing (sandbox), reviewer completes a session and finds no Tone Analysis card → flag.
7. **Open Profile → Settings → Delete Account.** Works (good). But if the reviewer signed in with Apple, the Apple revoke step is missing → flag.
8. **Open League → search for another user → tap profile.** Reviewer looks for Report / Block. Finds neither → flag.
9. **Open Settings → Terms of Service.** Loads 404 page → flag.

Blocked review paths:
- None outright blocked, but every blocker above is reachable in a 5-minute test pass.

Missing for reviewer:
- Working `/terms` page.
- Demo credentials in App Store Connect Review Notes.
- Privacy Nutrition Label answers aligned to rewritten policy.
- Privacy manifest in the binary.

## D. Guideline Risk Matrix

| Area | Risk |
|---|---|
| Safety (Guideline 1) | **HIGH** — UGC report/block missing |
| Performance (Guideline 2) | **MEDIUM** — broken /terms URL; paywall advertises disabled feature |
| Business (Guideline 3) | **HIGH** — paywall missing required disclosures and links |
| Design (Guideline 4) | **MEDIUM** — universal app with iPhone-only layouts |
| Legal (Guideline 5) | **HIGH** — privacy claims contradict code; Apple revoke missing |
| Privacy (5.1) | **HIGH** — on-device claims false; policy inaccurate |
| Account deletion (5.1.1(v)) | **MEDIUM** — deletion exists but partial-deletion risk + Apple revoke missing |
| IAP/subscriptions (3.1.2) | **HIGH** — paywall lacks Terms/Privacy links and ToS URL 404s |
| AI/speech/audio | **MEDIUM** — practice disclaimers absent in-app |
| Metadata consistency (2.3) | **HIGH** — paywall, privacy policy, in-app copy all disagree |
| Technical build readiness | **BLOCKER** — no `PrivacyInfo.xcprivacy`; Release entitlements wrong |
| Accessibility | **LOW** — partial labels present; full audit recommended |

## E. App Review Plans Created

All recommendations are in a single consolidated file (per user direction):

`_docs/plans/APP_REVIEW_PLAN_consolidated.md` — 24 numbered items, each with: status (B/H/M/L), issue, files, fix, verify.

| # | Title | Status |
|---|---|---|
| 1 | UGC moderation: report, block, profanity filter, EULA | Blocker |
| 2 | Paywall missing Terms of Use & Privacy links + broken /terms URL | Blocker |
| 3 | Misleading "on-device" privacy claims | Blocker |
| 4 | Paywall advertises a disabled feature (Tone & Emotion Analysis) | Blocker |
| 5 | Privacy policy contains material inaccuracies | Blocker |
| 6 | Add `PrivacyInfo.xcprivacy` privacy manifest | Blocker |
| 7 | Release build uses Debug entitlements + `aps-environment = development` | High |
| 8 | Email signup skips verification, marks user authenticated immediately | High |
| 9 | Account deletion: add Sign in with Apple revoke + server-orchestrate | High |
| 10 | App Store Connect metadata + Privacy Nutrition Labels + Review Notes | High |
| 11 | iPad support: ship iPhone-only or invest in real iPad layouts | High |
| 12 | AI speech coach safety disclaimers | Medium |
| 13 | Permission denial UX: speech denied has wrong alert | Medium |
| 14 | Cloudflare Worker hardening: auth + rate limit + CORS | Medium |
| 15 | Accessibility pass: VoiceOver labels + Dynamic Type at XXXL | Medium |
| 16 | Debug-only `isPro = true` — defensive guard | Low |
| 17 | Decide TelemetryDeck — ship analytics or remove scaffolding | Low |
| 18 | Bundle ID + custom Info.plist key naming + Supabase anon key duplication | Low |
| 19 | Supabase RLS audit + commit base schema migrations | Medium |
| 20 | App icon, launch screen, marketing assets — verify pre-submit | Low |
| 21 | Remove `questions.json.bak` and stop committing `ParlanceApp/build/` | Low |
| 22 | Login required before any value — verify justification or relax | Medium |
| 23 | Hardcoded paywall fallback price + missing intro offer surface | Low |
| 24 | App version & build number — bump for first submission | Low |

Items requiring human review (business / legal / backend / App Store Connect): 1 (EULA decision), 2 (publish ToS or opt into Apple's standard EULA), 5 (privacy policy rewrite), 10 (Connect metadata), 11 (iPad decision), 17 (analytics decision), 18 (bundle ID — permanent), 19 (RLS audit).

## F. Blocking Issues

For each blocker: issue, why Apple rejects, evidence, recommended fix, link.

### F1. UGC report/block/EULA missing
- **Why Apple rejects.** Guideline 1.2 is a hard requirement for apps with user-to-user interaction. Apple has rejected major apps for missing any one of: profanity filter on submitted content, in-app Report, in-app Block, accessible EULA / community guidelines.
- **Evidence.** No code path matching `report|block|moderate` in `Features/`; `Features/League/UserProfileDetailView.swift` exposes only "Done" and Unfriend; `Features/League/FriendRequestsSheet.swift` has accept/decline only; `Core/Services/SocialService.searchUsers` does not filter by a block list; `displayName`, `username`, `location`, `occupation` are free text in `AuthProfileSetupView` and `FirstLaunchSetupView`.
- **Fix.** Plan item #1.

### F2. Paywall missing Terms of Use & Privacy Policy + broken /terms URL
- **Why Apple rejects.** Guideline 3.1.2(a) is unambiguous about subscription paywalls requiring functional Terms of Use and Privacy Policy links plus subscription title, period, and price.
- **Evidence.** `PaywallView.legalText` shows only renewal copy; no `Link` to terms or privacy on the paywall. `curl -sI https://theparlance.app/terms` → `HTTP/2 404` (verified).
- **Fix.** Plan item #2.

### F3. False "on-device" privacy claims
- **Why Apple rejects.** Guideline 5.1.1 (Data Collection and Storage) — disclosures must match behavior. "On-device" is a privacy-sensitive claim Apple scrutinizes.
- **Evidence.** `SpeechTranscriber.swift` does not set `requiresOnDeviceRecognition = true`. Transcript is sent to the Cloudflare Worker (`ClaudeClient.fetchScoring → /feedback`) which forwards to Google Gemini. Four user-facing places claim "on-device" (two `RecordingView` alerts, `Info.plist` purpose string, Settings "About Your Data").
- **Fix.** Plan item #3.

### F4. Paywall advertises a disabled feature
- **Why Apple rejects.** Guideline 2.3.1 (Accurate Metadata) and 3.1.2(a) (subscriptions provide ongoing value). Charging for a feature that does not exist is a high-confidence rejection.
- **Evidence.** `PaywallView.benefits[2]` advertises "Tone & Emotion Analysis." `SessionCoordinator.processSession` has the Hume call commented out and `emotionResult = nil` always. `ResultsView` has `ToneAnalysisCard` commented out.
- **Fix.** Plan item #4.

### F5. Privacy policy inaccuracies
- **Why Apple rejects.** Guideline 5.1.1 / 5.1.2 — policy must match data flows.
- **Evidence (each verifiable):**
  - Policy: "Parlance uses Claude AI (Anthropic) to generate session feedback." → Worker calls Gemini (`cloudflare-worker/src/index.js handleFeedback`).
  - Policy: "Session data, transcripts, and your profile are stored on your device only." → `SyncService` and `SocialService` upload profile, stats, friendships, and scores to Supabase.
  - Policy: "Delete your data: Go to Profile → Settings → Reset All Data…" → that only wipes local SwiftData. The real deletion path is "Delete Account" which the policy never mentions.
  - Policy: "Portability: Your data stays on your device." → Supabase holds server-side rows.
  - Policy lists Hume but Hume is disabled in code.
  - No mention of Supabase or push tokens.
- **Fix.** Plan item #5.

### F6. Missing `PrivacyInfo.xcprivacy`
- **Why Apple rejects.** App Store Connect blocks uploads of apps using required-reason APIs without a privacy manifest.
- **Evidence.** `find . -name PrivacyInfo.xcprivacy` (outside `.claude/`) returns nothing. `UserDefaults` is used 17 times — that triggers the requirement.
- **Fix.** Plan item #6.

## G. High-Risk Issues

| Issue | Risk | Evidence | Fix |
|---|---|---|---|
| Release entitlements use `aps-environment = development` | Push notifications broken in production | `Parlance.xcodeproj/project.pbxproj` line ~543 + `ParlanceDebug.entitlements` | Plan #7 |
| Email signup flips `isAuthenticated = true` without a real session if email confirmation is on | Confused reviewer; silent server failures | `AuthService.signUp` and the `// TODO` comment | Plan #8 |
| Account deletion: no Apple Sign-In revoke; partial-deletion possible | Guideline 5.1.1(v) | `cloudflare-worker/src/index.js handleDeleteUser` and `AuthService.deleteAccount` | Plan #9 |
| App Store Connect metadata, demo account, and Review Notes incomplete | 2.3 Accurate Metadata | None in repo | Plan #10 |
| Universal app with iPhone-only layouts | Design 4.x | `TARGETED_DEVICE_FAMILY = "1,2"`, no `horizontalSizeClass` adaptations | Plan #11 |
| Login required before any value with no preview | 5.1.1(v) discouraged | `ContentView` gates everything on auth | Plan #22 |

## H. Medium / Low-Risk Observations

- AI feedback lacks in-app practice-only disclaimers (Plan #12)
- Speech-denied alert is misleading (Plan #13)
- Worker endpoints accept `*` CORS, no auth, no rate limit (Plan #14)
- VoiceOver labels missing on several icon-only controls (Plan #15)
- `SubscriptionService.isPro = true` in any DEBUG build — tighten to simulator-only (Plan #16)
- TelemetryDeck conditionally compiled but package not actually wired — decide and document (Plan #17)
- Bundle ID `org.Parlance` is unusual; embedded Supabase JWT in `Info.plist` (Plan #18)
- Supabase base-schema migrations not in repo; RLS audit recommended (Plan #19)
- App icon and launch-screen visual review needed (Plan #20)
- `questions.json.bak` and `ParlanceApp/build/` committed (Plan #21)
- Paywall shows hardcoded `$9.99` fallback (Plan #23)
- Version 1.0 / build 1 confirmation (Plan #24)

## I. Privacy and Data Collection Audit

| Data type | Source in code | Stored / transmitted? | Third party | Linked to user? | Tracking? | Privacy label / policy implication | Risk | Plan |
|---|---|---|---|---|---|---|---|---|
| Email | `AuthService.signUp`, `signIn` | Stored in Supabase (`auth.users`) | Supabase | Yes | No | Must declare "Contact Info → Email Address, Linked, App Functionality" | Medium | #5, #10 |
| Apple user identifier | `AuthService.signInWithApple` | Server | Apple → Supabase | Yes | No | "Identifiers → User ID, Linked" | Low | #10 |
| Display name, username, location, occupation, avatar | `AuthProfileSetupView`, `FirstLaunchSetupView`, `ProfileEditSheet`; uploaded by `SyncService.createProfile` | Stored in Supabase `profiles` | Supabase | Yes | No | Must declare "User Content" + UGC moderation requirements | High | #1, #5, #10 |
| Profile photo (`profileImageData`) | `ProfileEditSheet` (PhotosPicker) | Local SwiftData only (no Supabase upload observed) | None | Yes | No | Disclose locally-stored avatar | Low | #5 |
| Audio recording | `AudioRecorder.startRecording` | Saved to `tmp/`, deleted by `SessionCoordinator.processSession` after transcription | None (Hume disabled). Would be Hume if enabled | Yes (path embeds session UUID locally only) | No | Currently nil; if Hume re-enabled, "Audio Data, Linked, App Functionality" | Medium | #3, #4 |
| Speech transcript | `SpeechTranscriber.transcribe` → `ClaudeClient.fetchScoring` → Worker → Gemini | Transmitted (not stored remotely beyond request servicing per policy claim) | Google Gemini (currently — policy says Anthropic) | Yes (UID context if request included) | No | "Other User Content, Linked, App Functionality" | High | #3, #5 |
| AI feedback (scores, tips, best/worst moments) | `ScoringResult` → SwiftData `Session` | Stored locally; `session_scores` row also uploaded to Supabase | Supabase | Yes | No | Disclose | Medium | #5, #10 |
| Session metadata (mode, level, duration, score, XP) | `Session` SwiftData + `SyncService.syncAfterSession` | Local + Supabase `user_stats`, `session_scores` | Supabase | Yes | No | Disclose | Medium | #5 |
| Streaks, XP, weekly XP | `User`, synced by `SyncService` | Local + Supabase `user_stats` | Supabase | Yes | No | Disclose | Low | #5 |
| Friendship rows + friend-request rows | `SocialService` | Supabase `friendships`, `friend_requests` | Supabase | Yes | No | Disclose | Medium | #1, #5 |
| APNs device token | `PushTokenService.upsert` | Supabase `push_tokens` | Apple APNs + Supabase | Yes | No | Disclose; required for push delivery | Medium | #5, #7 |
| Coarse location (city string) | `AuthProfileSetupView` via `MKLocalSearchCompleter` (local) → uploaded to `profiles.location` | Supabase | Apple (search completion) + Supabase | Yes | No | "Location → Coarse Location, Linked, App Functionality" | Low | #5, #10 |
| App preferences (theme, daily reminder, sound, welcome flags) | `UserDefaults.standard` and `@AppStorage` | Local only | None | No | No | Triggers privacy-manifest UserDefaults reason `CA92.1` | High (manifest needed) | #6 |
| Analytics events | `AnalyticsService` (TelemetryDeck, conditionally compiled — not currently in the build) | Currently no-op | TelemetryDeck (if enabled) | Depends on TD config | No | If shipped, "Usage Data → Product Interaction" | Low | #17 |
| Push notification interactions | `AppDelegate.userNotificationCenter(_:didReceive:...)` | Routed in-app (Analytics call if enabled) | None | Yes | No | If analytics shipped, disclose | Low | #17 |
| Crash data | None observed (no Sentry / Crashlytics) | n/a | n/a | n/a | n/a | Optional to add; if added, disclose | n/a | n/a |

## J. Privacy Manifest / Required Reason API Audit

- **Existing privacy manifests:** none in the app target. Not in source, not in built `Parlance.app`.
- **Required Reason APIs in app code:**
  - `NSPrivacyAccessedAPICategoryUserDefaults` — 17 occurrences across `App/`, `Features/`, `Core/`. Use reason `CA92.1` (app's own settings).
  - `NSPrivacyAccessedAPICategoryFileTimestamp` — not used directly by app code.
  - `NSPrivacyAccessedAPICategoryDiskSpace` — not used directly.
  - `NSPrivacyAccessedAPICategorySystemBootTime` — not used.
  - `NSPrivacyAccessedAPICategoryActiveKeyboards` — not used.
- **Third-party SDK manifests:**
  - `supabase-swift` — should ship `PrivacyInfo.xcprivacy`; verify the resolved version does. Upgrade if not.
  - `TelemetryDeck` — not actually wired; if added, must include manifest.
- **Tracking domains:** none declared / none should be needed if no tracking SDKs are added.
- **Recommended implementation steps:** create `ParlanceApp/PrivacyInfo.xcprivacy`, add to Copy Bundle Resources, declare UserDefaults reason and any data types collected. See Plan #6.

## K. Permissions Audit

| Permission | Purpose string (project) | Needed? | Prompt timing | Denial handling | App Review risk | Plan |
|---|---|---|---|---|---|---|
| Microphone (`NSMicrophoneUsageDescription`) | "Parlance needs your microphone to record your practice sessions." | Yes — core flow | Pre-prompt → system alert at first record-tap | "Open Settings" alert if denied + recording can't proceed | LOW for behavior, HIGH for the "on-device" pre-prompt copy | #3 |
| Speech Recognition (`NSSpeechRecognitionUsageDescription`) | "Parlance uses speech recognition to transcribe your practice sessions and analyze your speaking performance." (project) — but built bundle shows older "on-device" string | Yes — for transcript | Pre-prompt → system alert after mic granted | Generic "Recording Failed" alert on denial (wrong) | HIGH | #3, #13 |
| Notifications (UN) | None — UN does not require a purpose string | Yes for Daily Reminder | Inside `ProfileViewModel.requestNotificationPermission` when user toggles Daily Reminder | Toggle reverts on denial | LOW | — |
| Photo Library | Not declared — `PhotosPicker` is permissionless | n/a | n/a | n/a | n/a | — |
| Location | Not declared — `MKLocalSearchCompleter` is permissionless | n/a | n/a | n/a | n/a | — |
| Contacts / Calendar / Bluetooth / Motion / Face ID / Tracking | Not declared, not used | n/a | n/a | n/a | n/a | — |

## L. Account / Login / Deletion Audit

- **Account creation:** Yes — email + password and Sign in with Apple (`AuthView`, `AuthViewModel`).
- **Login methods:** Email/password, Sign in with Apple. Sign in with Apple is **prominent and required** because third-party login is used (✅ compliant with 4.8).
- **Logout:** Yes (`SettingsSheet` → Sign Out → `AuthService.signOut`).
- **Password reset:** Yes (Supabase `resetPasswordForEmail`).
- **Email verification:** TODO in code. See Plan #8.
- **Account deletion:** Yes — in-app, two-tap confirmation in Settings (`SettingsSheet`). Calls `AuthService.deleteAccount` → Worker `delete-user` → per-table client DELETEs.
- **Gaps.** Apple Sign-In revoke not performed; partial-deletion risk; clear post-delete confirmation could be stronger. See Plan #9.
- **Reviewer access concerns.** Need demo credentials in App Store Connect Review Notes. See Plan #10.

## M. Subscription / IAP Audit

- **IAP detected.** Yes — auto-renewable monthly subscription `com.parlance.pro.monthly` ($9.99/mo) in `Parlance.storekit`.
- **Products / StoreKit flow.** `SubscriptionService.purchase` is correct: fetches product, calls `product.purchase()`, verifies, finishes transaction, refreshes entitlement.
- **Restore purchases.** Present in `PaywallView.restoreButton`.
- **Paywall compliance.** **Failing.** Missing Terms of Use link, missing Privacy Policy link, hardcoded `$9.99` fallback, advertised feature (Tone & Emotion Analysis) disabled in code. See Plans #2 and #4.
- **Subscription disclosure.** Period and renewal language present; subscription title missing in legal block.
- **External payment risk.** None — no external links anywhere in the paywall or unlock flow.
- **Debug-only bypass.** `isPro = true` in any DEBUG build — defensive change recommended (Plan #16).

## N. AI / Speech Coaching Audit

- **AI claims.** Auth tagline "Your AI speech coach." Paywall: "Parlance Pro — The full coaching experience. Nothing held back. Access levels 7–10 for elite coaching." Reasonable framing; no medical or therapeutic claims.
- **AI provider mismatch.** Privacy policy says "Claude AI (Anthropic)" but Worker calls Google Gemini. See Plan #5.
- **Speech coaching positioning.** Acceptable (practice + gamification). No diagnostic language in `FeedbackGenerator` prompt, though the prompt's "be rigorous" mode could benefit from an explicit "no clinical / diagnostic terminology" instruction (Plan #12).
- **Audio/transcript handling.**
  - Audio is recorded to `FileManager.default.temporaryDirectory`, transcribed via `Speech` framework (server-side fallback possible), then deleted by `SessionCoordinator.processSession`.
  - Transcript is sent to the Worker; the Worker forwards a prompt with the transcript to Gemini.
  - Audio file itself is never sent server-side today (Hume disabled). If re-enabled, audio uploads to Worker `/emotion` → Hume.
- **Safety disclaimers in-app.** Missing. Add at three surfaces — see Plan #12.
- **Data disclosure.** Privacy policy mentions AI processing but the third-party list is wrong (Plan #5).
- **Risky wording / recommended safer wording.**
  - "elite coaching" → fine; not a problem
  - "The full coaching experience. Nothing held back." → fine
  - "Audio analyzed by AI for emotion detection" → currently false. Remove or implement.
- **Backend / API disclosure gaps.** Worker route names (`/feedback`, `/emotion`, `/delete-user`) and provider chain should appear in Review Notes (Plan #10).

## O. Metadata / App Store Connect Checklist

Verify each manually in App Store Connect before submission:

- [ ] App name — "Parlance"
- [ ] Subtitle — ≤ 30 chars, recommended: "AI practice for public speaking"
- [ ] Keywords — `speech,coach,public speaking,interview,pitch,AI,toastmasters,presentation,vocabulary,confidence` (under 100 chars)
- [ ] Description — 3–4 paragraphs, practice-only framing
- [ ] Promotional text — 170 chars
- [ ] Screenshots — 6.7"/6.9" required; 5.5" optional; iPad 12.9"/13" if iPad enabled
- [ ] Preview video — optional, recommended
- [ ] Support URL — `https://theparlance.app/support` (200 OK ✅)
- [ ] Marketing URL — `https://theparlance.app` (verify)
- [ ] Privacy Policy URL — `https://theparlance.app/privacy` (200 OK ✅, but **content must be rewritten** per Plan #5)
- [ ] Review Notes — see section P below
- [ ] Demo account — required (placeholder in Review Notes)
- [ ] Age rating — recommended 12+ (Infrequent/Mild Mature Themes via user-generated UGC potential, Infrequent/Mild Profanity if not filtered)
- [ ] Privacy Nutrition Label — must align with rewritten privacy policy
- [ ] Category — Education (primary), Lifestyle (secondary optional)
- [ ] Pricing / availability — confirm subscription regions
- [ ] IAP metadata — `com.parlance.pro.monthly`: title, description, EULA selection, review screenshot
- [ ] Subscription group — "Pro"
- [ ] Encryption (`ITSAppUsesNonExemptEncryption = NO`) — already set; confirm it remains true (HTTPS-only use is exempt)
- [ ] Sign in with Apple capability — confirmed
- [ ] Push Notifications capability — confirmed; verify production APNs key (Plan #7)

## P. Recommended App Review Notes

(Ready-to-paste draft. Replace placeholder credentials before submission.)

> **Parlance — AI Speech Coach**
>
> Parlance is a public-speaking practice app. Users pick a mode (Interview / Pitch / Keynote / Daily Convo), receive a question, record themselves answering, and get AI-generated practice feedback. All AI feedback is framed as practice, not professional coaching, therapy, or medical advice.
>
> **How to test the main flow:**
> 1. Sign in. The fastest path is "Sign in with Apple." A demo email account is also provided below.
> 2. Complete the brief profile setup (name + comfort level).
> 3. From the Home tab, tap any practice mode (e.g. "Interview").
> 4. The app shows a question, runs a 3-2-1 countdown, then prompts for Microphone and Speech Recognition permission. Please grant both.
> 5. Speak for at least 5 seconds (you can speak up to 3 minutes). Tap the red square to finish.
> 6. The app uploads the transcript (not the audio file) to our backend over HTTPS for AI feedback generation. The audio file is deleted from the device immediately after transcription.
> 7. The Results screen shows an overall score, AI coaching paragraph, best/worst moment, and metric breakdown.
>
> **Demo account (placeholder — replace before submission):**
> Email: `reviewer@parlance.app`
> Password: `Parlance-Reviewer-2026!`
>
> **How to test the subscription:**
> Profile → Settings → "Upgrade to Pro." Product is `com.parlance.pro.monthly` at $9.99/month. Pro unlocks levels 7–10 and additional practice modes. "Restore purchases" is in the same paywall.
>
> **How to test account deletion:**
> Profile → Settings → "Delete Account" → confirm. The auth user, all profile data, all session scores, friendships, push tokens, and user stats are deleted server-side. For Sign in with Apple users, Apple's revoke endpoint is called server-side.
>
> **Privacy notes for reviewers:**
> - Audio is recorded on device; only the transcript is sent to our AI provider for coaching feedback. The audio file is deleted after processing.
> - We use Sign in with Apple and email/password. Sign in with Apple revokes are honored on account deletion.
> - The social layer (League → Friends) includes Report and Block on every user profile and on incoming friend requests. Display names and usernames are screened with a profanity filter at submit.
>
> **Known reviewer concerns proactively addressed:**
> - The app requires an account because AI feedback depends on per-user state (XP, streaks, history). A short profile setup follows sign-up.
> - No payment is required to use the core practice loop on free modes and levels 1–6.
> - All AI claims are framed as practice. No medical or therapeutic claims are made.
>
> Backend endpoints: `https://parlance-api.parlance-app.workers.dev/{feedback, emotion, delete-user}`. All require Bearer tokens (Supabase JWT) where applicable.
>
> Contact: `parlance.app@gmail.com`

## Q. Security Findings

| Concern | Detail | Severity | Plan |
|---|---|---|---|
| Hardcoded Supabase anon key | Embedded in source and `Info.plist`. Public by design (anon JWT). Safe IF RLS is enforced everywhere. | Low if RLS is correct | #18, #19 |
| Hardcoded TelemetryDeck App ID | Public client ID, safe to commit. | Low | — |
| Worker `*` CORS + no auth on `/feedback`, `/emotion` | Anyone on the public internet can drive Gemini/Hume calls through the Worker. | Medium (cost abuse) | #14 |
| `aps-environment = development` in Release | Push silently broken in App Store build. | Medium | #7 |
| Sensitive logs | All `print(...)` are wrapped in `#if DEBUG`. No release logging of transcripts or audio. | Low | — |
| Insecure local storage | Local SwiftData store contains transcripts and scores. Not encrypted at rest beyond iOS data-protection class. | Low (iOS default is reasonable) | — |
| HTTP / ATS exceptions | All endpoints are HTTPS; no ATS exceptions found. | Low | — |
| Service-role key | Only in Worker `env`, never in client. | Low (correct) | — |
| Debug flags shipping | `SubscriptionService` DEBUG bypass is gated by `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG"` which is Debug-config only; Release is correctly gated. | Low (defensive guard recommended in #16) | #16 |
| `get-task-allow` | Set to `true` in build folder. Xcode auto-toggles this during App Store distribution archive, but Plan #7 also rebuilds entitlements cleanly. | Low (Xcode-managed) | #7 |
| `questions.json.bak` in repo | Stale 2.5MB backup file next to the live questions file. | Low | #21 |

## R. Accessibility / HIG Findings

- **VoiceOver.** Recording button has a label ("Start/Stop recording"). Many icon-only buttons in Profile/League/Home lack `accessibilityLabel`. Recommend a pass — Plan #15.
- **Dynamic Type.** No documented audit. Some `Spacer().frame(height: 60)` and fixed-height bars in `Home`/`Profile` will clip at Accessibility XXXL.
- **Contrast.** Gold-on-card-light combos may not meet WCAG AA for body text. Body usage is mostly correct (gold used for emphasis, not body), but verify on the Auth screen and Results verdicts.
- **Tap targets.** `AppConstants.IconButton.hitTarget = 44` is used in several places — good.
- **Destructive actions.** Reset / Delete Account / Sign Out / End Session all have explicit confirmation dialogs — good.
- **Native UX.** No misleading system-style UI; the gold palette is custom and clearly Parlance-branded.

## S. Build / Release Configuration Findings

- **Schemes / targets.** `Parlance` (app), `ParlanceTests` (unit), `ParlanceUITests` (UI). Looks clean.
- **Release configuration concerns.**
  - Same entitlements file for Debug and Release (Plan #7).
  - Custom `INFOPLIST_KEY_*` keys for the Worker URL, Supabase URL, and Supabase anon key. The Supabase keys are redundant with the hardcoded values in `SupabaseManager.swift` (Plan #18).
  - `SWIFT_COMPILATION_MODE = wholemodule` for Release ✅
  - `VALIDATE_PRODUCT = YES` for Release ✅
  - `ITSAppUsesNonExemptEncryption = NO` for Release ✅
  - Deployment target iOS 18.0 — reasonable but excludes older devices.
- **Signing / provisioning.** Automatic. Bundle ID `org.Parlance` is unusual but valid; finalize before first submission (Plan #18).
- **Debug / staging artifact concerns.** `SubscriptionService` DEBUG `isPro = true` bypass — verified to NOT ship in Release (Plan #16 is defensive).
- **Build / test limitations during this review.** No simulator was launched; no `xcodebuild` was run that would mutate files. All findings are from static analysis and verified URL `curl` checks.

## T. Manual Review Items

These cannot be verified from repo and require human action:
- App Store Connect product, subscription, EULA, screenshots, demo account, privacy answers
- Bundle ID final decision (permanent after first submission)
- Privacy policy rewrite (lives on the marketing site)
- Terms of Service (publish or opt into Apple's standard EULA)
- Supabase RLS enforcement audit
- iPad strategy (iPhone-only vs invest in real iPad UI)
- Email confirmation policy (Supabase Auth setting)
- Apple Services ID + P8 key for server-side Apple revoke
- Push notification production APNs key
- Privacy policy / Terms / Support URL hosting

## U. Recommended Pre-Submission Checklist

### Code / app behavior
- [ ] `PrivacyInfo.xcprivacy` added and bundled (Plan #6)
- [ ] Release entitlements file uses `aps-environment = production` (Plan #7)
- [ ] UGC Report and Block flows shipped (Plan #1)
- [ ] Profanity filter on `displayName`, `username`, `location`, `occupation` (Plan #1)
- [ ] Paywall has Terms of Use and Privacy Policy links (Plan #2)
- [ ] All "on-device" copy rewritten to match actual behavior, OR `requiresOnDeviceRecognition = true` set + AI feedback removed (Plan #3)
- [ ] "Tone & Emotion Analysis" bullet either removed or feature shipped (Plan #4)
- [ ] AI practice-only disclaimers added at three surfaces (Plan #12)
- [ ] Speech-denied alert rewritten (Plan #13)
- [ ] Subscription DEBUG bypass tightened (Plan #16)
- [ ] Bundle ID finalized (Plan #18)
- [ ] `questions.json.bak` and `ParlanceApp/build/` removed from repo (Plan #21)
- [ ] Paywall product price loaded from StoreKit; no hardcoded fallback shown to users (Plan #23)

### Privacy / legal
- [ ] Privacy policy rewritten and live (Plan #5)
- [ ] Terms of Service published OR Apple Standard EULA selected (Plan #2)
- [ ] Sign in with Apple revoke implemented in Worker (Plan #9)
- [ ] App Store privacy answers aligned with policy (Plan #10)

### App Store Connect
- [ ] All metadata fields filled (Plan #10)
- [ ] Screenshots produced for chosen device families
- [ ] Demo account works
- [ ] Review Notes pasted (section P)
- [ ] In-app purchase localized, has review screenshot, EULA selected

### IAP / subscriptions
- [ ] Restore Purchases tested end-to-end on a fresh install (Plan #14 + sandbox)
- [ ] Cancelled / pending / failed purchase paths tested
- [ ] Subscription group correctly configured

### Account deletion
- [ ] Email user deletion verified (all rows gone)
- [ ] Apple user deletion verified — Apple ID Settings removes the app (Plan #9)
- [ ] Deletion works under poor network (Plan #9)

### AI / speech / audio
- [ ] Microphone denial path tested
- [ ] Speech Recognition denial path tested (Plan #13)
- [ ] AI service failure path tested (local fallback present in `SessionCoordinator.scoreAndSave`)
- [ ] AI prompt does not produce clinical language across 10 sessions (Plan #12)

### QA / device testing
- [ ] iPhone SE → 16 Pro Max physical / simulator pass
- [ ] iPad pass if iPad shipped; otherwise device family = `1` (Plan #11)
- [ ] VoiceOver pass on core loop (Plan #15)
- [ ] Dynamic Type Accessibility XXXL pass (Plan #15)
- [ ] Light and Dark mode pass
- [ ] Airplane mode pass (graceful failure on AI scoring)

### Metadata / screenshots
- [ ] All marketing assets render at small sizes
- [ ] App icon does not look like a system app
- [ ] Launch screen is just the background color, no text

## V. Confidence Scores (1–10)

- App Store approval readiness: **3 / 10** — would fail first review on Plans 1, 2, 3, 4, 5, 6 as listed
- Crash / bug readiness: **8 / 10** — no obvious crashes; persistence has a wipe-and-recreate path; transcription has a 30 s timeout; AI failure falls back to local scoring
- Privacy compliance readiness: **3 / 10** — manifest missing, multiple inaccurate user-facing claims
- Metadata readiness: **2 / 10** — App Store Connect metadata, Privacy Nutrition Labels, Review Notes all need work
- IAP / subscription readiness: **5 / 10** — StoreKit code is good; paywall disclosures and one fictitious bullet must be fixed
- Account deletion readiness: **6 / 10** — flow exists; Apple revoke and server orchestration missing
- AI / speech / audio readiness: **6 / 10** — pipeline works; on-device claims false; disclaimers missing
- Build / release readiness: **5 / 10** — Release entitlements wrong; manifest missing; otherwise clean

## W. Analysis Limitations

The following could not be verified from repo / static analysis alone:
- App Store Connect metadata (description, keywords, screenshots, age rating answers, demo account, Privacy Nutrition Labels, IAP localization)
- Real backend behavior under production load
- The actual content of the privacy policy and absence of `/terms` are verified via `curl` against `https://theparlance.app/...` from the developer machine
- Whether the Cloudflare Worker production deployment uses the same `index.js` checked into the repo
- Whether Hume API credentials are configured in the Worker (would matter if Plan #4 chooses to ship Hume)
- Supabase RLS policy enforcement on each table
- Apple revoke endpoint behavior (no Apple refresh token captured in current code)
- Real-device permission dialogs, push delivery, and StoreKit purchase under sandbox
- App icon and launch screen image content
- App Store Connect app record state and bundle-ID registration
- Whether the team has uploaded a production APNs Auth Key

---

**End of mock review.** The single consolidated action list is `_docs/plans/APP_REVIEW_PLAN_consolidated.md`. Close items 1–6 (Blockers) and 7–11 (High Priority) before pressing Submit for Review.
