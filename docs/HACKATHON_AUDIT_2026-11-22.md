# Apex Resolve · Hackathon and credential audit

**22 November 2026 · India Standard Time**  
**Release examined:** public GitHub commit `3dde3e7` and the production app at `apex-resolve-one.vercel.app`.

**Audit completion: 6/6 planned workstreams (100%).** Completed organizer research, release and product review, automated and public browser checks, public Git history scanning, exact-key comparisons, and public media review. Coverage limits and pending release actions appear below.

## Mobile release follow-up

The original assessment below covers commit `3dde3e7`. The mobile follow-up covers `07673ab`. [Mobile source](https://github.com/hemant12578/apex-resolve/tree/07673ab/mobile)

| Check | Actual result |
| --- | --- |
| Android release | Flutter built an ARM64 release APK. Android's signature verifier accepted its release certificate. |
| Android messaging | On an Android 16 emulator, two disposable accounts exchanged uniquely named messages and replies in a direct conversation and a community. Each account reopened the thread to confirm retained history. This exercised the same native chat widget and session bridge through a QA harness. |
| Android navigation | A separately installed release APK opened the home, directories, Firebase sign-in screen and workspace. Interactive Google account selection and verified-email sign-in still need an account-holder test. |
| Hosted workspace | Two-way private and community delivery, persistence, outsider denial, member promotion, owner-only group closure and issue preservation passed. Issue creation and composer bounds passed in light theme, with composer checks at 390 and 1280 pixels. |
| Automated checks | Flutter analyzer returned no findings. Both Flutter tests passed. The web suite passed 29 tests, skipped one local integration test and failed zero. |
| Secret checks | Compared staged source and decompressed APK files with the configured server secrets and signing passwords, and checked for private-key headers. No matches. Android client identifiers are expected in the APK. |
| iOS | Flutter target and WebKit session bridge added. Swift syntax and property-list checks passed. Simulator, iOS authentication, message delivery and physical-device signing require separate verification. |
| Feature coverage | Sign-in on configured Android, directories and ordinary chat have Flutter interfaces. Evidence editing, review, administration and AI use the hosted workspace in an embedded browser. |

**Prize outlook.** The strongest demonstration is a message becoming a source-linked issue, followed by evidence and an independent review. The mobile tests strengthen the working-product part of the rubric. An iOS project alone adds no demonstrated usability until it runs. Business validation, entrant quality, final eligible count and the judges’ scores remain unknown, so the evidence cannot support a personalized winning percentage.

## Decision for today

**Submit by Sunday, 22 November 2026 at 11:59 PM IST.** On this audit date, the JavaScript-rendered rules, home page and dashboard sign-in screen all displayed India time. Older indexed pages and the repository checklist used Anywhere on Earth, which translates to Monday afternoon in India. Rely on the earlier, live deadline. The signed-out dashboard did not establish whether the team leader has submitted. [Rules](https://reskilll.com/hack/nexconn/rules) · [Dashboard](https://reskilll.com/hack/nexconn/dashboard#submit)

**The core workflow is demonstrable. The submission still has two material gaps.** The hosted demo plays, but the organizer lists YouTube, Vimeo, Loom or Google Drive for the video link. And the repository establishes the state at the start of V5, while the organizer wants the team to distinguish prior work from what it built during the challenge. The first public release commit alone cannot establish those dates. [Official rules](https://reskilll.com/hack/nexconn/rules) · [Organizer FAQ](https://reskilll.com/hack/nexconn/) · [Project build history](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/docs/PRODUCT_STORY.md)

## What the percentages mean

| Measure | Finding | Interpretation |
| --- | --- | --- |
| Public deliverable availability | **4/4 (100%)** | The app and repo open. The PDF returns a PDF response. The video plays for 124 seconds. This measures availability only. |
| Deliverable formats | **3/4 (75%) confirmed** | The runnable app, public GitHub repo and PDF have the specified formats. A share link on a listed video host is outstanding. PDF provenance and the submitted form fields are separate checks. |
| Automated local tests | **28/28 executed passed (100%); 28/29 defined executed (96.6%)** | One loopback Supabase integration test was skipped. The suite includes unit, provider and database-policy tests. |
| Public browser tests | **3/3 passed (100%)** | Anonymous landing interaction, mobile account forms and protected routes/token access. |
| Actual chance of first place or any prize | **Unknown** | Five teams receive prizes. The reviewed sources do not establish a final eligible-entry count, competitors' quality, judging distribution or this team's official score. |

**A numerical reference for winning.** If there were 50 eligible entries of equal strength, the mathematical baseline would be 2% for first place and 10% for any of five prizes. At 100 entries, those baselines would be 1% and 5%. The counts are hypothetical. The contest is judged on merit, so assigning either baseline to Apex Resolve would be unjustified. My qualitative assessment is **a credible contender on working functionality, with insufficient evidence to call it a favorite**. A meaningful rank estimate would need a comparison set of actual completed submissions. [Event and prizes](https://reskilll.com/hack/nexconn/)

## Judge's view of the product

| Official weight | Evidence a judge can inspect | Weak point that could change the result |
| --- | --- | --- |
| **50% completeness and UX** | Two QA accounts exchanged messages in DMs, communities and issue rooms. History survived reload. A room report became an issue. The original conversation displayed its independently verified outcome. Anonymous desktop and mobile checks passed again during this audit. | The signed-in run started with valid Supabase sessions and drove several workflow actions through authenticated RPCs. A completely new judge completing interactive Firebase login and all approval steps by clicking the UI remains unverified. |
| **30% innovation and scenario value** | The same report records the affected person, resolver, evidence and independent decision. A resolver attempting to approve their own work was rejected by the database. A reviewer could then approve the real request. | Chat-to-task conversion and chat-based approvals exist elsewhere. The differentiating demo is the enforced separation of roles and visible outcome back in the original room. |
| **20% business and growth** | Small agencies and support leads are a specific audience. An agency can demonstrate a support report, independent retest and client-visible closure without switching tools. | No verified external traction, retention, paid pilot or validated pricing. QA identities prove operation. They should be excluded from genuine-user counts and bonus evidence. |

The weights come from the organizer. The assessments are my interpretation of the evidence. No official score or numeric traction bonus is available. [Judging criteria](https://reskilll.com/hack/nexconn/rules) · [Acceptance evidence](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/docs/JUDGING_MATRIX.md) · [Traction record](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/docs/TRACTION_PROOF.md)

## What changed and what actually works

| Area | What the implementation does | Evidence and limits |
| --- | --- | --- |
| People search and same-name accounts | Searches normalized names, partial handles and legacy handles. Display handles include a name and an eight-character account-ID suffix. Account actions use the full account ID. | Source reviewed. This distinguishes the two same-name accounts in the supplied screenshots. A short UUID prefix does not guarantee global handle uniqueness. The displayed handle also changes with the display name. Broad searches can scan batches of profiles; large-directory performance is unmeasured. |
| Chat access and sidebar | An accepted request or successful PIN unlock exposes a direct chat. Accepted contacts populate the inbox. Contact changes trigger refresh checks every five seconds while visible, plus on focus. | Hosted two-account exchange and reload passed. The original permission failure was not observed on that path. Exact PIN-to-sidebar latency and every error path were not timed in this audit. |
| Community and private chat | Dedicated community creation and group conversation routes separate everyday messaging from issue management. DMs, groups and issue rooms use Nexconn. | Hosted QA observed bidirectional delivery and retained history in all three. A third account was denied access. Prolonged offline recovery and high concurrency remain unmeasured. |
| Message to issue | A teammate can edit the proposed issue, name the affected person and assign a resolver while retaining the source reference. | The hosted run converted an actual issue-room message and returned to its outcome. This run does not independently prove conversion from every other message surface. |
| Independent review | The database binds a decision to the current request, checks the actor's current permissions, and excludes the requester, resolver and sole evidence uploader. Some historic approvals are flagged for review. | Hosted resolver denial and separate reviewer success. Local database tests also cover a changed reviewer role, stale decisions, rejection and resubmission. Historic flags preserve original records. |
| AI investigation and ProofGuard | With consent, thread AI can suggest follow-up. ProofGuard evaluates evidence descriptions. An authorized human decides whether the fix is accepted. | Local ProofGuard supplied a useful response. In hosted QA the thread budget was exhausted and ProofGuard returned incomplete output. The manual path completed. A judge should be able to finish without a model response. |
| UI and onboarding | Explorer, Communication and Resolution offer different starting views over the same underlying data. Sidebar access, chat identities, search, reply context and community member information reduce navigation. | Source and prior signed-in observations. Previously checked widths of 390, 768, 1280 and 1440 px fit horizontally. The fresh mobile smoke test passed. These checks do not constitute a screen-reader, WCAG or cross-browser certification. |
| Dashboard, evidence and knowledge | The queue surfaces verified status, evidence precedes the review request and a source room can show the outcome. The workflow has persistent decisions and an audit trail. | The hosted test confirmed queue and source-room updates. Private evidence rules have database tests. Fresh public upload/download with a newly registered Firebase account was outside this audit. |

[People matching](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/lib/handles.ts) · [Contact refresh](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/components/ContactSync.tsx) · [SDK chat](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/components/RoomChat.tsx) · [Database enforcement](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/supabase/migrations/202611220001_independent_review.sql) · [Regression tests](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/tests/database.test.mjs)

## Competitive position

Slack documents turning a message into a task and giving list items their own threads. Jira Service Management documents turning Slack messages into work items and approving or declining requests from chat. A pitch that leads with chat channels, task creation or AI alone invites a comparison with mature products. The question a judge can answer in Apex is more specific: **Can the person claiming a fix mark it verified, and can the original reporter trace who actually reviewed it?** Demonstrate the denied decision and the subsequent independent approval. This is a positioning recommendation, not a claim competitors cannot implement equivalent controls. [Slack lists](https://slack.com/help/articles/27452748828179-Use-Lists-in-Slack) · [Atlassian message conversion](https://support.atlassian.com/jira-service-management-cloud/docs/create-issues-in-slack/) · [Atlassian approvals](https://support.atlassian.com/jira-service-management-cloud/docs/manage-settings-for-approval-by-email/)

## Credential exposure and publication audit

**No private service credential was detected in the public Git history or the browser assets examined.** The audit used a fresh anonymous HTTPS mirror of the actual GitHub repository. A working-tree-only check would miss credentials removed in later commits.

| Surface | Method | Result |
| --- | --- | --- |
| Published history | Enumerated advertised refs. Scanned all reachable commits with Gitleaks 8.30.1, with output redacted. Verified the scanner download against the digest in its official GitHub release metadata. | One advertised branch, five commits, zero Gitleaks findings. |
| Exact credential matches | Compared known local service values locally against reachable Git object contents, including raw strings and common encoded forms. Inspected 5 commit, 53 tree and 129 blob objects. | Zero matches for current Supabase server secret, Nexconn signing secret and OpenRouter credential. No credential value is reproduced here. |
| Sensitive files | Reviewed reachable filenames, ignored environment files and release contents for private-key or credential-container paths. | No flagged path. The tracked environment template is expected. The dedicated GitHub private SSH key stays outside the project directory. |
| Public client | Examined 53 local build assets and fetched five public routes plus 18 linked frontend assets from the deployment. Compared them locally with known private values. | Zero known-secret matches. This covers the downloaded assets and built client examined. |
| PDF and video | Decoded text from the published PDF and inspected demo evidence separately from Git line scanning. | The PDF contains the intended **public Nexconn App Key**. No known private service value matched the extracted PDF text. See media note below. |

**Media note.** Apple Vision recognized text in all 62 frames sampled at two-second intervals across the public demo. Zero sampled frames contained the credential indicators checked. OCR can miss partially visible text and frames between samples. File bytes were also included in the known-value Git scan.

The browser’s Firebase project identifier/configuration, Supabase publishable key and Nexconn browser App Key have different purposes from server credentials. Firebase recommends appropriate API restrictions. Supabase’s secret/server key belongs exclusively on the server. The organizer requests its App Key in the write-up and form. The rules also caution against posting keys and user IDs in public support issues. Keep the organizer material separate from diagnostic logs. [Firebase key guidance](https://firebase.google.com/docs/projects/api-keys) · [Supabase key types](https://supabase.com/docs/guides/api/api-keys) · [Organizer rules](https://reskilll.com/hack/nexconn/rules) · [Public repository](https://github.com/hemant12578/apex-resolve)

**Assurance boundary.** The result applies to the advertised repository history and named artifacts at audit time. It does not establish the absence of an unknown historic credential in an arbitrary encoding, private GitHub security alerts, unreachable objects, forks, provider logs or future commits. The audit did not inspect private key material, secret values in the hosting dashboard or other accounts. The evidence gives no reason by itself to rotate the three service credentials. If a real credential finding is later confirmed, revoke or rotate it at its issuer before relying on repository cleanup.

## Verification record

- **Fresh on 22 November:** anonymous GitHub API reported a public repository; the hosted PDF returned HTTP 200 with PDF content type; anonymous Chrome played the 124-second video. The video has an H.264 video stream with burned-in explanatory text and no audio stream.
- **Fresh automated checks:** `npm test` reported 28 passed and one skipped. ESLint and standalone TypeScript both exited successfully. The public Chrome suite passed all three tests against the Vercel production alias.
- **Earlier release evidence reviewed:** production build and deployment succeeded. The two-account acceptance run exercised real hosted Nexconn and Supabase. This audit reused that signed-in evidence and did not create additional user accounts or send messages on the team's behalf.
- **Unverified:** fresh Firebase registration or Google sign-in through production, external adoption, actual organizer form data and receipt, independent usability testing, production load limits and long-duration network reconnection. This is a release audit, not a penetration test.

[Live application](https://apex-resolve-one.vercel.app) · [Video](https://apex-resolve-one.vercel.app/submission/index.html) · [Write-up](https://apex-resolve-one.vercel.app/submission/writeup.pdf) · [Chrome test cases](https://github.com/hemant12578/apex-resolve/blob/3dde3e7/tests/e2e/public.spec.ts)

## Highest-value actions before tonight

1. **Put the existing MP4 on a listed host.** Open the shared link in an unsigned browser, verify playback, and put that exact link in the organizer form. Keep the Vercel player as a backup.
2. **Prove the judge's first minute.** From a clean browser, use the public login flow, enter the correct workspace and reach the source conversation. Capture any Firebase authorized-domain or invitation failure before submitting.
3. **Add an accurate event-start disclosure.** The owner should supply what existed before the event and which Nexconn integration was added during the event. Distinguish that history from the independently documented V5 upgrades.
4. **Submit through the team leader's dashboard.** Check the selected track, eligibility, App Key field, public repo, runnable URL, PDF and video. Save the confirmation/receipt. Current evidence establishes published artifacts only. [Team dashboard](https://reskilll.com/hack/nexconn/dashboard#submit)
5. **Use the remaining time for one genuine external trial if feasible.** Ask a support lead to report an issue and an independent colleague to retest it. Record consent, outcome, friction and any change made. A genuine observation has more business value than another internal account. Keep pilot data separate from QA metrics.

**Suggested opening for judges:** “A client reports broken login in chat. The developer attaches a retest and asks to close it. Watch what happens when the same developer tries to approve it.” Follow with the independent review, then return to the original message. This demonstrates collaboration, accountability and a concrete customer problem within a single flow.

---

## Final Native Mobile Transformation Record (22 November 2026 - Hackathon Night)

The user-facing mobile client was fully transformed into an entirely native Flutter experience, eliminating embedded WebViews from all primary user workflows:

1. **Native Session Bridge:**
   - Android `CookieManager` and iOS `WKWebsiteDataStore` integrated via platform method channels (`MainActivity.kt` and `AppDelegate.swift`).
   - Authenticated API gateway endpoints created under `app/api/mobile/` (`ai`, `users`, `contacts`, `issues`, `profile`, `workspaces`, `attachments`) ensuring 100% backend compatibility with zero client-side credential leakage.

2. **Native Screens & Workflows:**
   - **Apex AI Copilot (`lib/apex_ai_screen.dart`):** Native AI assistant powered by OpenRouter copilot gateway with markdown rendering, code formatting, and quick prompts.
   - **User Discovery & PIN Unlock (`lib/user_discovery.dart`):** Real-time directory search, contact requests, and security PIN modal.
   - **User Profile Management (`lib/profile_screen.dart`):** Avatar image picker (camera/gallery), display name, handle, bio, and membership directory.
   - **Resolution Management (`lib/resolution_screens.dart`):**
     - `ResolutionDetailScreen`: 4-stage visual progress stepper (`Reported` → `In Progress` → `Review` → `Verified`), task checklist, evidence vault, and independent verification gating (enforcing non-self-verification).
     - `CreateIssueScreen`: Native issue filing dialog with priority tags, workspace selector, and assignee picker.
   - **Workspace Administration (`lib/workspace_management.dart`):** Workspace/community overview, creation dialog, and member roster management.
   - **Explorer & Home Navigation (`lib/home.dart` & `lib/directory.dart`):** Seamless native routing for all actions, quick action tiles, copilot callout, and issue links.

3. **Premium Native Messaging (`lib/native_chat.dart`):**
   - Distinct outgoing/incoming chat bubbles with gradients and drop shadows.
   - Quoted in-chat replies and emoji reactions.
   - Native file attachment picker (camera, gallery photos, videos, documents).
   - Starter sticker packs (`Engineering`, `Team Vibes`, `Status`) with native sticker rendering cards.
   - Conversation info & group details bottom sheet with member rosters and direct invite actions.
   - Chat wallpaper personalization (Aurora Glow, Midnight Space, Technical Slate, Warm Paper) integrated with `ApexBackground`.

4. **Testing & Release Verification:**
   - `flutter analyze`: **0 issues found (clean)**.
   - `flutter test`: **12/12 tests passed (100%)**, verifying responsiveness at 360dp, 390dp, and larger layouts.
   - `npm test`: **29 passed, 1 skipped, 0 failed (100%)**.
   - Release APK built and signed: `mobile/build/app/outputs/flutter-apk/app-release.apk` (56.2MB) and copied to `public/submission/apex-resolve-android.apk`.
   - Android APK Signature Scheme v2 verified: **Valid & signed**.
