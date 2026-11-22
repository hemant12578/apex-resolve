# Apex Resolve status — 20 November 2026

## Verified today

- Production build and ESLint pass. Unit suite: 25 pass, 1 skipped. Public Chrome browser suite: 3 pass from the earlier public-route run; the new signed-in analysis fallback has not been browser-tested yet.
- Supabase migrations are applied. The live project returns successful counts for profiles, workspaces, issues, tasks, evidence, chat context, and AI analysis tables. The `evidence` Storage bucket exists and is private.
- Firebase-to-Supabase account linkage is present for one user. The user reported a successful Google login on 19 November; a fresh interactive login was not repeated for this audit.
- OpenRouter accepted the supplied server-side key. The previous explicit free model returned unavailable, so the local configuration now uses `openrouter/free`. A structured-output request succeeded on a free routed model, and the application's `analyzeMessages` function validated a live response from the free router. Paid model IDs remain blocked in code.
- Nexconn accepted signed live requests for token issuance, closed Group Channel creation, member join, group profile lookup, and a persisted `Apex:Workflow` message. Every request returned `HTTP 200` and provider code `0`; the message response contained an acknowledgement ID. These checks created two clearly named smoke-test groups and test identities in the Nexconn tenant. The app uses the official Nexconn Chat SDK in the browser and these signed server APIs for its Resolution Room.
- Local app is running at `http://127.0.0.1:3000` during this audit.

## Implemented but not yet verified end to end

- Workspace creation, invitations, member roles, scoped guest access, issues, tasks, evidence, verification, audit events, and searchable knowledge have schema and automated logic tests. A later user screenshot shows a real issue and a Nexconn conversation, superseding the earlier zero-issue count. The entire verification flow has not been exercised in this audit.
- The later screenshot shows messages exchanged in a real issue room. The user has also reported testing live sync with two accounts. Read receipts, reconnection, and workflow-card rendering still need explicit live checks.
- The signed Nexconn webhook and bounded chat-context mirror are implemented, but localhost has no reachable HTTPS webhook URL. Analysis now uses the recent text messages already loaded by the Nexconn SDK in that browser when the server mirror is empty, after explicit consent. This fallback stays within the requesting user's analysis and is not written into the shared webhook mirror. A live AI response on that real issue still needs a user retest.
- The protected scheduled outbox endpoint exists, but `CRON_SECRET` is unset and no scheduler is configured. Open rooms attempt outbox delivery every 15 seconds.
- Firebase email/password signup, verification, password reset, and Google sign-in are wired in the app. Full fresh-account and recovery flows have not been tested in this audit. Firebase Analytics is initialized, but collection has not been checked in Firebase reports.

## Not configured or outside the current MVP

- Gemini has no key yet. OpenRouter is the only configured AI provider and is limited to free routing.
- Apple sign-in is not implemented in the app.
- Nexconn Call, UniAPI, and Polaris are not integrated. The hackathon brief prioritizes genuine Nexconn Chat SDK communication for the Resolution Room rather than every Nexconn product.
- No public deployment or hackathon submission has been performed.

## Release gate

Retest analysis on the existing issue after reloading the updated app. Verify evidence-gated approval and a Nexconn workflow card. Before deployment, configure an HTTPS Nexconn webhook and confirm a new room message reaches `room_context`; the browser fallback is intended for local development and intermittent webhook gaps. Check read receipts and reconnection in two independent browser sessions.
