# MisarMail TypeScript SDK

> Send transactional email, run campaigns, and manage the whole list — typed, from Node, Deno, Bun or the edge.

[![npm](https://img.shields.io/npm/v/@misarmail/sdk)](https://www.npmjs.com/package/@misarmail/sdk)
[![types](https://img.shields.io/badge/types-included-blue)](https://www.npmjs.com/package/@misarmail/sdk)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**43 resource groups · 179 methods · SSE streaming · zero runtime dependencies**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

Works anywhere with a global `fetch` — Node 18+, Deno, Bun, Cloudflare Workers and other edge runtimes. Dual ESM + CJS build with bundled `.d.ts`; every request and response interface is exported.

---

## Install

### npm

```bash
npm install @misarmail/sdk
```

### pnpm

```bash
pnpm add @misarmail/sdk
```

### yarn

```bash
yarn add @misarmail/sdk
```

### bun

```bash
bun add @misarmail/sdk
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```ts
import { MisarMailClient } from "@misarmail/sdk";

const mail = new MisarMailClient(process.env.MISARMAIL_API_KEY!);
```

---

## Resources

Every group the client exposes, and every public method on it.

### Send

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.email` | `send` | Transactional send — cc/bcc/reply-to, tags, metadata, `idempotency_key`. |
| `mail.sandbox` | `list`, `clear` | Test sends captured instead of delivered. |

### Campaigns and tests

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.campaigns` | `list`, `create`, `get`, `update`, `delete`, `send` | Marketing campaigns: draft, edit, queue for send. |
| `mail.abTests` | `list`, `create`, `selectWinner`, `setWinner` | Subject, content, send-time, from-name and preheader splits, and winner selection. |

### Audience

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.contacts` | `list`, `create`, `delete`, `import` | Subscribers, plus bulk import. |
| `mail.segments` | `list`, `get`, `create`, `update`, `delete`, `preview`, `refresh`, `members` | Dynamic audience segments and their membership. |
| `mail.landingPages` | `list`, `get`, `create`, `update`, `delete` | Hosted landing pages with an email capture form. |
| `mail.forms` | `listForms`, `getForm`, `getFormSubmissions`, `list`, `get`, `create`, `update`, `delete`, `submissions`, `embed` | Signup forms, their embed code and their submissions. |
| `mail.preferences` | `get`, `update` | Token-authenticated subscriber preference centre. |

### Content

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.templates` | `list`, `create`, `render` | Reusable templates and server-side variable rendering. |
| `mail.marketplace` | `listMarketplaceItems`, `getMarketplaceItem`, `list`, `get`, `submitListing`, `download`, `purchase`, `listReviews`, `submitReview`, `recordPremiumPurchase`, `listPremiumPurchases`, `submitCommunityTemplate`, `listSubmissions`, `myListings`, `updateListing` | Template marketplace: browse, buy, download, review, publish. |
| `mail.drafts` | `list`, `create`, `update`, `delete` | Saved drafts. |
| `mail.labels` | `list`, `create`, `delete` | Mailbox labels. |
| `mail.ai` | `subjectLines` | AI-generated subject lines. |

### Automations

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.automations` | `list`, `create`, `get`, `update`, `delete`, `activate` | Trigger-based workflows — welcome series, drips, re-engagement. |

### Deliverability and sending infrastructure

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.domains` | `listDomains`, `addDomain`, `verifyDomain`, `list`, `create`, `get`, `verify`, `delete` | Sending domains and their DNS verification. |
| `mail.dmarc` | `listDomains`, `check`, `addDomain`, `removeDomain` | Live SPF/DKIM/DMARC record checks and monitored domains. |
| `mail.deliverability` | `audit`, `history`, `playbooks`, `score`, `sendTime` | Deliverability score, audit and remediation guidance. |
| `mail.dedicatedIps` | `list`, `get`, `create`, `update` | Dedicated sending IPs. |
| `mail.warmup` | `get` | IP/domain warm-up progress and today's remaining capacity. |
| `mail.inbound` | `list`, `create`, `delete` | Inbound routing domains, so replies land in the unified inbox. |
| `mail.settings` | `listSignatures`, `createSignature`, `updateSignature`, `deleteSignature`, `listSmtpPools`, `upsertSmtpPool`, `deleteSmtpPool`, `listDedicatedIps`, `requestDedicatedIp`, `listDmarcDomains`, `addDmarcDomain`, `deleteDmarcDomain`, `listIpPools`, `createIpPool`, `deleteIpPool`, `getUnsubscribePage`, `updateUnsubscribePage`, `getWhitelabel`, `updateWhitelabel`, `auditLogs` | Signatures, SMTP and IP pools, unsubscribe page, whitelabel, audit logs. |

### Mailbox and inbox

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.emails` | `list`, `get`, `update` | Stored messages in the mailbox. |
| `mail.emailAccounts` | `list` | Connected mailbox accounts. |
| `mail.inbox` | `list`, `get`, `send`, `snooze`, `unsubscribe`, `categorize`, `improve`, `reply`, `summarize` | Unified-inbox conversations, plus AI improve/reply/summarize. |
| `mail.notifications` | `list`, `markRead` | In-app notifications. |

### Analytics and attribution

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.analytics` | `get` | Delivery and engagement stats — aggregate, or one campaign. |
| `mail.track` | `event`, `purchase` | Custom events and ecommerce purchases. |
| `mail.revenue` | `attribution` | Revenue attributed back to email. |
| `mail.usage` | `get` | Metered usage for a period. |

### Validation

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.validate` | `email`, `batch`, `balance` | Address validation, and the credit balance behind it. |

### Plan, billing and credits

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.plan` | `get`, `monetization` | Current plan, quotas and monetization stats. |
| `mail.billing` | `subscription`, `checkout` | Subscription state and checkout. |
| `mail.subscription` | `get`, `planLimits`, `upsert`, `cancel` | Subscription read/write and per-product plan limits. |
| `mail.wallet` | `get`, `debit`, `credit` | Credit balance, credit and debit. |
| `mail.creditRates` | `list` | What each metered action costs in credits. |
| `mail.teamMembers` | `get` | Team members on the account. |
| `mail.monetization` | `recordTip` | Newsletter tips. |
| `mail.referrals` | `stats`, `generate`, `leaderboard`, `logShare`, `milestones`, `milestoneClaims`, `claim`, `nudge` | Referral stats, links, milestones and leaderboard. |

### Developer

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.keys` | `list`, `create`, `delete` | API keys — create, list, revoke. |
| `mail.webhooks` | `list`, `create`, `get`, `update`, `delete`, `test` | Webhook endpoints, plus a test delivery. |
| `mail.integrations` | `listIntegrations`, `getIntegration`, `toggleIntegration` | Third-party integrations and their sync state. |
| `mail.streaming` | `generateEmail`, `campaignSend`, `stream` | The two Server-Sent Events endpoints. |

---

## Client

| Thing | Detail |
| --- | --- |
| Entry point | `new MisarMailClient(apiKey, options?)` — every resource is a readonly property on it. |
| `options.baseURL` | `https://api.misar.io/mail/v1` |
| `options.maxRetries` | `3` |
| `options.timeoutMs` | `30_000` |
| Transport | `fetch` with an `AbortController` timeout. |
| Retried | `429`, `500`, `502`, `503`, `504` and network failures, with 200 ms → 400 ms → 800 ms backoff. |
| Never retried | Plan refusals, and streams. |
| Errors | `MisarMailError`, `MisarMailNetworkError`, `MisarMailPlanLimitError` — all exported from the package root. |
| Webhook verifier | Not shipped here. Verify `HMAC-SHA256(timestamp + "." + rawBody)` from `X-Misar-Signature` yourself with `node:crypto` and a constant-time compare. (Go, Python, Ruby and Dart ship one.) |

---

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

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- npm — https://www.npmjs.com/package/@misarmail/sdk

MIT © [Misar AI](https://misar.io)
