# App Store Mock Review: Production Submission Readiness

_Mock review conducted 2026-05-11. Analysis-only — no production code, configuration, or assets were modified. Plan files for every recommended action live under `_docs/plans/APP_REVIEW_PLAN_*.md`._

---

## A. Executive Summary

Parlance is an iOS speech-coaching app (SwiftUI, iOS 18 deployment target, SwiftData persistence, Supabase backend, Cloudflare Worker proxy to Google Gemini for AI feedback, Apple Speech Recognition for transcription, Sign in with Apple + email/password auth, monthly auto-renewing subscription `com.parlance.pro.monthly`, friends/leaderboards UGC). Codebase is in good shape overall — account deletion is implemented end-to-end (including Apple token revoke), block/report exist, permissions copy is honest, and a profanity / scenario denylist is in place.

However, **the app is not ready to submit today**. The most serious issue is a paywall that advertises a feature ("Tone & Emotion Analysis") whose code path has been disabled in production — paying users would not receive that benefit. There are also two paywall compliance gaps (no on-screen Terms/Privacy links, hardcoded "$9.99/month" fallback that could mismatch a non-USD storefront), an over-declared `CoarseLocation` data type in the privacy manifest, and an explicit TODO that bypasses email verification at sign-up. Once those are fixed and an App Review demo account + notes are prepared, the app should clear review.

- **Production code changes made by this review:** none. This was strictly analysis-only.
- **Number of `APP_REVIEW_PLAN_*.md` files created:** 17, listed in Section E.

## B. Final Verdict

**NOT READY: HIGH REJECTION RISK**

The single highest-risk item is the paywall promising the Tone & Emotion Analysis feature while the Hume call site in `SessionCoordinator.swift` is commented out. This is a guideline 3.1.2(a) / 2.3.1 rejection waiting to happen. The other Blockers/High items are routine but each is a known rejection trigger for AI + subscription apps. With the items in Sections F and G addressed, the app's verdict would move to **READY AFTER MINOR FIXES**.

## C. Reviewer Simulation Result

A reviewer launching a fresh build will:

1. Land on `AuthView`. The "Sign in with Apple" button is prominent and at parity with email/password. Privacy and Support links are visible.
2. Without a demo account, the reviewer is **forced to create an account** (currently no email verification — they would sign up with any address and proceed). Apple expects demo credentials in App Review Notes; the repo contains no such notes draft. **Blocked review path unless demo credentials are provided in App Store Connect.**
3. After sign-up, the reviewer reaches `FirstLaunchSetupView` and then the Home tab. The four practice modes are present.
4. Tapping a mode triggers microphone + speech recognition pre-prompts with specific purpose strings and an "audio is deleted, only transcript is sent" explanation.
5. Completing a recording calls the Cloudflare Worker `/feedback` endpoint which proxies to Google Gemini. **If the worker is paused or the Gemini key is misconfigured at review time, the app falls back to local heuristic scoring (`FeedbackGenerator.localScoringResult`) — so the reviewer always sees a results screen, even on backend failure.** This is a good defensive design and reduces the chance of a "core feature broken at review" rejection.
6. Opening the paywall via `Profile → Upgrade to Pro` shows four bullet benefits including the disabled tone analysis feature → rejection trigger.
7. Profile → Settings → Delete Account works (calls `/delete-user`, revokes Apple identity on the worker side, wipes local data).

Reviewer concerns that emerge:
- **No on-paywall Terms of Use / Privacy Policy link.** Apple requires this for auto-renewing subscriptions.
- **Paywall price/period strings are hardcoded.** A non-USD storefront would see "$9.99" before the StoreKit product loads.
- **Backend health.** Worker is a critical dependency for the AI scoring; reviewers will retry on failure. The 30s scoring timeout + local fallback mitigates this.

## D. Guideline Risk Matrix

| Area | Risk | Notes |
|---|---|---|
| Safety | LOW | Disclaimers ("not therapy/medical advice") visible in Setup, Sample preview, Results, Settings. Slurs denylist + Real Life pre-flight filter exist. |
| Performance | LOW | Fallback paths for transcription, scoring, and emotion analysis. Permission denial UX handled. |
| Business / IAP | **HIGH (BLOCKER)** | Paywall advertises a disabled feature; missing Terms/Privacy links on paywall; hardcoded price. |
| Design | MEDIUM | iPad target enabled but locked to portrait + full-screen-only. Hardcoded English strings on paywall. |
| Legal | MEDIUM | Privacy Policy must accurately disclose Google Gemini, Apple Speech, Supabase, Cloudflare. Cannot verify external Privacy Policy from repo. |
| Privacy | **HIGH** | Privacy manifest over-declares `CoarseLocation` (no CoreLocation usage in codebase). Required Reason API declarations likely incomplete. |
| Account deletion | LOW | In-app deletion present and reachable. SIWA revoke handled server-side. |
| AI / speech / audio | MEDIUM | Audio kept on-device; only transcript sent; honest mic copy. Generic "our AI provider" wording should name Google. |
| Metadata consistency | **HIGH** | Paywall copy vs feature reality, App Store Connect privacy answers vs actual data flows, age-rating UGC questions. |
| Technical build readiness | LOW | Release config is clean. UI-test hooks gated by `#if DEBUG`. Verify archive uses Release. |
| Accessibility | LOW–MEDIUM | Mic button has VO label; broader VO + Dynamic Type pass recommended. |

