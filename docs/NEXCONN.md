# Nexconn resolution rooms

## Configuration

1. Create a dedicated application in the [Nexconn console](https://console.nexconn.ai/agile/apps/km). Select its Chat service, note the data center, enable group management, and check group message history retention for your plan.
2. Set `NEXT_PUBLIC_NEXCONN_APP_KEY`, `NEXCONN_APP_SECRET`, and `NEXCONN_REGION` in the server environment. The supported mappings are Singapore (`SG`), North America (`NA`), and Saudi Arabia (`SA`). Supply the server-side Supabase key and apply all migrations in order.
3. Configure a short token lifetime in the Nexconn console. The provider documents indefinite validity by default. Browser sessions receive a per-user token in a private, uncached response after Supabase authenticates the user and RLS admits the issue.
4. To populate the optional text context mirror, set the Nexconn webhook in Chat → Chat settings → Webhooks to the deployment’s HTTPS `/api/chat/webhook` URL and subscribe to `message:send` and `message:delete`. Configure it before the conversation you intend to analyze. The browser chat itself reads history directly from Nexconn. The mirror retains up to 50 rows per room, including deletion tombstones. It ignores directed messages, other channels, blocked messages, custom events and attachments. No webhook data is sent to an AI provider by this handler.
5. While a room is open it drains committed workflow events every 15 seconds. For unattended delivery, set a random `CRON_SECRET` and schedule a server-side GET to `/api/chat/events` with that bearer credential. Each invocation publishes at most ten eligible events. Configure schedule frequency for the backlog and hosting plan.

## SDK and server behavior

The installed SDK exposes version 26.5.1 of both `@nexconn/engine` and `@nexconn/chat`. The official skill repository confirms its optional installation command below. This application uses the underlying Web SDK with a custom room panel to filter a single Group Channel, display persisted workflow cards, and coordinate restricted membership. [Official skill](https://github.com/NexconnAI-Dev/nexconn-skills) · [Web SDK quickstart](https://docs.nexconn.ai/chatsdk-web.md)

```sh
npx skills add https://github.com/NexconnAI-Dev/nexconn-skills.git --skill nexconn-chat
```

On first authorized room entry, the session handler issues an identity for the reserved workflow sender, creates a closed group owned by that sender, persists the deterministic group ID, registers the current user, and joins them using the signed server API. Supabase UUIDs map to alphanumeric Nexconn user IDs. Retries reuse the same channel ID and verify ownership and join settings when recovering an existing group. Clients receive neither the workflow identity token nor the App Secret. The current product supports adding memberships and changing team roles. Before adding access removal, synchronize the provider-side group removal and expire affected tokens during revocation. [Server signing](https://docs.nexconn.ai/platform-chat-api/prepare-to-use-api/auth.md) · [Token issuance](https://docs.nexconn.ai/platform-chat-api/user/register.md) · [Group creation](https://docs.nexconn.ai/platform-chat-api/group-channel/managing-channels/create-group.md) · [Group join](https://docs.nexconn.ai/platform-chat-api/group-channel/managing-members/join-group.md)

The client registers listeners before connecting. It requests history in pages of 50, merges live and historical messages, and refreshes the newest page on SDK reconnect. The installed SDK uses `message.channelIdentifier` and `isPersisted` in custom type registration. Group read receipts are requested on sends, answered on visible incoming messages, and updated from SDK callbacks. Group typing and presence are omitted. [Receiving](https://docs.nexconn.ai/chatsdk-web/message/receive.md) · [History](https://docs.nexconn.ai/chatsdk-web/message/get-history.md) · [Reconnect](https://docs.nexconn.ai/chatsdk-web/connection/reconnect-kick.md) · [Custom messages](https://docs.nexconn.ai/chatsdk-web/message/customize.md)

Audit and outbox rows commit in the same transaction. A server worker leases outbox rows, sends a persistent `Apex:Workflow` custom message, and acknowledges provider success in PostgreSQL. Ambiguous transport failures may create multiple provider messages. The room renders one card per audit event ID and recognizes workflow cards only from the server-owned sender. The audit timeline remains authoritative. [Server group messages](https://docs.nexconn.ai/platform-chat-api/message/send-group.md)

## Live acceptance record

Live API status on 20 November 2026: signed token issuance, closed Group Channel creation, member join, profile lookup, and one persisted `Apex:Workflow` send all returned HTTP 200/provider code 0. The send returned a message ID. This smoke test created test identities and two labeled test groups in the Singapore tenant. It verifies the server API path; the later user screenshot and reported two-account sync provide separate evidence of user-facing chat.

Later on 20 November, a user screenshot showed a real issue with Nexconn conversation messages, and the user reported two-account live sync. The previous zero-issue observation is therefore stale. Localhost cannot receive Nexconn's external webhook, so an empty `room_context` no longer blocks advisory AI analysis: with explicit consent, the app uses up to 50 text messages currently loaded by the Nexconn Web SDK in that browser when the server mirror is empty. That browser snapshot is validated, user-scoped, and never inserted into the shared mirror. Production should still configure the signed HTTPS webhook for independent server-side history; deletion and retention semantics depend on it.

Use two separate browser profiles with different registered users. Record the run date, deployment, SDK version, issue ID, results and evidence privately. Redact tokens, secrets and real customer messages.

| Check | Expected observation |
|---|---|
| Open an issue as an admin, then as its invited guest | Both see Connected. The issue has one channel_id. |
| Exchange a unique message in each direction | Both profiles receive the other account’s text and sender identifier. |
| Refresh both tabs | Both messages reload from remote history. |
| Disconnect and restore network in one browser | The SDK reconnects. Send a fresh message and verify it arrives. |
| Complete a task or attach evidence | Both clients receive a workflow card matching the committed audit event. |
| Retry delivery and reload history | The same audit event renders once. |
| Try a different, unshared issue as the guest | The protected route and chat-session endpoint deny access. |
| Request a group join directly from an unrelated app identity | Provider-side group permissions deny the request. |
| Configure webhook and exchange fresh text | The authorized context reader returns the two messages in chronological order. |

If the console app cannot access group management, check the service settings and the region first. If a vendor call fails, the room shows the connection error and the app retains the issue for retry. History retention and reconnect behavior require a real tenant test.

## Webhook integrity and access testing

Nexconn signs the App Secret, nonce, and timestamp. The signature input excludes the request body. Use HTTPS and restrict ingress at the deployment firewall to the published Nexconn IP ranges for your region. The handler checks the App Key, verifies the signature in constant time, enforces a five-minute freshness window, and atomically binds each verified header identity to the SHA-256 digest of the first body received. An identical retry is safe. A changed body with the same identity returns HTTP 403. The first body relies on transport integrity. Provider delivery retries are limited, so the context mirror can have gaps after prolonged downtime. [Official webhook authentication and address ranges](https://docs.nexconn.ai/platform-chat-api/webhook/overview.md)

Closed rooms set `joinPerm=3` (user joins disabled) and `memInvitePerm=0` (owner invitations only). The only owner is the service identity whose token stays on the server. The signed Platform Chat API admits authorized app users through the separate administrative join endpoint. Tests check the outgoing values and the role checks in PostgreSQL. Confirm denied client joins and denied client invitations against the selected Nexconn tenant during live acceptance. [Provider permissions](https://docs.nexconn.ai/platform-chat-api/group-channel/managing-channels/create-group.md) · [Administrative join](https://docs.nexconn.ai/platform-chat-api/group-channel/managing-members/join-group.md)
