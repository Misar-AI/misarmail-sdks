# MisarMail Rust SDK

> Async Rust client for MisarMail — transactional send, campaigns, deliverability and analytics over reqwest/tokio.

[![crates.io](https://img.shields.io/crates/v/misarmail)](https://crates.io/crates/misarmail)
[![docs.rs](https://img.shields.io/docsrs/misarmail)](https://docs.rs/misarmail)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 92 methods · SSE streaming · typed plan-limit errors**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

An async client over `reqwest`/`tokio` for backends, workers and CLIs. Payloads are `serde_json::Value` in and out — no generated structs, so nothing breaks when the API adds a field.

---

## Install

### cargo add

```bash
cargo add misarmail tokio serde_json
cargo add futures-util   # only if you use the SSE streams
```

### Cargo.toml

```toml
[dependencies]
misarmail = "5.0"
tokio = { version = "1", features = ["full"] }
serde_json = "1"
futures-util = "0.3"   # only for streaming
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```rust
use misarmail::MisarMailClient;

let mail = MisarMailClient::new(&std::env::var("MISARMAIL_API_KEY").unwrap());
```

---

## Resources

Every group the client exposes, and every public method on it.

### Send

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.email` | `send` | Transactional send — cc/bcc/reply-to, tags, metadata, `idempotency_key`. |
| `mail.sandbox` | `send`, `list`, `delete` | Test sends captured instead of delivered. |

### Campaigns and tests

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.campaigns` | `list`, `create`, `get`, `update`, `send_campaign`, `delete` | Marketing campaigns: draft, edit, queue for send. |
| `mail.ab_tests` | `list`, `create`, `get`, `set_winner` | Subject, content, send-time, from-name and preheader splits, and winner selection. |

### Audience

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.contacts` | `list`, `create`, `get`, `update`, `delete`, `import_contacts` | Subscribers, plus bulk import. |
| `mail.segments` | `members` | Dynamic audience segments and their membership. |
| `mail.landing_pages` | `create` | Hosted landing pages with an email capture form. |

### Content

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.templates` | `list`, `create`, `get`, `update`, `delete`, `render` | Reusable templates and server-side variable rendering. |
| `mail.ai` | `subject_lines` | AI-generated subject lines. |

### Automations

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.automations` | `list`, `create`, `get`, `update`, `delete`, `activate` | Trigger-based workflows — welcome series, drips, re-engagement. |

### Deliverability and sending infrastructure

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.domains` | `list`, `create`, `get`, `verify`, `delete` | Sending domains and their DNS verification. |
| `mail.dmarc` | `check`, `list_domains`, `add_domain`, `remove_domain` | Live SPF/DKIM/DMARC record checks and monitored domains. |
| `mail.deliverability` | `audit`, `score` | Deliverability score, audit and remediation guidance. |
| `mail.dedicated_ips` | `list`, `create`, `update`, `delete` | Dedicated sending IPs. |
| `mail.warmup` | `get` | IP/domain warm-up progress and today's remaining capacity. |
| `mail.inbound` | `list`, `create`, `get`, `delete` | Inbound routing domains, so replies land in the unified inbox. |

### Mailbox and inbox

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.emails` | `list`, `get`, `update` | Stored messages in the mailbox. |
| `mail.email_accounts` | `list` | Connected mailbox accounts. |

### Analytics and attribution

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.analytics` | `overview` | Delivery and engagement stats — aggregate, or one campaign. |
| `mail.track` | `event`, `purchase` | Custom events and ecommerce purchases. |
| `mail.revenue` | `attribution` | Revenue attributed back to email. |
| `mail.usage` | `get` | Metered usage for a period. |

### Validation

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.validate` | `email`, `balance` | Address validation, and the credit balance behind it. |

### Plan, billing and credits

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.plan` | `get`, `monetization`, `limits` | Current plan, quotas and monetization stats. |
| `mail.billing` | `subscription`, `checkout` | Subscription state and checkout. |
| `mail.subscription` | `get`, `upsert`, `cancel` | Subscription read/write and per-product plan limits. |
| `mail.wallet` | `get`, `credit`, `debit` | Credit balance, credit and debit. |
| `mail.credit_rates` | `list` | What each metered action costs in credits. |
| `mail.team_members` | `get` | Team members on the account. |
| `mail.monetization` | `tip` | Newsletter tips. |

### Developer

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.keys` | `list`, `create`, `get`, `revoke` | API keys — create, list, revoke. |
| `mail.webhooks` | `list`, `create`, `get`, `update`, `delete`, `test` | Webhook endpoints, plus a test delivery. |
| `mail.streaming` | `generate_email`, `campaign_send` | The two Server-Sent Events endpoints. |

---

## Client

| Thing | Detail |
| --- | --- |
| Entry point | `MisarMailClient::new(api_key)` — every resource is a public field on it. |
| Builder | `.with_base_url(..)`, `.with_api_base(..)`, `.with_max_retries(..)`. |
| Defaults | `https://api.misar.io/mail/v1`, API base `https://api.misar.io/mail`, 3 attempts. |
| Payloads | `serde_json::Value` in, `Value` out. |
| Transport | `reqwest`, 30-second timeout. |
| Retried | `429`, `500`, `502`, `503`, `504` and network failures, 200 ms then 400 ms. |
| Never retried | Plan refusals, and streams. |
| Errors | One `MisarMailError` enum: `Api`, `PlanLimit`, `Network`, `Json`. `err.upgrade_url()` works on any variant. |
| Webhook verifier | Not shipped here — verify `HMAC-SHA256(timestamp + "." + raw_body)` yourself with an HMAC crate and a constant-time compare. (Go, Python, Ruby and Dart ship one.) |

---

## Quick start

```rust
use misarmail::{MisarMailClient, MisarMailError};
use serde_json::json;

#[tokio::main]
async fn main() -> Result<(), MisarMailError> {
    let mail = MisarMailClient::new("msk_your_key");

    let sent = mail.email.send(json!({
        "from": { "email": "you@yourdomain.com", "name": "Your App" },
        "to": [{ "email": "someone@example.com" }],
        "subject": "Hello",
        "html": "<p>Hi there</p>",
    })).await?;

    println!("{}", sent["message_id"]);
    Ok(())
}
```

## Primary functions

### Send a transactional email

`from` is a single address object and `to` is an array of them. Pass an
`idempotency_key` and a retry can never send twice — the response comes back with
`idempotent: true` the second time.

```rust
let res = mail.email.send(json!({
    "from": { "email": "receipts@yourdomain.com", "name": "Acme" },
    "to": [{ "email": "customer@example.com" }],
    "reply_to": { "email": "support@yourdomain.com" },
    "subject": "Your receipt",
    "html": "<p>Thanks for your order.</p>",
    "text": "Thanks for your order.",
    "tags": ["receipt"],
    "metadata": { "order_id": "ord-1041" },
    "idempotency_key": "ord-1041-receipt",
})).await?;

res["message_id"];  // "msg-…"
```

### List and create contacts

Responses are enveloped. `list` returns `{ success, data, pagination }`; `create`
returns `{ success, data }` with the contact under `data`. Pass `Value::Null` to `list`
when you want no filters at all.

```rust
let page = mail.contacts.list(json!({ "page": 1, "limit": 50, "status": "subscribed" })).await?;
println!("{} of {}", page["data"].as_array().map_or(0, Vec::len), page["pagination"]["total"]);

let created = mail.contacts.create(json!({
    "email": "new@example.com",
    "firstName": "Ada",
    "lastName": "Lovelace",
    "tags": ["beta"],
    "customFields": { "plan": "pro" },
})).await?;

println!("{}", created["data"]["id"]);
```

`get` and `delete` take the contact id, which the route reads from the query string
rather than a path segment. `update` is different again: it identifies the contact by
**email address**, not by id — `mail.contacts.update("ada@example.com", json!({ "status": "unsubscribed" }))`.

### Bulk import contacts

Counts come back under `summary`, and `errors` is a separate list of messages.

```rust
let imported = mail.contacts.import_contacts(json!({
    "contacts": [
        { "email": "a@example.com", "firstName": "A" },
        { "email": "b@example.com", "firstName": "B" },
    ],
    "updateExisting": true,
})).await?;

imported["summary"];  // { imported, updated, skipped, errors }
imported["errors"];   // array of strings
```

### Create and send a campaign

Campaigns take `fromName` and `fromEmail` as separate fields — there is no `from` object
here, unlike `email.send`. `send_campaign` queues it and reports it as `scheduled`.

```rust
let campaign = mail.campaigns.create(json!({
    "name": "March launch",
    "subject": "We just shipped",
    "fromName": "Ada at Acme",
    "fromEmail": "hello@yourdomain.com",
    "replyTo": "support@yourdomain.com",
    "bodyHtml": "<h1>It's live</h1>",
    "segmentId": "seg-123",
})).await?;

let id = campaign["data"]["id"].as_str().unwrap_or_default();
let queued = mail.campaigns.send_campaign(id).await?;
println!("{} {}", queued["campaignId"], queued["status"]);  // "…" "scheduled"
```

Only `draft`, `scheduled` or `paused` campaigns can be updated, and only `draft`
campaigns can be deleted.

### Validate an address

Each call spends a credit, and the response tells you what is left. There is no batch
method in this crate — call `email` per address, or post to `/validate` yourself with an
`emails` array.

```rust
let check = mail.validate.email("someone@example.com").await?;

check["data"]["is_valid"];         // bool
check["data"]["score"];            // 0–1 confidence
check["data"]["checks"];           // { syntax, mx, smtp }
check["data"]["flags"]["disposable"];
check["credits"]["balance_after"]; // credits remaining
```

### Render a template

```rust
let rendered = mail.templates.render(json!({
    "template_id": "tpl-123",
    "variables": { "name": "Ada", "plan": "Pro" },
})).await?;

rendered["data"]["subject"];  // "Welcome, Ada"
rendered["data"]["html"];
```

### Track events and revenue

The event name field is `event_name`, and purchase totals are integer **cents** in
`total_cents`.

```rust
mail.track.event(json!({
    "email": "customer@example.com",
    "event_name": "viewed_pricing",
    "event_data": { "plan": "pro" },
})).await?;

let purchase = mail.track.purchase(json!({
    "email": "customer@example.com",
    "order_id": "ord-1041",
    "total_cents": 9900,
    "currency": "USD",
    "items": [{ "name": "Pro annual", "quantity": 1, "price_cents": 9900 }],
})).await?;

purchase["attribution"];  // which campaign or automation earned it
```

### Read analytics and list keys

Without `campaignId` you get aggregate usage and totals for the period; with one you get
that campaign's stats and rates. `keys.list()` returns the keys under **`keys`**, not
`data`, and `create` returns the raw key exactly once.

```rust
let overall = mail.analytics.overview(json!({ "startDate": "2026-04-01", "endDate": "2026-04-30" })).await?;
let one = mail.analytics.overview(json!({ "campaignId": id })).await?;

let listed = mail.keys.list().await?;
listed["keys"];

let fresh = mail.keys.create(json!({ "name": "CI", "scopes": ["send", "read"] })).await?;
fresh["key"];  // shown once and never again
```

## Errors

Every method returns `Result<Value, MisarMailError>`. The enum has four variants:

| Variant | When |
| --- | --- |
| `MisarMailError::Api { status, message }` | Any non-2xx API response. |
| `MisarMailError::PlanLimit { status, message, plan, upgrade_url, retry_after, feature }` | The subscription behind the key does not cover the call. |
| `MisarMailError::Network(reqwest::Error)` | The request never got an answer (DNS, socket, timeout). |
| `MisarMailError::Json(serde_json::Error)` | A 2xx body that was not valid JSON. |

`err.upgrade_url()` returns the pricing URL for a `PlanLimit` and `None` for everything
else, so you can offer an upgrade without matching on the variant.

### Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**, carrying
`code: "plan_limit_exceeded"`. The SDK keys on that code rather than the status, which is
why a refusal is typed correctly even though 403 is otherwise an authorization failure.
It returns `MisarMailError::PlanLimit` and **does not retry** — retrying cannot help
until the allowance resets or the plan changes. Read `upgrade_url` to send the user
somewhere useful.

```rust
match mail.campaigns.create(json!({
    "name": "Blast",
    "subject": "We just shipped",
    "fromName": "Your Name",
    "fromEmail": "you@yourdomain.com",
})).await {
    Err(MisarMailError::PlanLimit { feature, plan, upgrade_url, .. }) => {
        eprintln!("{feature:?} exhausted on {plan:?}: {upgrade_url:?}");
    }
    other => { other?; }
}
```

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps), `usage` —
an array with one entry per metered feature, each carrying `used`, `limit` and
`remaining` — and `upgrade`, which is null until a quota is tight. A null `limit` means
unlimited, and `remaining` is null alongside it rather than 0. Read it before an
expensive call rather than discovering the ceiling through a refusal.

The key needs the `read` or `subscription` scope.

```rust
let plan = mail.plan.get().await?;
println!("{} {}", plan["sending"], plan["usage"]);
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1`, which the SDK
handles for you by using the API base:

| Method | Route |
| --- | --- |
| `streaming.generate_email` | `POST /api/ai/generate-email/stream` |
| `streaming.campaign_send` | `GET /api/campaigns/{id}/send-stream` |

Frames are unnamed (`data: {…}`, with no `event:` line) and the stream ends with
`data: [DONE]`, which the SDK consumes rather than handing on. A stream is never retried:
replaying one that failed mid-flight would duplicate whatever you had already read. A
plan refusal on open surfaces as `MisarMailError::PlanLimit`, exactly as for a
non-streaming call.

```rust
use futures_util::StreamExt;

let mut stream = mail.streaming.generate_email(json!({ "prompt": "a launch email" })).await?;
while let Some(frame) = stream.next().await {
    let frame = frame?;
    print!("{}", frame.data["delta"].as_str().unwrap_or(""));
}

let mut progress = mail.streaming.campaign_send(&campaign_id).await?;
while let Some(frame) = progress.next().await {
    println!("{}", frame?.data);
}
```

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- crates.io — https://crates.io/crates/misarmail

MIT © [Misar AI](https://misar.io)