## E. App Review Plans Created

All under `_docs/plans/`. Plans must be considered before submission.

| # | Filename | Issue | Status | Risk | Human Review? |
|---|---|---|---|---|---|
| 1 | `APP_REVIEW_PLAN_paywall_tone_analysis_advertised_but_disabled.md` | Paywall lists Tone & Emotion Analysis but Hume call site and ToneAnalysisCard are commented out | Blocker | Blocker | Product decision |
| 2 | `APP_REVIEW_PLAN_paywall_missing_terms_and_privacy_links.md` | Auto-renew paywall lacks Terms/Privacy links on the same screen | Blocker | Blocker | No |
| 3 | `APP_REVIEW_PLAN_paywall_hardcoded_price_and_period.md` | "$9.99" and "per month" hardcoded fallbacks | High Priority | High | No |
| 4 | `APP_REVIEW_PLAN_privacy_manifest_coarse_location_misdeclared.md` | `NSPrivacyCollectedDataTypeCoarseLocation` declared without CoreLocation use | High Priority | High | No |
| 5 | `APP_REVIEW_PLAN_privacy_policy_ai_providers_disclosure.md` | Privacy Policy must name Google Gemini, Apple Speech, Supabase, Cloudflare | Deferred: Human Review Required | High | Yes (legal) |
| 6 | `APP_REVIEW_PLAN_app_review_notes_and_demo_account.md` | App Review Notes + demo account not prepared | High Priority | High | Yes (App Store Connect) |
| 7 | `APP_REVIEW_PLAN_email_verification_unenforced.md` | Email/password sign-up bypasses verification (TODO in code) | High Priority | High | Yes (Supabase config) |
| 8 | `APP_REVIEW_PLAN_age_rating_ugc_and_moderation.md` | Set 17+ rating with UGC sub-answers; document report SLA in app | High Priority | High | Yes (App Store Connect + ops) |
| 9 | `APP_REVIEW_PLAN_required_reason_api_audit.md` | Privacy manifest only declares UserDefaults; audit other RR-APIs | High Priority | High | No |
| 10 | `APP_REVIEW_PLAN_about_your_data_specificity.md` | Generic "our AI" copy should name Google Gemini | Recommended | Low–Medium | No |
| 11 | `APP_REVIEW_PLAN_dead_hume_code_and_emotion_model.md` | Remove dead Hume integration after Option A on Plan #1 | Recommended | Low | Coupled to Plan #1 |
| 12 | `APP_REVIEW_PLAN_signout_wipes_local_data.md` | Sign Out destroys local transcripts without warning | Recommended | Low | No |
| 13 | `APP_REVIEW_PLAN_ipad_full_screen_and_orientation.md` | iPad target enabled but portrait/full-screen-only | Recommended | Low–Medium | Yes (product) |
| 14 | `APP_REVIEW_PLAN_bundle_id_form.md` | `org.Parlance` non-standard form, locked at first submission | Recommended | Low | Yes (irreversible after launch) |
| 15 | `APP_REVIEW_PLAN_accessibility_pass_vo_dynamic_type.md` | VoiceOver/Dynamic Type/contrast audit needed | Recommended | Low | No |
| 16 | `APP_REVIEW_PLAN_storekit_test_file_in_release.md` | Confirm `Parlance.storekit` not in Copy Bundle Resources | Recommended | Low | No |
| 17 | `APP_REVIEW_PLAN_ui_test_seed_arg_in_release.md` | Verify `--ui-test-seed-pro` hooks excluded from Release archive | Recommended | Low | No |

## F. Blocking Issues

### F1. Paywall advertises Tone & Emotion Analysis but feature is disabled
- **Why Apple may reject:** Guideline 3.1.2(a) — IAP must deliver advertised value. Guideline 2.3.1 — accuracy of metadata. Paying users would not receive the headline benefit "🎙️ Tone & Emotion Analysis".
- **Evidence:** `Features/Paywall/PaywallView.swift:20` (benefit row); `Features/Session/SessionCoordinator.swift:188-193` (Hume call commented out, `emotionResult = nil` forced); `Features/Results/ResultsView.swift:123-125` (ToneAnalysisCard render commented out).
- **Recommended fix:** Either remove the benefit row (Option A) or re-enable Hume end-to-end with privacy disclosure (Option B).
- **Plan:** `APP_REVIEW_PLAN_paywall_tone_analysis_advertised_but_disabled.md`.

### F2. Paywall lacks Terms of Use / Privacy Policy links
- **Why Apple may reject:** Guideline 3.1.2 — auto-renew subscriptions must surface Terms/Privacy links on the purchase screen.
- **Evidence:** `Features/Paywall/PaywallView.swift:157-163` (`legalText`) — no `Link(...)` to terms or privacy.
- **Recommended fix:** Add two `Link` views beneath the renewal blurb. Pull price + period from StoreKit `Product`.
- **Plan:** `APP_REVIEW_PLAN_paywall_missing_terms_and_privacy_links.md`.

