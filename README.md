# Apex Resolve

**From Conversation to Verified Resolution**

Apex Resolve gives each software issue a private Nexconn conversation, a task list, an evidence record, and a verification decision. It is built for agencies and support teams whose clients need to see what fixed a problem.

An authorized independent reviewer can approve a pending resolution after inspecting evidence. The database checks the current request and excludes the requester, assigned resolver and sole evidence uploader. PostgreSQL records the decision, audit event, knowledge entry, and message-outbox entry in one transaction. The room later broadcasts that committed decision through Nexconn. Reopening a regression preserves its history and removes it from the verified knowledge base.

[Judge evidence](docs/JUDGING_MATRIX.md) · [Write-up](output/pdf/Apex-Resolve-Writeup.pdf) · [Two-minute demo](output/demo/Apex-Resolve-Demo.mp4)

## Run locally

Use Node.js 22.18+ or 24 LTS, npm and a dedicated Supabase project.

```sh
npm ci
cp .env.example .env.local
npm run dev -- --port 3001
```

Open the development URL printed by Next.js. The landing page and account forms render before configuration. Sign-in, workspaces, private storage, chat and analysis each require the corresponding services. Apply the numbered SQL files in `supabase/migrations` in order, configure Auth redirects and set the environment variables in the setup guide. [Setup and Vercel deployment](docs/SETUP.md)

## Implementation

| Area | Components |
| --- | --- |
| UI | Next.js App Router, strict TypeScript, React, Tailwind CSS, shadcn/ui, Lucide |
| Identity and access | Firebase email/Google sign-in, server-verified Firebase identity, Supabase session bridge, workspace roles and issue-scoped guest access |
| Persistence | Supabase PostgreSQL, RLS, transactional RPCs and private Supabase Storage |
| Conversation | Nexconn Web SDK, server-issued tokens, Group Channels, persisted history, read receipts, custom workflow cards |
| Analysis | Consent-gated OpenRouter free routing, optional Gemini when configured, Zod output validation, manual approval of suggested tasks |
| Release | Git, npm lockfile, Next.js production server and Vercel configuration guide |

## Verification and release status

```sh
npm run lint
npm test
npm run build
npx tsc --noEmit
```

The production build generates the Next.js route types consumed by the standalone type check. For a clean checkout without a build, run `npx next typegen` first. Browser checks use Playwright. The separate credentialed acceptance test creates real records and requires two accounts. [Browser testing](docs/BROWSER_TESTS.md)

The Nexconn server API path passed live token, group, join, profile and workflow-message checks. A user screenshot shows a real issue conversation, and the user reported successful two-account sync. OpenRouter free routing has answered a live application analysis request; Gemini awaits a key. On localhost, consented analysis can use the current browser's Nexconn history when the HTTPS webhook mirror is empty. A deployed app should still configure that webhook and verify its delivery. Group typing and online presence are omitted. File upload and metadata registration span separate services; an interrupted upload can leave a private unreferenced object. A leased outbox provides at-least-once transport and the room deduplicates cards by audit ID. [Current status](docs/STATUS_REPORT.md) · [Test record](docs/TESTING.md) · [Nexconn details](docs/NEXCONN.md)

## Project guides

- [Architecture](docs/ARCHITECTURE.md)
- [Security and access model](docs/SECURITY.md)
- [Two-user demo script](docs/DEMO_SCRIPT.md)
- [Submission checklist](docs/SUBMISSION.md)
