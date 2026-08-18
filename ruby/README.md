# MisarMail Ruby SDK

> Send transactional email and run marketing campaigns from Ruby — one client, no runtime dependencies.

[![gem](https://img.shields.io/gem/v/misarmail)](https://rubygems.org/gems/misarmail)
[![ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7-CC342D)](https://rubygems.org/gems/misarmail)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 90 methods · SSE streaming · webhook signature verification**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

Built on `net/http` with nothing outside the standard library, for Ruby 2.7+. Every method returns a plain `Hash` with string keys, so nothing breaks when the API adds a field.

---

## Install

### RubyGems

```bash
gem install misarmail
```

### Bundler

```ruby
gem "misarmail", "~> 1.0"
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```ruby
require "misar_mail"

mail = MisarMail::Client.new(api_key: ENV.fetch("MISARMAIL_API_KEY"))
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
| `mail.campaigns` | `list`, `create`, `get`, `update`, `send`, `delete` | Marketing campaigns: draft, edit, queue for send. |
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
| `mail.validate` | `email` | Address validation, and the credit balance behind it. |

### Plan, billing and credits

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.plan` | `get`, `monetization` | Current plan, quotas and monetization stats. |
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
| Entry point | `MisarMail::Client.new(api_key:, timeout: 30, max_retries: 3, base_url:)`. `MisarMail.new(**kwargs)` is a shorthand. |
| `base_url` | `https://api.misar.io/mail/v1` |
| Results | A `Hash` with **string** keys. `204`/empty comes back as `{}`; a top-level array is wrapped as `{"data" => [...]}`. |
| Transport | `net/http`, 10-second open timeout, your `timeout` for reads. |
| Retried | `429`, `500`, `502`, `503`, `504`, plus `Net::OpenTimeout`, `Net::ReadTimeout`, `Errno::ECONNREFUSED`, `Errno::ECONNRESET` and `SocketError` — 300 ms then 600 ms. |
| Never retried | Plan refusals, and streams. |
| Errors | `MisarMail::ApiError`, with `NetworkError` and `PlanLimitError` extending it. |
| Webhook verifier | `MisarMail::Webhooks.verify` / `.sign`. |
| Escape hatch | `mail.request(:get, path)` is public, for routes with no method yet. |

---

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

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- RubyGems — https://rubygems.org/gems/misarmail

MIT © [Misar AI](https://misar.io)
