# Browser acceptance

Start the app in one terminal using `npm run dev`. In another terminal, run `npx playwright install chromium` once, then `npm run test:e2e`. Set `E2E_BASE_URL` if the app runs somewhere other than http://127.0.0.1:3000. To use an installed Chrome, set `E2E_BROWSER_CHANNEL=chrome`.

The public suite checks the landing workflow preview, mobile layout, login/signup/reset navigation, protected route redirects and unauthenticated chat token refusal. The live case is explicitly skipped by default.

## Two-user release gate

Use a disposable Supabase project with all migrations applied, two verified Firebase email/password test accounts, and a test Nexconn app with the credentials and region configured on the server. Set the following in the test process environment, privately through your shell or CI secret store. The existing live suite has not yet been rerun against the Firebase bridge and remains a release gate, not proof of current live chat.

| Variable | Purpose |
| --- | --- |
| E2E_LIVE | Set to 1 to run the live case |
| E2E_ADMIN_EMAIL, E2E_ADMIN_PASSWORD | Account that creates a workspace and becomes its admin |
| E2E_MEMBER_EMAIL, E2E_MEMBER_PASSWORD | Separate account invited as a member |
| E2E_BASE_URL | URL of the configured running application |
| E2E_BROWSER_CHANNEL | Optional installed browser channel |

Run `npm run test:e2e -- live.spec.ts`. The test creates a fresh workspace, issue, invitation, messages, evidence, verification, audit events and knowledge record. These records stay in the test projects after the run. Traces, videos and automatic screenshots are disabled because they can contain chat content, invitation URLs and session data.

The two isolated browser contexts sign in separately. Before invitation acceptance, the member must receive a 404 on the initial room token request. Both users must then exchange messages, retrieve history after reload, and recover a message sent during an offline interval. The member requests verification without evidence and receives an error, uploads a test log and requests review again. The admin approves the issue. The test checks committed workflow events in chat, knowledge search, and logout. Any failed assertion keeps the release gate open. Browser offline emulation must interrupt the actual socket for the reconnect assertion to pass. A skipped case provides no live-provider verification.

With a disposable Supabase stack and the same two test accounts, set `E2E_CORE=1` to run the core workflow independently of Nexconn. Both workflows create and complete a task, upload a private text log, verify its downloaded contents, and request approval. The Nexconn case additionally checks real-time and history behavior. Use `E2E_CORE=1 npm run test:e2e -- live.spec.ts` to run just the core case and skip the credentialed chat case.
