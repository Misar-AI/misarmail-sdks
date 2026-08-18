# MisarMail TypeScript SDK

[MisarMail](https://misarmail.com) is a transactional **and** marketing email platform:
one API for the receipts and password resets your product sends, and for the campaigns,
segments and automations your marketing team runs on the same contact list and the same
verified domains. This package is the TypeScript/JavaScript client for that API — a
typed client covering all 43 resource groups, for anything that can run modern
JavaScript with a global `fetch` (Node 18+, Deno, Bun, Cloudflare Workers and other edge
runtimes).

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

## Features

Grouped the way the client exposes them. Every name below is a property on
`MisarMailClient`.

- **Transactional send** — `email.send` with cc/bcc/reply-to, tags, metadata and an
  `idempotency_key`; `sandbox` to list or clear test sends that never leave the building.
- **Campaigns** — `campaigns` list/create/get/update/delete/send; `abTests` for
  subject, content, send-time, from-name and preheader splits, with
  `selectWinner`/`setWinner` by opens, clicks, revenue or conversions.
- **Audience** — `contacts` (list, create, delete, bulk `import`), `segments`
  (create, update, `preview`, `refresh`, `members`), `forms`, `landingPages`, and
  `preferences` for the token-authenticated subscriber preference centre.
- **Content** — `templates` (list, create, `render` with variable substitution),
  `marketplace` (browse, purchase, download, review and publish template listings),
  `drafts`, `labels`, and `ai.subjectLines` for generated subject lines.
- **Automations** — `automations` list/create/get/update/delete/`activate`.
- **Deliverability and sending infrastructure** — `domains` (add, verify DNS, delete),
  `dmarc` (monitored domains and DNS checks), `deliverability`
  (`audit`, `score`, `history`, `playbooks`, `sendTime`), `dedicatedIps`, `warmup`,
  `inbound` domains, and `settings` for signatures, SMTP pools, IP pools, the
  unsubscribe page, whitelabel config and audit logs.
- **Inbox** — `inbox` conversations (list, get, send, snooze, unsubscribe, categorize,
  plus AI `improve`/`reply`/`summarize`), `emails` for stored messages, `emailAccounts`.
- **Analytics and attribution** — `analytics.get` (aggregate, or per-campaign when you
  pass `campaignId`), `track.event`, `track.purchase`, `revenue.attribution`, `usage`.
- **Validation** — `validate.email`, `validate.batch` (max 500 addresses),
  `validate.balance`.
- **Plan, billing and credits** — `plan.get`, `billing`, `wallet`, `subscription`,
  `creditRates`, `teamMembers`, `monetization.recordTip`, `referrals`.
- **Developer** — `keys`, `webhooks` (CRUD plus `test`), `notifications`,
  `integrations`, `streaming`.

## What's in the package

- **`MisarMailClient`** — the one entry point. Every resource hangs off it as a readonly
  property (`mail.contacts`, `mail.campaigns`, …); there is nothing else to construct.
- **Options** — `new MisarMailClient(apiKey, { baseURL, maxRetries, timeoutMs })`.
  Defaults: `baseURL` `https://api.misar.io/mail/v1`, `maxRetries` `3`, `timeoutMs`
  `30_000`.
- **Transport** — `fetch` with an `AbortController` timeout. `429`, `500`, `502`, `503`
  and `504` are retried with exponential backoff (200 ms, 400 ms, 800 ms …), as are
  network failures. A plan refusal is never retried.
- **Errors** — `MisarMailError`, `MisarMailNetworkError`, `MisarMailPlanLimitError`, all
  exported from the package root.
- **SSE streaming** — `mail.streaming.generateEmail()` and
  `mail.streaming.campaignSend()` are async generators; see [Streaming](#streaming).
- **Types** — every request and response interface is exported, so `import type
  { Campaign, Contact, EmailVerificationResult } from "@misarmail/sdk"` works.
- **Packaging** — dual ESM + CJS build with bundled `.d.ts`. No runtime dependencies.
- **No webhook signature verifier.** `mail.webhooks` manages webhook *endpoints*
  (list/create/get/update/delete/test). MisarMail signs deliveries as
  `HMAC-SHA256(timestamp + "." + rawBody)` in the `X-Misar-Signature` header alongside
  `X-Misar-Timestamp`, but this SDK does not ship a helper to check it — verify it
  yourself with `node:crypto` and a constant-time compare. (The Go, Python, Ruby, Dart
  and Flutter SDKs do ship one.)

## Install

```bash
npm install @misarmail/sdk
```

## Auth

Use a MisarMail developer key (`msk_…`), created at
[misarmail.com/developers](https://misarmail.com/developers). It is sent as
`Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer.

## Quick start

```ts
import { MisarMailClient } from "@misarmail/sdk";

const mail = new MisarMailClient(process.env.MISARMAIL_API_KEY!);

const sent = await mail.email.send({
  from: { email: "you@yourdomain.com", name: "Your App" },
  to: [{ email: "someone@example.com" }],
  subject: "Hello",
  html: "<p>Hi there</p>",
});

console.log(sent.message_id);
```

## Primary functions

### Send a transactional email

`from` is a single address object and `to` is an array of them. Pass an
`idempotency_key` and a retry can never send twice — the response comes back with
`idempotent: true` the second time.

```ts
const res = await mail.email.send({
  from: { email: "receipts@yourdomain.com", name: "Acme" },
  to: [{ email: "customer@example.com" }],
  reply_to: { email: "support@yourdomain.com" },
  subject: "Your receipt",
  html: "<p>Thanks for your order.</p>",
  text: "Thanks for your order.",
  tags: ["receipt"],
  metadata: { order_id: "ord-1041" },
  idempotency_key: "ord-1041-receipt",
});

res.message_id; // "msg-…"
```

### List and create contacts

Responses are enveloped. `list()` returns `{ success, data, pagination }`; `create()`
returns `{ success, data }` with the contact under `data`.

```ts
const page = await mail.contacts.list({ page: 1, limit: 50, status: "subscribed" });
console.log(page.data.length, "of", page.pagination.total);

const created = await mail.contacts.create({
  email: "new@example.com",
  firstName: "Ada",
  lastName: "Lovelace",
  tags: ["beta"],
  customFields: { plan: "pro" },
});

console.log(created.data.id);
```

### Bulk import contacts

Up to 5000 rows per call. Counts come back under `summary`, and `errors` is a separate
list of messages.

```ts
const imported = await mail.contacts.import({
  contacts: [
    { email: "a@example.com", firstName: "A" },
    { email: "b@example.com", firstName: "B" },
  ],
  updateExisting: true,
});

console.log(imported.summary); // { imported, updated, skipped, errors }
console.log(imported.errors);  // string[]
```

### Create and send a campaign

Campaigns take `fromName` and `fromEmail` as separate fields — there is no `from` object
here, unlike `email.send`. `send()` queues the campaign and reports it as `scheduled`.

```ts
const campaign = await mail.campaigns.create({
  name: "March launch",
  subject: "We just shipped",
  fromName: "Ada at Acme",
  fromEmail: "hello@yourdomain.com",
  replyTo: "support@yourdomain.com",
  bodyHtml: "<h1>It's live</h1>",
  segmentId: "seg-123",
});

const queued = await mail.campaigns.send(campaign.data.id);
console.log(queued.campaignId, queued.status); // "…", "scheduled"
```

Only `draft`, `scheduled` or `paused` campaigns can be updated, and only `draft`
campaigns can be deleted.

### Validate an address

Each call spends a credit, and the response tells you what is left.

```ts
const check = await mail.validate.email({ email: "someone@example.com" });

check.data.is_valid;          // boolean
check.data.score;             // 0–1 confidence
check.data.checks;            // { syntax, mx, smtp }
check.data.flags.disposable;  // boolean
check.credits.balance_after;  // credits remaining

const bulk = await mail.validate.batch({ emails: ["a@example.com", "b@example.com"] });
console.log(bulk.summary); // { total, valid, invalid, risky, unknown, duration_ms }
```

### Render a template

```ts
const rendered = await mail.templates.render({
  template_id: "tpl-123",
  variables: { name: "Ada", plan: "Pro" },
});

rendered.data.subject; // "Welcome, Ada"
rendered.data.html;
```

### Track events and revenue

The event name field is `event_name`, and purchase totals are integer **cents** in
`total_cents`.

```ts
await mail.track.event({
  email: "customer@example.com",
  event_name: "viewed_pricing",
  event_data: { plan: "pro" },
});

const purchase = await mail.track.purchase({
  email: "customer@example.com",
  order_id: "ord-1041",
  total_cents: 9900,
  currency: "USD",
  items: [{ name: "Pro annual", quantity: 1, price_cents: 9900 }],
});

console.log(purchase.attribution); // which campaign or automation earned it
```

### Read analytics

Without `campaignId` you get aggregate usage and totals for the period; with one you get
that campaign's stats and rates.

```ts
const overall = await mail.analytics.get({ startDate: "2026-04-01", endDate: "2026-04-30" });
const one = await mail.analytics.get({ campaignId: campaign.data.id });
```

### Manage API keys

`keys.list()` returns the keys under **`keys`**, not `data`. `create()` returns the raw
key exactly once — store it immediately.

```ts
const { keys } = await mail.keys.list();

const fresh = await mail.keys.create({
  name: "CI",
  scopes: ["send", "read"],
});
console.log(fresh.key); // shown once and never again
```

## Errors

Three classes, all exported from the package root:

| Class | When |
| --- | --- |
| `MisarMailError` | Any non-2xx API response. Carries `status`, `errorType`, `details`. |
| `MisarMailNetworkError` | The request never got an answer (DNS, socket, timeout). `status` is `0`. |
| `MisarMailPlanLimitError` | The subscription behind the key does not cover the call. |

`MisarMailError` also exposes three getters so you don't have to compare status codes by
hand: `isUnauthorized` (401), `isPlanDenied` (402/403/429) and `isRetryable`
(429 or 5xx).

### Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**, carrying
`code: "plan_limit_exceeded"`. The SDK keys on that code rather than the status, which is
why a refusal is typed correctly even though 403 is otherwise an authorization failure.
It raises `MisarMailPlanLimitError` and **does not retry** — retrying cannot help until
the allowance resets or the plan changes. Read `upgradeUrl` to send the user somewhere
useful.

```ts
import { MisarMailClient, MisarMailPlanLimitError } from "@misarmail/sdk";

try {
  await mail.campaigns.create({
    name: "Blast",
    subject: "Hi",
    fromName: "You",
    fromEmail: "you@yourdomain.com",
  });
} catch (err) {
  if (err instanceof MisarMailPlanLimitError) {
    console.error(`${err.feature} exhausted on ${err.plan}`, err.upgradeUrl, err.retryAfter);
  } else {
    throw err;
  }
}
```

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps), `usage` —
an array with one entry per metered feature, each carrying `used`, `limit` and
`remaining` — and `upgrade`, which is null until a quota is tight. A null `limit` means
unlimited, and `remaining` is null alongside it rather than 0. Read it before an
expensive call rather than discovering the ceiling through a refusal.

The key needs the `read` or `subscription` scope.

```ts
const plan = await mail.plan.get();
console.log(plan.sending, plan.usage);
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1`, which the SDK
handles for you:

| Method | Route |
| --- | --- |
| `streaming.generateEmail` | `POST /api/ai/generate-email/stream` |
| `streaming.campaignSend` | `GET /api/campaigns/{id}/send-stream` |

Frames are unnamed (`data: {…}`, with no `event:` line) and the stream ends with
`data: [DONE]`, which the SDK consumes rather than handing on. A stream is never retried:
replaying one that failed mid-flight would duplicate whatever you had already read.

```ts
for await (const chunk of mail.streaming.generateEmail({ prompt: "a launch email" })) {
  process.stdout.write(chunk.delta ?? "");
}

for await (const progress of mail.streaming.campaignSend(campaign.data.id)) {
  console.log(progress);
}
```

## License

MIT — see [LICENSE](LICENSE).
