# Security

## Authorization

Every workspace route checks Supabase Auth. User-facing database operations use the caller's session. RLS limits reads and protected tables deny direct client writes. SECURITY DEFINER workflow functions use an empty search path, fully qualified objects, explicit role checks, issue locks and restricted execute grants.

Admins manage invitations and team roles. The owner retains the admin role. Members and verifiers work on issues. Guests see only explicitly shared rooms and may add evidence. Verifiers and admins approve, reject or reopen an issue. An immutable-to-app-users audit event records actor, timestamp and resource. Invite tokens expire after 24 hours, are stored as digests and are consumed under a row lock. Treat links and the invitation creation page URL as bearer credentials.

## External services

The Nexconn secret, Supabase secret key and provider keys stay on the server. A same-origin token request requires a verified user and an RLS-visible issue. Token issuance is rate limited. Tenant-managed token lifetime and group permissions also matter because SDK traffic goes directly to the provider. Use a dedicated provider app. If you revoke access operationally, remove the corresponding provider membership and invalidate any issued credentials as well. [Nexconn setup](NEXCONN.md)

Validated uploads have a 4 MiB ceiling. The handler checks format signatures or UTF-8 text, extension, MIME type and issue permissions. The private bucket denies direct end-user uploads. A download route uses the caller's client for the RLS check and short-lived link. URL evidence is opened with a separate browsing context and never fetched by the server. Periodically reconcile unreferenced private objects after interrupted uploads.

The consent dialog names both possible AI providers. The server sends bounded message text with instructions to treat conversations as untrusted. Generated text is rendered through React and requires human approval before becoming work. The OpenRouter path enforces a free-model suffix. Upstream responses and keys stay out of application error messages. Basic text redaction cannot detect all sensitive content. Configure provider billing limits independently of application reservations.

## Operational checks

Use isolated test tenants, HTTPS, Supabase Auth rate limits, short-lived Nexconn tokens and restricted access to production database roles. Review your hosting logs for invitation URL retention and webhook secret exposure. Token responses and file redirects use private no-store responses. Do not upload production credentials, real customer conversations or private evidence to the hackathon dashboard.