## G. High-Risk Issues

### G1. Paywall hardcodes "$9.99" and "per month"
- **Risk:** Non-USD storefronts see USD price; period misrepresented if SKU changes.
- **Evidence:** `Features/Paywall/PaywallView.swift:112, 115, 129`.
- **Fix:** Defer rendering until `Product` loads; derive period from `Product.subscription?.subscriptionPeriod`.
- **Plan:** `APP_REVIEW_PLAN_paywall_hardcoded_price_and_period.md`.

### G2. Privacy manifest over-declares CoarseLocation
- **Risk:** Apple flags privacy-manifest claims that do not match the binary. Implies geolocation collection that the app does not perform.
- **Evidence:** `ParlanceApp/PrivacyInfo.xcprivacy:48-58`; no `import CoreLocation` anywhere; `User.location` is a typed text field.
- **Fix:** Remove the `CoarseLocation` block. Keep location text under `OtherUserContent`.
- **Plan:** `APP_REVIEW_PLAN_privacy_manifest_coarse_location_misdeclared.md`.

### G3. Privacy Policy must name third-party processors
- **Risk:** Production traffic goes to Google Gemini (not "our AI provider"). Apple Speech, Cloudflare Workers, and Supabase are also processors. The Privacy Policy at https://theparlance.app/privacy must list each.
- **Evidence:** `cloudflare-worker/src/index.js:300-369` (Gemini proxy); `Features/Profile/SettingsSheet.swift:147` (generic copy).
- **Fix:** Update hosted Privacy Policy + App Store Privacy answers + in-app disclosures to name processors.
- **Plan:** `APP_REVIEW_PLAN_privacy_policy_ai_providers_disclosure.md`.

### G4. App Review Notes + demo account not prepared
- **Risk:** App gates substantial functionality behind sign-up. Without demo credentials and review notes, the reviewer cannot exercise the app.
- **Evidence:** `App/ContentView.swift:46-56` — auth-gated; no notes file in repo.
- **Fix:** Provision a Supabase demo user, seed history, paste the draft notes (see Section P) into App Store Connect → App Review Information.
- **Plan:** `APP_REVIEW_PLAN_app_review_notes_and_demo_account.md`.

### G5. Email/password sign-up does not require verification
- **Risk:** Anyone can create an account with any address. Combined with public leaderboards + friend search, opens an impersonation/abuse vector.
- **Evidence:** `Core/Services/AuthService.swift:86-90` (explicit "TODO before production" comment).
- **Fix:** Enable Supabase `Confirm email`, add a "Check your inbox" UI state, handle the deep-link return.
- **Plan:** `APP_REVIEW_PLAN_email_verification_unenforced.md`.

### G6. Age rating + UGC sub-question answers
- **Risk:** Misanswered age rating questionnaire is a common rejection cause for apps with leaderboards + user-generated text.
- **Evidence:** Profile fields, leaderboards, Real Life scenarios are all UGC surfaces. No in-app SLA disclosure for reports.
- **Fix:** Answer the questionnaire honestly (likely 17+ with UGC). Publish Community Guidelines. Add report-response SLA copy in the report sheet.
- **Plan:** `APP_REVIEW_PLAN_age_rating_ugc_and_moderation.md`.

### G7. Required Reason API audit
- **Risk:** Apple's automated submission scanner rejects builds with undeclared Required Reason APIs. Manifest currently only declares UserDefaults.
- **Evidence:** `ParlanceApp/PrivacyInfo.xcprivacy:84-94`; file timestamp APIs likely used in `AudioRecorder`.
- **Fix:** Grep the codebase per category, add declarations.
- **Plan:** `APP_REVIEW_PLAN_required_reason_api_audit.md`.

## H. Medium / Low-Risk Observations

