# Judge evidence
| Criterion | What the judge can do | Verified on Nov 22 |
| --- | --- | --- |
| Completeness & UX · 50% | Exchange a private message and a community message, refresh, convert a room message to an issue and open the source again. | PASS on localhost and the anonymous-accessible Vercel production URL with hosted Nexconn and Supabase. Chrome checked 390, 768, 1280 and 1440 px for horizontal overflow. |
| Innovation & scenario value · 30% | Assign the resolver, identify the affected colleague, inspect evidence with ProofGuard, request independent review and return to the original conversation. | PASS. The resolver's authenticated approval was denied. An independent reviewer approved. Verified status appeared in the filtered queue and source room. ProofGuard assessed an intentionally sparse note. The local run returned an evidence assessment. On the public URL the model returned an incomplete assessment and the UI offered manual review. Thread AI hit its configured daily budget. Human review completed in both runs. |
| Business & growth · 20% | Examine the agency support workflow and proposed customer pilot. | PARTIAL. A test team completed the flow. External demand, retention and willingness to pay remain unmeasured. |

The browser uses the Nexconn SDK to send and receive messages. Supabase stores roles, requests, issues, evidence and decisions. Test setup and workflow transitions used authenticated RPCs. The run did not exercise interactive Firebase sign-in or exhaustively test every form.

[SDK implementation](../components/RoomChat.tsx) · [Database regression suite](../tests/database.test.mjs) · [Review policy](../supabase/migrations/202611220001_independent_review.sql) · [Release checklist](SUBMISSION_CHECKLIST.md)
