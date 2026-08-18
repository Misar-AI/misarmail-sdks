# MisarMail Ruby SDK

[MisarMail](https://misarmail.com) is a transactional **and** marketing email platform:
one API for the receipts and password resets your product sends, and for the campaigns,
segments and automations your marketing team runs on the same contact list and the same
verified domains. This gem is the Ruby client for that API — 33 resource groups on one
client object, built on `net/http` with no runtime dependencies beyond the standard
library.

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

## Features

Grouped the way the client exposes them. Every name below is a reader on
`MisarMail::Client`.

- **Transactional send** — `email.send`; `sandbox` (`send`, `list`, `delete`) for test
  sends that never leave the building.
- **Campaigns** — `campaigns` `list`/`create`/`get`/`update`/`send`/`delete`; `ab_tests`
  `list`/`create`/`get`/`set_winner`.
- **Audience** — `contacts` (`list`, `create`, `get`, `update`, `delete`,
  `import_contacts`) and `segments.members`.
- **Content** — `templates` (`list`, `create`, `get`, `update`, `delete`, `render`),
  `landing_pages.create`, and `ai.subject_lines` for generated subject lines.
- **Automations** — `automations` `list`/`create`/`get`/`update`/`delete`/`activate`.
- **Deliverability and sending infrastructure** — `domains` (add, `verify`, delete),
  `dmarc` (`check`, `list_domains`, `add_domain`, `remove_domain`), `deliverability`
  (`audit`, `score`), `dedicated_ips`, `warmup.get`, `inbound` addresses.
- **Mailbox** — `emails` (`list`, `get`, `update`), `email_accounts.list`.
- **Analytics and attribution** — `analytics.overview` (aggregate, or per-campaign when
  you pass `campaignId`), `track.event`, `track.purchase`, `revenue.attribution`,
  `usage.get`.
- **Validation** — `validate.email` for one address at a time.
- **Plan, billing and credits** — `plan` (`get`, `monetization`), `billing`
  (`subscription`, `checkout`), `subscription` (`get`, `upsert`, `cancel`), `wallet`
  (`get`, `credit`, `debit`), `credit_rates.list`, `team_members.get`,
  `monetization.tip`.
- **Developer** — `keys` (`list`, `create`, `get`, `revoke`), `webhooks` (CRUD plus
  `test`), `streaming`, and `MisarMail::Webhooks` for verifying inbound deliveries.

Narrower than the TypeScript SDK, which is the reference implementation: forms, labels,
drafts, marketplace, inbox conversations, preferences, referrals, notifications,
integrations and workspace settings have no Ruby methods yet, `segments.members` is the
only segments call, and there is no batch address validation. `mail.request(:get, path)`
is public if you need to reach one of those routes.

## What's in the package

- **`MisarMail::Client`** — the one entry point. Every resource is a reader on it
  (`mail.contacts`, `mail.campaigns`, …); there is nothing else to construct.
  `MisarMail.new(**kwargs)` is a shorthand for `MisarMail::Client.new`.
- **Options** — `MisarMail::Client.new(api_key:, timeout: 30, max_retries: 3, base_url:)`.
  `base_url` defaults to `https://api.misar.io/mail/v1` and is for tests and self-hosted
  deployments.
- **Payloads and results** — requests take keyword/hash payloads and every method returns
  a `Hash` with **string** keys. There are no model classes, so nothing breaks when the
  API adds a field. A `204` or an empty body comes back as `{}`; a top-level JSON array
  is wrapped as `{"data" => [...]}`.
- **Transport** — `net/http` with a 10-second open timeout and your `timeout` for reads.
  `429`, `500`, `502`, `503` and `504` are retried with exponential backoff (300 ms, then
  600 ms), as are `Net::OpenTimeout`, `Net::ReadTimeout`, `Errno::ECONNREFUSED`,
  `Errno::ECONNRESET` and `SocketError`. A plan refusal is never retried.
- **Errors** — `MisarMail::ApiError`, with `MisarMail::NetworkError` and
  `MisarMail::PlanLimitError` extending it.
- **SSE streaming** — `mail.streaming.generate_email` and `campaign_send` yield a
  `MisarMail::StreamEvent` per frame, or return an `Enumerator` with no block; see
  [Streaming](#streaming).
- **Webhook signature verification** — `MisarMail::Webhooks.verify` and `.sign`. Unlike
  the C#, PHP, Rust and Swift SDKs, this one ships the verifier.

## Install

```bash
gem install misarmail
```

Or in a Gemfile:

```ruby
gem "misarmail", "~> 1.0"
```

## Auth

Use a MisarMail developer key (`msk_…`), created at
[misarmail.com/developers](https://misarmail.com/developers). It is sent as
`Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer.

## Quick start

```ruby
require "misar_mail"

mail = MisarMail::Client.new(api_key: ENV.fetch("MISARMAIL_API_KEY"))

sent = mail.email.send(
  from: { email: "you@yourdomain.com", name: "Your App" },
  to: [{ email: "someone@example.com" }],
  subject: "Hello",
  html: "<p>Hi there</p>"
)

puts sent["message_id"]
```

## Primary functions

### Send a transactional email

`from` is a single address hash and `to` is an array of them. Pass an `idempotency_key`
and a retry can never send twice — the response comes back with `idempotent: true` the
second time.

```ruby
res = mail.email.send(
  from: { email: "receipts@yourdomain.com", name: "Acme" },
  to: [{ email: "customer@example.com" }],
  reply_to: { email: "support@yourdomain.com" },
  subject: "Your receipt",
  html: "<p>Thanks for your order.</p>",
  text: "Thanks for your order.",
  tags: ["receipt"],
  metadata: { order_id: "ord-1041" },
  idempotency_key: "ord-1041-receipt"
)

res["message_id"]  # "msg-…"
```

### List and create contacts

Responses are enveloped. `list` returns `{"success", "data", "pagination"}` and takes
`page:`/`limit:` keywords rather than a params hash; `create` returns
`{"success", "data"}` with the contact under `data`.

```ruby
page = mail.contacts.list(page: 1, limit: 50)
puts "#{page['data'].length} of #{page['pagination']['total']}"

created = mail.contacts.create(
  email: "new@example.com",
  firstName: "Ada",
  lastName: "Lovelace",
  tags: ["beta"],
  customFields: { plan: "pro" }
)

puts created["data"]["id"]
```

`get` and `delete` take the contact id, which the route reads from the query string
rather than a path segment. `update` is different again: it identifies the contact by
**email address**, not by id.

```ruby
mail.contacts.update("ada@example.com", status: "unsubscribed")
```

### Bulk import contacts

The method is `import_contacts` — `import` is not defined. Counts come back under
`summary`, and `errors` is a separate list of messages.

```ruby
imported = mail.contacts.import_contacts(
  contacts: [
    { email: "a@example.com", firstName: "A" },
    { email: "b@example.com", firstName: "B" }
  ],
  updateExisting: true
)

imported["summary"]  # {"imported"=>…, "updated"=>…, "skipped"=>…, "errors"=>…}
imported["errors"]   # array of strings
```

### Create and send a campaign

Campaigns take `fromName` and `fromEmail` as separate fields — there is no `from` hash
here, unlike `email.send`. `campaigns.send(id)` queues the campaign and reports it as
`scheduled`.

```ruby
campaign = mail.campaigns.create(
  name: "March launch",
  subject: "We just shipped",
  fromName: "Ada at Acme",
  fromEmail: "hello@yourdomain.com",
  replyTo: "support@yourdomain.com",
  bodyHtml: "<h1>It's live</h1>",
  segmentId: "seg-123"
)

queued = mail.campaigns.send(campaign["data"]["id"])
puts "#{queued['campaignId']} #{queued['status']}"  # … scheduled
```

Only `draft`, `scheduled` or `paused` campaigns can be updated, and only `draft`
campaigns can be deleted.

### Validate an address

Each call spends a credit, and the response tells you what is left.

```ruby
check = mail.validate.email("someone@example.com")

check["data"]["is_valid"]             # true / false
check["data"]["score"]                # 0–1 confidence
check["data"]["checks"]               # {"syntax"=>…, "mx"=>…, "smtp"=>…}
check["data"]["flags"]["disposable"]
check["credits"]["balance_after"]     # credits remaining
```

### Render a template

```ruby
rendered = mail.templates.render(
  template_id: "tpl-123",
  variables: { name: "Ada", plan: "Pro" }
)

rendered["data"]["subject"]  # "Welcome, Ada"
rendered["data"]["html"]
```

### Track events and revenue

The event name field is `event_name`, and purchase totals are integer **cents** in
`total_cents`.

```ruby
mail.track.event(
  email: "customer@example.com",
  event_name: "viewed_pricing",
  event_data: { plan: "pro" }
)

purchase = mail.track.purchase(
  email: "customer@example.com",
  order_id: "ord-1041",
  total_cents: 9900,
  currency: "USD",
  items: [{ name: "Pro annual", quantity: 1, price_cents: 9900 }]
)

purchase["attribution"]  # which campaign or automation earned it
```

### Read analytics and manage keys

Without `campaignId` you get aggregate usage and totals for the period; with one you get
that campaign's stats and rates. `keys.list` returns the keys under **`keys`**, not
`data`, and `create` returns the raw key exactly once.

```ruby
overall = mail.analytics.overview(startDate: "2026-04-01", endDate: "2026-04-30")
one = mail.analytics.overview(campaignId: campaign_id)

keys = mail.keys.list
keys["keys"].length

fresh = mail.keys.create(name: "CI", scopes: %w[send read])
puts fresh["key"]  # shown once and never again
```

### Verify an inbound webhook

MisarMail signs each delivery as `HMAC-SHA256(timestamp + "." + raw_body)`, sending the
digest in `X-Misar-Signature` and the Unix timestamp in `X-Misar-Timestamp`. Verify
against the **raw** request body — re-serializing the parsed hash changes key order and
whitespace, and so changes the digest. `verify` compares in constant time, rejects
timestamps older than 300 seconds by default, and returns `false` rather than raising on
malformed input.

```ruby
ok = MisarMail::Webhooks.verify(
  payload: request.raw_post,
  signature: request.headers["X-Misar-Signature"],
  timestamp: request.headers["X-Misar-Timestamp"],
  secret: ENV.fetch("MISARMAIL_WEBHOOK_SECRET"),
  tolerance: 300
)
head :bad_request unless ok
```

`MisarMail::Webhooks.sign(payload, timestamp, secret)` produces the same digest, which is
what you want when testing your own consumer.

## Errors

Three classes, all under `MisarMail`:

| Class | When |
| --- | --- |
| `ApiError` | Any non-2xx API response. Carries `status` and `error_type`. |
| `NetworkError` | The request never got an answer, or every retry was spent. `status` is `0`. |
| `PlanLimitError` | The subscription behind the key does not cover the call. |

`NetworkError` and `PlanLimitError` both subclass `ApiError`, so
`rescue MisarMail::ApiError` catches everything the SDK raises.

### Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**, carrying
`code: "plan_limit_exceeded"`. The SDK keys on that code rather than the status, which is
why a refusal is typed correctly even though 403 is otherwise an authorization failure.
It raises `PlanLimitError` and **does not retry** — retrying cannot help until the
allowance resets or the plan changes. Read `upgrade_url` to send the user somewhere
useful.

```ruby
begin
  mail.campaigns.create(
    name: "Blast", subject: "We just shipped",
    fromName: "Your Name", fromEmail: "you@yourdomain.com"
  )
rescue MisarMail::PlanLimitError => e
  warn "#{e.feature} exhausted on #{e.plan}: #{e.upgrade_url}"
  # e.retry_after is seconds until the allowance resets, when the API says so
end
```

`mail.plan.get` returns `plan`, `sending` (the per-day and per-month email caps), `usage`
— an array with one entry per metered feature, each carrying `used`, `limit` and
`remaining` — and `upgrade`, which is null until a quota is tight. A null `limit` means
unlimited, and `remaining` is null alongside it rather than 0. Read it before an
expensive call rather than discovering the ceiling through a refusal.

The key needs the `read` or `subscription` scope.

```ruby
plan = mail.plan.get
p plan["sending"]
p plan["usage"]
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1`, which the SDK
handles for you:

| Method | Route |
| --- | --- |
| `streaming.generate_email` | `POST /api/ai/generate-email/stream` |
| `streaming.campaign_send` | `GET /api/campaigns/{id}/send-stream` |

Frames are unnamed (`data: {…}`, with no `event:` line) and the stream ends with
`data: [DONE]`, which the SDK consumes rather than handing on. Each `StreamEvent` carries
`event` (normally nil), `data` (the parsed hash, or nil when the payload was not JSON)
and `raw`. Without a block you get an `Enumerator` instead. A stream is never retried:
replaying one that failed mid-flight would duplicate whatever you had already read.

Note that streaming always talks to `https://api.misar.io/mail` — unlike the other
methods it does not follow the `base_url:` you passed the client.

```ruby
mail.streaming.generate_email(prompt: "a launch email") do |event|
  print event.data["delta"]
end

mail.streaming.campaign_send(campaign_id) do |event|
  puts event.raw
end
```

## License

MIT — see [LICENSE](LICENSE).