- **`Core/AI/ClaudeClient.swift` is misnamed.** The worker proxies to Google Gemini, not Anthropic Claude. Internal-only cosmetic issue; no App Review impact.
- **Sign Out wipes local SwiftData** (`Features/Profile/SettingsSheet.swift:181-191`). Surprises users who switch accounts. Plan: `APP_REVIEW_PLAN_signout_wipes_local_data.md`.
- **iPad target enabled but locked to portrait/full-screen.** Drop iPad or commit to a proper iPad pass. Plan: `APP_REVIEW_PLAN_ipad_full_screen_and_orientation.md`.
- **Bundle ID `org.Parlance`** is unusual form. Decide now — locked at first submission. Plan: `APP_REVIEW_PLAN_bundle_id_form.md`.
- **Accessibility audit** (VoiceOver labels on mic ring, Dynamic Type at Accessibility5, contrast on gold-on-card). Plan: `APP_REVIEW_PLAN_accessibility_pass_vo_dynamic_type.md`.
- **`Parlance.storekit`** at repo root — verify not in Copy Bundle Resources. Plan: `APP_REVIEW_PLAN_storekit_test_file_in_release.md`.
- **UI-test seed args (`--ui-test-seed-pro`, `_uiTestSeedPro()`, `PARLANCE_PRO_OVERRIDE`)** are `#if DEBUG`-gated. Verify Release archive excludes them. Plan: `APP_REVIEW_PLAN_ui_test_seed_arg_in_release.md`.
- **Dead Hume code paths** should be removed (or feature-flagged) if Option A is chosen for the paywall plan. Plan: `APP_REVIEW_PLAN_dead_hume_code_and_emotion_model.md`.
- **In-app data disclosure copy** is honest but generic. Naming Google Gemini specifically would strengthen the disclosure. Plan: `APP_REVIEW_PLAN_about_your_data_specificity.md`.
- **Supabase anon key is intentionally embedded.** This is the standard pattern; not a secret. Comment in `SupabaseManager.swift:5-6` documents it.
- **No third-party tracking SDKs detected.** `NSPrivacyTracking` is correctly `false`.
- **`ITSAppUsesNonExemptEncryption = NO`** declared via Info.plist — correct, the app does not use proprietary encryption beyond HTTPS.
- **Cloudflare Worker** enforces rate limiting + JWT verification + body-size caps + scenario sanitization (XML-tag wrapping with anti-injection instructions). Defensive backend.
- **Account deletion** revokes the SIWA refresh token server-side (`cloudflare-worker/src/index.js:133-185`) — required by 5.1.1(v). Implemented correctly.
- **Reset All Data** in Settings is non-destructive at the server level — only wipes the local SwiftData store. Helpful for testing but reviewers may not understand it; consider hiding behind a `#if DEBUG` flag in production, or document it in App Review Notes.

## I. Privacy and Data Collection Audit

| Data | Source | Stored? | Sent off-device? | Linked to user? | Tracking? | Privacy label | Risk |
|---|---|---|---|---|---|---|---|
| Email | `AuthView` sign-up + SIWA | Supabase `auth.users` | Yes (Supabase) | Yes | No | Declared (`Email`) | Low |
| User ID (Supabase UUID) | Supabase | Server + local | Yes | Yes | No | Declared (`UserID`) | Low |
| Display name | `ProfileEditSheet` | Server + local | Yes | Yes | No | Declared (`Name`) | Low |
| Username | `ProfileEditSheet` | Server + local | Yes | Yes | No | Declared (`OtherUserContent`) | Low |
| Self-reported city ("location") | `ProfileEditSheet` text field | Server + local | Yes | Yes | No | **Mis**-declared as `CoarseLocation` | **High — fix manifest** |
| Occupation | `ProfileEditSheet` | Server + local | Yes | Yes | No | `OtherUserContent` | Low |
| Avatar emoji or photo | `ProfileEditSheet`, `ImageCropSheet` | Local; photo encoded in `profileImageData` | Profile photo currently local-only (verify Supabase upload pipeline) | Yes | No | `Photos or Videos` if uploaded; `OtherUserContent` otherwise | Verify whether photo syncs to server |
| Audio recording (raw m4a) | `AudioRecorder` | Temp file, deleted post-transcription | **No** (Hume disabled) | Would be Yes if re-enabled | No | Audio Data if re-enabled | OK while disabled; high if Option B chosen |
| Speech transcript | `SpeechTranscriber` | Local SwiftData | Yes (sent to Gemini for scoring) | Yes (via auth header) | No | `OtherUserContent` | Medium (depends on Privacy Policy specifics) |
| Real Life scenario text (free-form) | `RealLifeSetupView` | Local recent-scenario history; sent to `/real-life/tips` | Yes (to Gemini via worker) | Yes | No | `OtherUserContent` | Medium |
| AI feedback paragraph | Worker response | Local SwiftData | Generated server-side; stored locally | Yes | No | `OtherUserContent` | Low |
| Filler/pace/clarity/structure/vocabulary scores | `SpeechAnalyzer` + AI | Local; aggregate avg synced to `user_stats` and per-session score row to `session_scores` | Yes | Yes | No | `ProductInteraction` | Low |
| XP / level / streak | `GamificationService` | Local + `user_stats` | Yes | Yes | No | `ProductInteraction` | Low |
| Push token (APNs hex) | `AppDelegate.didRegister` → `PushTokenService` | `push_tokens` table | Yes | Yes | No | `DeviceID` — **not currently declared** | Medium — consider adding to manifest |
| Daily reminder preference | `ProfileViewModel.toggleDailyReminder` | Local + synced to `profiles.daily_reminder_enabled` | Yes | Yes | No | `ProductInteraction` | Low |
| Sound effects preference | UserDefaults | Local only | No | n/a | No | n/a | Low |
| Friend relationships | `SocialService` | `friend_requests`, `friends` | Yes | Yes | No | `OtherUserContent` | Low |
| Block / report records | `SocialService` | `blocked_users`, `user_reports` | Yes | Yes | No | `OtherUserContent` / `CustomerSupport` | Low |
| Auth tokens | Supabase SDK | Keychain via Supabase Auth | Yes (to backend) | Yes | No | n/a | Low |
| Crash logs | Not collected by app | n/a | n/a | n/a | n/a | n/a | None |
| Analytics | Not integrated | n/a | n/a | n/a | n/a | n/a | None — none detected |

