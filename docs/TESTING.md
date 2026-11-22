# Test record

The unit and PostgreSQL suite uses controlled provider responses and PGlite for the migration logic. It checks guest isolation, direct write denial, invitation reuse, task changes, file metadata checks, verification transactions, audit/outbox consistency, AI reservations and provider fallback. The SQL tests apply all numbered migrations to a temporary database. Run `npm test`.

`npm run lint`, `npm run build`, and `npx tsc --noEmit` check the repository. The build must run before the standalone type check on a clean checkout so Next.js generates route types.

`npm run test:e2e` checks the public experience and anonymous access in Chrome. `E2E_LIVE=1 npm run test:e2e -- live.spec.ts` runs the credentialed two-user scenario described in [browser testing](BROWSER_TESTS.md). The live scenario creates real persisted records. Run it only in a disposable test tenant.

The release record is complete only after the Supabase migrations have been applied and two test accounts have passed browser checks using a live Nexconn app. Verify message exchange, refresh history, reconnection, event cards and provider-side membership enforcement. Then enable AI with a configured budget and test Gemini and the free OpenRouter fallback with the real account quotas. Record failures and the provider model versions in the release notes.
