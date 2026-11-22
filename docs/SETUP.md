# Setup and deployment

## Credentials and services

Use separate development and production projects. Copy `.env.example` to `.env.local` in the project root. Restart the Next.js server after configuration. Configure Vercel environment variables separately for preview and production.

| Variable | Value |
| --- | --- |
| NEXT_PUBLIC_APP_URL | Exact application origin, including port locally. This is used for invitation and Auth callback links. |
| NEXT_PUBLIC_SUPABASE_URL | Supabase project API URL |
| NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY | Supabase publishable key. A legacy anon key also works in this field. |
| SUPABASE_SECRET_KEY | Supabase secret key or legacy service-role key. Used by server code only. |
| NEXT_PUBLIC_NEXCONN_APP_KEY | Client app identifier from the Nexconn Chat console |
| NEXCONN_APP_SECRET | Matching server signing secret |
| NEXCONN_REGION | SG, NA or SA matching the app |
| CRON_SECRET | Random server-only bearer secret if using background outbox delivery |
| GEMINI_API_KEY, GEMINI_MODEL | Google AI Studio API key and Gemini model identifier |
| OPENROUTER_API_KEY, OPENROUTER_MODEL | Server-only key and free model ID, or `openrouter/free` for free-only routing |
| AI_PRIMARY_PROVIDER | `openrouter` now; set to `gemini` only after configuring Gemini |
| AI_ENABLED, AI_FALLBACK_ENABLED | Set to true only when enabling the corresponding feature |
| AI_DAILY_LIMIT, AI_MAX_CONTEXT_MESSAGES | Per-user analyses per UTC day and maximum messages (defaults 3 and 50) |
| AI_DAILY_BUDGET_MICROS, AI_REQUEST_RESERVE_MICROS | Deployment-wide daily budget and reservation per analysis in millionths of a US dollar. Zero daily budget blocks new calls. |

Supabase publishable keys identify the application. Database policies and the authenticated user's session determine access. The secret key bypasses RLS and belongs exclusively in the server environment. [Supabase API keys](https://supabase.com/docs/guides/api/api-keys)

## Database and accounts

1. Create a fresh Supabase project with Auth, Storage and the Data API enabled. From the repository root, initialize the Supabase CLI project if needed, link the intended project with `supabase link --project-ref YOUR_REF`, then run `supabase db push`. Alternatively, execute each versioned SQL file in filename order in the project SQL editor. Apply the migrations once to the intended database.
2. Configure Firebase Authentication for email/password and Google sign-in. Add the local and deployment origins to its authorized domains. Email/password accounts require Firebase's verification email before the app issues a Supabase session; Google accounts arrive verified through Firebase. The server validates Firebase ID tokens and creates a scoped Supabase session for database access.
3. Configure Firebase's email templates and authorized domain for verification and password reset. Workspace invites are single-use links displayed to the issuing admin.
4. Run `npm ci` and `npm run dev`. Register two Firebase accounts and confirm email/password accounts as required. Set distinguishable names in Settings.
5. Create a workspace in Dashboard. Open an issue, then invite the second account. A guest invitation requires an explicit issue. A team invitation grants workspace-level access.

## Nexconn and AI

Configure a dedicated Nexconn Chat app, select its region, enable group management and message persistence, and register the signed webhook before generating a conversation for analysis. The webhook needs a reachable HTTPS origin. Complete the independent-browser release gate before enabling AI. [Nexconn setup and acceptance](NEXCONN.md)

OpenRouter's `openrouter/free` route selects an available free model that supports the requested structured output. Explicit `:free` model IDs are also accepted; paid model IDs are rejected in code. Free model availability and rate limits change, so verify the provider again before a demo. The Gemini configuration remains available for later use. [OpenRouter free models](https://openrouter.ai/collections/free-models/)

Set a finite provider budget and a conservative worst-case per-request reservation for the selected model, bounded prompt and 2,600 output tokens. For example, 100,000 micro-USD reserves USD 0.10 per request. Daily reservations include failed attempts because a timed-out request may already have been billed. Tune the reserve against current provider rates and set billing controls at the provider. Explicit per-analysis consent is required for each enabled provider.

## Vercel

Use the repository root and Next.js framework preset, Node 24 LTS, npm install from the lockfile, and `npm run build`. Set the public origin and environment for the target deployment, then rebuild after changing public keys. Apply migrations separately before sending traffic. Each preview deployment using Auth needs a permitted redirect URL. Use a distinct preview Supabase/Nexconn tenant when testing private data.

The room drains committed events while open. For unattended retries configure a Vercel Cron or private scheduler for `GET /api/chat/events` and send `Authorization: Bearer <CRON_SECRET>`. Select an interval supported by the hosting plan. Perform the live browser test and check the webhook using newly sent test messages after deployment. Repository publication, deployment and hackathon submission require a separate user decision.

## Firebase Authentication and Analytics

The Firebase web SDK is installed through npm. Set the seven `NEXT_PUBLIC_FIREBASE_*` variables from the registered Firebase web app configuration. The root layout initializes Analytics in supported browsers. Firebase handles login, signup and password reset; Supabase stores application data and receives a server-created session after Firebase identity verification. Check the Analytics DebugView or Realtime report after deployment to confirm collection.