## J. Privacy Manifest / Required Reason API Audit

- **Existing manifest:** `ParlanceApp/PrivacyInfo.xcprivacy` — declares Email, UserID, Name, CoarseLocation (incorrect), OtherUserContent, ProductInteraction; UserDefaults Required Reason `CA92.1`.
- **Issues:**
  - `CoarseLocation` should be removed (no CoreLocation usage). See Plan #4.
  - Push token (`DeviceID`) is collected and stored on the server but **not declared**. Consider adding `NSPrivacyCollectedDataTypeDeviceID`.
  - Only one Required Reason API is declared (UserDefaults). Other categories may be triggered by `AudioRecorder` (temp file timestamps) or `TimingStats` (system uptime). See Plan #9 for full audit.
  - The Supabase Swift SDK ships its own privacy manifest as of supabase-swift 2.x — confirm the dependency version includes it.
- **Tracking domains:** `NSPrivacyTrackingDomains` is empty and `NSPrivacyTracking = false`. Correct, given no advertising/tracking SDKs.
- **Recommended steps:** see plans #4, #9.

## K. Permissions Audit

| Permission | Purpose string | Needed? | Prompt timing | Denial handling | Risk |
|---|---|---|---|---|---|
| Microphone (`NSMicrophoneUsageDescription`) | "Parlance needs your microphone to record your practice sessions." | Yes (core feature) | At first record tap, after pre-prompt explaining audio handling | "Open Settings" alert; recording disabled | Pass — purpose string is specific and honest |
| Speech recognition (`NSSpeechRecognitionUsageDescription`) | "Parlance uses speech recognition to transcribe your practice sessions and analyze your speaking performance." | Yes | At first record tap, after pre-prompt | "Open Settings" alert; recording cannot proceed | Pass |
| User notifications | Not pre-declared in Info.plist (uses runtime `UNUserNotificationCenter.requestAuthorization`) | Optional (daily reminder + remote pushes) | Only when user toggles Daily Reminder on | Toggle reverts if denied | Pass |
| Photo library (read) | None declared; PhotosPicker uses `PHPickerViewController` which does not require usage description | Yes (avatar upload) | When user opens picker | System UX | Pass — PHPicker doesn't need NSPhotoLibraryUsageDescription |
| Camera | Not used | n/a | n/a | n/a | n/a |
| Location | Not used | n/a (despite manifest entry) | n/a | n/a | Manifest declaration is wrong; see Plan #4 |
| Contacts/Calendars/Reminders/Bluetooth/Motion/FaceID/Tracking | Not used | n/a | n/a | n/a | n/a |

## L. Account / Login / Deletion Audit

- **Account creation:** present (`AuthView` → `signUp` → `AuthProfileSetupView` → `FirstLaunchSetupView` → home).
- **Login methods:** Email/password + Sign in with Apple. Apple is prominently placed at the top of the auth screen (correct ordering per HIG).
- **Sign in with Apple parity:** Apple button is present alongside email/password, of comparable prominence. No third-party social logins are used, so SIWA parity rule is satisfied trivially.
- **Logout:** present in Settings; **wipes local SwiftData** — see Plan #12.
- **Account deletion:** present in Settings as a destructive button with a confirmation alert. Calls `/delete-user` on the worker. The worker:
  - Verifies the user's Supabase JWT.
  - Looks up Apple identity and calls `https://appleid.apple.com/auth/revoke` with the user's refresh token (if available).
  - Deletes per-table rows.
  - Deletes the Supabase auth user.
  - Returns `{ success: true, appleRevoked: <bool> }`.
  - **5.1.1(v) compliance:** SIWA revoke is implemented. Note: revoke is best-effort; if the refresh token is missing the worker logs a warning and continues. Apple does not currently require revoke to succeed, only to be attempted.
- **Reviewer access concerns:** demo account + notes not yet in App Store Connect — see Plan #6.
- **Email verification:** not enforced — see Plan #7.

## M. Subscription / IAP Audit

- **Product ID:** `com.parlance.pro.monthly` (StoreKit configuration file present in repo for local testing).
- **Type:** Auto-renewing monthly subscription.
- **Group:** `parlance_pro_group`.
- **Restore Purchases:** present on paywall (`PaywallView.restoreButton`). Calls `AppStore.sync()` then `refreshStatus()`. Correct.
- **Transaction verification:** `SubscriptionService.checkVerified` throws on `.unverified` — correct.
- **Listener:** `Transaction.updates` is consumed in the singleton's task — correct.
- **Currentitlement detection:** `Transaction.currentEntitlements` iterated, gated on `productID == proProductID` and `revocationDate == nil` — correct.
- **Paywall compliance gaps:** missing Terms/Privacy links (Plan #2), hardcoded price/period (Plan #3), advertises disabled feature (Plan #1).
- **Free trial / introductory offer:** none configured. If added later, the paywall must disclose the trial length, post-trial price, and renewal terms.
- **External purchase risk:** none detected. No external billing links. No paywall avoidance UI.

## N. AI / Speech Coaching Audit

- **AI claims:** the app uses cautious framing throughout. Disclaimers appear in:
  - `Features/Setup/FirstLaunchSetupView.swift:168` — "AI feedback is for practice. Not professional coaching, therapy, or medical advice."
  - `Features/Auth/AuthProfileSetupView.swift:263` — same.
  - `Features/Auth/SamplePreviewView.swift:138` — "Practice feedback only — not professional coaching or medical advice."
  - `Features/Results/ResultsView.swift:437` — "Practice feedback only. Not professional coaching or medical advice."
  - `Features/Profile/SettingsSheet.swift:161` — "AI scores and feedback are for practice only. They aren't a substitute for professional coaching, therapy, or medical advice."
- **Speech coaching positioning:** consistently framed as practice/coaching, not therapy. No claims of curing anxiety, fixing speech disorders, or guaranteeing interview success. Good.
- **Audio handling:** kept on-device, deleted post-transcription. Mic pre-prompt is honest. (If Hume is re-enabled, this disclosure must be updated.)
- **Transcript handling:** sent to Cloudflare Worker → Google Gemini. The transmission is over HTTPS with the Supabase access token as the Authorization bearer. Body size capped at 50 KB. Rate-limited at 20 requests / minute / user.
- **Real Life mode (user-typed scenarios):** the scenario string is sanitized via two layers:
  1. Client-side denylist (`RealLifeContentDenylist`) — conservative regex set targeting named-target violence, sexualizing minors, and a sealed slurs list.
  2. Server-side wrapping in `<user_scenario>` XML tags with prompt-injection countermeasures in the system prompt.
- **Risky wording:** none found in repo. No "cures", "guaranteed", "diagnoses", or "therapist-level".
- **Safer wording recommendations:** add "AI may occasionally produce inaccurate feedback" to the Results screen if Apple's AI guidance tightens further.
- **Plans:** #5, #10, #11.

## O. Metadata / App Store Connect Checklist

Items that must be verified manually in App Store Connect (cannot be checked from repo):

- App name (suggest "Parlance — AI Speech Coach" or "Parlance: Speak Better").
- Subtitle (30 chars max; do not duplicate name).
- Promotional text.
- Description — must avoid medical/therapy/guarantee claims; aligns with in-app copy.
- Keywords — avoid generic terms; respect Apple's restrictions on competitor names.
- Screenshots — must depict real, shipping features only. **Do not include tone analysis screenshots** if Plan #1 Option A is chosen.
- Preview videos — same constraint.
- Category — primary "Education" or "Health & Fitness" or "Productivity". Choose carefully; "Health & Fitness" invites stricter medical scrutiny.
- Age rating — questionnaire must reflect UGC (Plan #8).
- Privacy policy URL — `https://theparlance.app/privacy` must be live, accessible without login, and match in-app disclosures (Plan #5).
- Support URL — `https://theparlance.app/support` must be live.
- Marketing URL — optional.
- Copyright string — typically "© 2026 <legal entity>".
- Contact info — phone + email reachable by Apple.
- Review notes — paste Section P draft (Plan #6).
- Demo account credentials — must accompany Review notes.
- Privacy Nutrition Label answers — align with Plans #4, #5.
- Pricing/availability — confirm $9.99 monthly is intended; verify all storefronts.
- IAP metadata — name, description, screenshot, review screenshot of the paywall for `com.parlance.pro.monthly`.
- Subscription group display name + localizations.

## P. Recommended App Review Notes (ready to paste)

```
Parlance is an AI speech coaching app. The core loop:
- Pick a practice mode → answer a prompt → record your voice → AI scores your
  delivery (filler words, pace, clarity, structure, vocabulary) and returns
  coaching feedback.

Permissions:
- Microphone (required to record your practice).
- Speech Recognition (Apple's transcription; transcript is sent to our AI).
- Notifications (optional; daily practice reminder).

Demo account:
  Email:    <REPLACE_WITH_DEMO_EMAIL>
  Password: <REPLACE_WITH_DEMO_PASSWORD>
This account has a populated profile and several historic sessions across
Job Interview, Pitch, Keynote, and Daily Conversation modes.

How to test the core flow:
1. Sign in with the demo account above.
2. From Home, tap any mode tile.
3. Grant Microphone + Speech Recognition when prompted.
4. After a 3-2-1 countdown, recording auto-starts. Speak for at least 5 seconds
   then tap the stop button. (Max 3 minutes per session.)
5. AI feedback loads on the Results screen.

How to test In-App Purchase (Parlance Pro):
1. From Home or Profile → Settings, open the paywall.
2. Use a StoreKit sandbox account to complete the purchase.
3. Restore Purchases is available on the same screen.

Account deletion:
- Profile → Settings → "Delete Account". Permanently deletes the account, all
  data, and revokes the Sign in with Apple identity if used.

Disclosures:
- AI feedback is positioned as practice, not therapy or medical advice.
- Audio is recorded locally and deleted after transcription.
- Only the transcript is sent over HTTPS to our AI provider (Google's Gemini
  API via our Cloudflare Worker proxy) for coaching feedback.
- See https://theparlance.app/privacy for the full privacy policy.

Backend health:
- API base: https://parlance-api.parlance-app.workers.dev
- Support: <REPLACE_WITH_SUPPORT_EMAIL>
```

## Q. Security Findings

- **Hardcoded secrets:** none of concern. The Supabase **anon key** is intentionally embedded in `SupabaseManager.swift:16` — this is the documented practice for Supabase (anon key is public, RLS enforces access). The code comment correctly explains this.
- **Worker secrets:** All sensitive keys (`SUPABASE_SERVICE_ROLE_KEY`, `APPLE_P8_PRIVATE_KEY`, `GEMINI_API_KEY`, `HUME_API_KEY`) live in Cloudflare Worker secrets, not in the iOS binary. Correct.
- **Token handling:** Supabase SDK stores tokens in Keychain. Worker calls use the user's JWT as the `Authorization: Bearer` header. JWT validation on the worker queries Supabase `/auth/v1/user`. Correct.
- **Network:** All API calls use HTTPS. No `NSAllowsArbitraryLoads` overrides. ATS defaults preserved.
- **Logging:** All `print(...)` calls in production code are gated by `#if DEBUG`. Spot-checked `SpeechTranscriber` (logs transcript prefix), `ClaudeClient` (logs raw response), `AppDelegate` (logs APNs token), `PushTokenService` (logs user ID) — all DEBUG-only.
- **Local storage:** SwiftData container at the default location; no sensitive secrets stored in UserDefaults (only `appTheme`, `dailyReminderEnabled`, `parlance.pendingSync`, `parlance.welcome_uid`). No PII keychain abuse.
- **Debug endpoints:** API base URL `https://parlance-api.parlance-app.workers.dev` is the production worker. No staging URL in Release config.
- **Debug menus:** none observed. UI-test bootstrap (`UITestBootstrap`) only activates when the launch arg `--ui-test-seed-pro` is present **and** the build is Debug. Verify in archive (Plan #17).
- **Profanity/abuse:** filter applied to profile fields and Real Life scenarios.

## R. Accessibility / HIG Findings

- **VoiceOver:** record button has `accessibilityLabel`. Toggle rows in Settings render as a single VO element (label + icon). Several decorative icons are not explicitly `accessibilityHidden(true)` — should be checked.
- **Dynamic Type:** custom fonts via `AppFonts.body(_:)`, `AppFonts.bodyMedium(_:)`, etc. Verify these use `Font.custom(_, size:, relativeTo:)` so they scale.
- **Contrast:** gold-on-card backgrounds at 12pt look light on light theme — verify against WCAG AA.
- **Tap targets:** mic button at 116pt is comfortable; back button at ~40pt height is borderline. The `IconButton.hitTarget = 44` constant is correctly used.
- **Destructive actions:** Sign Out, Reset All Data, Delete Account all show confirmation alerts. Sign Out alert should disclose local data wipe (Plan #12).
- **Native patterns:** uses NavigationStack, sheets, alerts — all native. No mimicry of system UI.
- **App icon:** must be reviewed in App Store Connect — not compared here.
- **Plan:** #15.

## S. Build / Release Configuration Findings

- **Schemes/targets:** `Parlance` (app), `ParlanceTests`, `ParlanceUITests`.
- **Configurations:** Debug + Release. Release block (pbxproj 458-514) sets `SWIFT_COMPILATION_MODE = wholemodule`, `ENABLE_NS_ASSERTIONS = NO`, `VALIDATE_PRODUCT = YES`, `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`. All correct for App Store distribution.
- **Signing:** automatic, team `497VU99KK9`. Verify the team has the App Store distribution certificate.
- **Entitlements:** Release uses `Parlance.entitlements` with `aps-environment = production` and Sign in with Apple. Debug uses `ParlanceDebug.entitlements` with `aps-environment = development`. Correct separation.
- **Deployment target:** iOS 18.0 across all configs. Aggressive but acceptable — restricts audience to iOS 18+ devices.
- **Device family:** iPhone + iPad (Plan #13).
- **Background modes:** `remote-notification` only. No silent push abuse concerns.
- **App Transport Security:** default (no overrides).
- **Bitcode:** removed by Apple in modern Xcode; no action needed.
- **Bundle ID:** `org.Parlance` (Plan #14).
- **Marketing version / build:** 1.0 / 1 — correct for first submission.

## T. Manual Review Items

Items that must be handled outside the codebase before submission:

- Demo account creation + App Review Notes (Plan #6).
- Privacy Policy published and accurate (Plan #5).
- Terms of Service published.
- Community Guidelines published (Plan #8).
- Privacy Nutrition Label answers in App Store Connect.
- Age rating questionnaire answers (Plan #8).
- App Store screenshots — confirm no disabled features depicted.
- StoreKit product (`com.parlance.pro.monthly`) in "Ready to Submit" with localized name/description.
- Cloudflare Worker production deploy + monitored uptime.
- Supabase production project: email confirmation, RLS policies, push token table, leaderboard views, blocked_users + user_reports tables.
- Apple P8 key + key ID + team ID configured in worker secrets for `/delete-user` revoke flow.
- Real-device testing of the full session loop (mic, transcription, scoring, results, paywall, restore, deletion).
- iPad strategy decision (Plan #13).
- Bundle ID decision (Plan #14).

## U. Recommended Pre-Submission Checklist

**Code / app behavior**
- [ ] Resolve Plan #1: remove or re-enable Tone Analysis end-to-end.
- [ ] Resolve Plan #2: add Terms/Privacy links to paywall.
- [ ] Resolve Plan #3: remove hardcoded paywall price/period strings.
- [ ] Resolve Plan #7: enforce email verification.
- [ ] Resolve Plan #11: delete or feature-flag dead Hume code.
- [ ] (Optional) Resolve Plan #12: stop wiping local data on Sign Out.
- [ ] (Optional) Resolve Plan #13: drop iPad target or commit to iPad pass.
- [ ] (Optional) Resolve Plan #14: confirm bundle ID.
- [ ] (Optional) Resolve Plan #15: accessibility audit.

**Privacy / legal**
- [ ] Resolve Plan #4: remove CoarseLocation from privacy manifest.
- [ ] Resolve Plan #5: publish updated Privacy Policy naming Gemini, Apple, Supabase, Cloudflare.
- [ ] Resolve Plan #9: complete Required Reason API audit.
- [ ] Resolve Plan #10: update in-app "About Your Data" copy.
- [ ] Confirm Community Guidelines live (Plan #8 dependency).
- [ ] Confirm Terms of Service live.

**App Store Connect**
- [ ] App name, subtitle, description, keywords entered.
- [ ] Screenshots + preview video reflect shipping features only.
- [ ] Privacy Nutrition Label completed (no CoarseLocation; mentions Gemini).
- [ ] Age rating questionnaire answered with UGC + 17+ if appropriate (Plan #8).
- [ ] Support URL, Marketing URL, Privacy URL live + correct.
- [ ] App Review Notes pasted (Plan #6 / Section P).
- [ ] Demo account email + password attached to review notes (Plan #6).

**IAP / subscriptions**
- [ ] `com.parlance.pro.monthly` "Ready to Submit" with localizations.
- [ ] Subscription Privacy Policy + Terms URLs entered at the product level.
- [ ] Review screenshot of the paywall uploaded.

**Account deletion**
- [ ] Deletion flow tested end-to-end on a test account; Apple identity revoke confirmed.

**AI / speech / audio**
- [ ] All AI claims read as practice/coaching, not therapy/medical.
- [ ] Mic + speech permission prompts disclose where audio/transcript goes.
- [ ] Tone Analysis claim removed from paywall (or fully re-enabled, Plan #1).

**QA / device testing**
- [ ] Fresh-install flow on iOS 18.x physical device.
- [ ] Mic + Speech permission denied path — app survives.
- [ ] Mic + Speech permission revoked mid-session — app survives.
- [ ] Airplane mode session — local scoring fallback engages, results screen shows.
- [ ] StoreKit sandbox: purchase, cancel, restore, refund tested.
- [ ] Account deletion tested on real device.
- [ ] VoiceOver smoke test across each tab.

**Metadata / screenshots**
- [ ] No reference to "Tone & Emotion Analysis" anywhere unless Plan #1 Option B is chosen.
- [ ] No "beta", "test", "debug", "coming soon" in shipped strings.
- [ ] Screenshots show real localized prices, not "$9.99".

## V. Confidence Scores (1–10)

| Area | Score |
|---|---|
| App Store approval readiness (today) | 4 |
| App Store approval readiness (after Blockers + Highs) | 8 |
| Crash / bug readiness | 8 |
| Privacy compliance readiness | 5 |
| Metadata readiness | 4 |
| IAP / subscription readiness | 3 |
| Account deletion readiness | 9 |
| AI / speech / audio readiness | 7 |
| Build / release readiness | 8 |

## W. Analysis Limitations

This review was static and could not verify the following:

- **App Store Connect metadata** (description, keywords, screenshots, privacy answers, age rating, support/marketing/privacy URLs, IAP metadata) — must be verified manually before submission.
- **External Privacy Policy and Terms** at `theparlance.app/privacy`, `/terms`, `/guidelines`, `/support` — not in repo; cannot verify content matches code.
- **Live backend behavior** of the Cloudflare Worker and Supabase backend (RLS policies, table schema, push pipeline). Code paths inspected; runtime behavior assumed.
- **Real-device permission behavior** (mic denial, speech revoke, notification permission) — code paths reviewed; on-device behavior must be re-tested.
- **Live StoreKit behavior** (purchase, cancel, restore, refund) — not exercised; configuration validated against `Parlance.storekit`.
- **Reviewer credentials** — must be provisioned manually.
- **Sandbox / production environment differences** — only one API base URL detected; verify Release archive uses the correct URL.
- **Marketing materials** — the App Store listing's "Tone & Emotion Analysis" mention (if any) is out of scope for this static review and must be reconciled if Plan #1 Option A is chosen.
- **Localizations** — only `en_US` locale verified for StoreKit; other locale strings not audited.
- **Apple Speech privacy** — Apple's own data flow for `SFSpeechRecognizer` is governed by Apple's privacy policy; recipient liability for transcribed audio rests with Apple.

End of mock review.
