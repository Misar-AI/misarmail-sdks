# MisarMail Python SDK

> Send transactional email and run marketing campaigns from Python — sync and async, from the same client.

[![PyPI](https://img.shields.io/pypi/v/misarmail)](https://pypi.org/project/misarmail/)
[![python](https://img.shields.io/pypi/pyversions/misarmail)](https://pypi.org/project/misarmail/)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 91 methods · 89 async mirrors · SSE streaming**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

Every resource method has an `a`-prefixed async twin (`contacts.list` / `contacts.alist`) on the same client, so sync and async code share one object. Python 3.9+, `httpx` the only runtime dependency.

---

## Install

### pip

```bash
pip install misarmail
```

### uv

```bash
uv add misarmail
```

### With the WebSocket extra

```bash
pip install 'misarmail[websocket]'
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```python
import os
from misarmail import MisarMailClient

mail = MisarMailClient(os.environ["MISARMAIL_API_KEY"])
```

---

## Resources

Every group the client exposes, and every public method on it. Each method also has an `a`-prefixed async twin — `contacts.list` / `contacts.alist` — except the two streams.

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
| `mail.plan` | `get`, `limits`, `monetization` | Current plan, quotas and monetization stats. |
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
| Entry point | `MisarMailClient(api_key, base_url=…, max_retries=3, timeout=30)` — every resource is an attribute on it. |
| `base_url` | `https://api.misar.io/mail/v1` |
| Async | `await mail.contacts.alist()` — an `a`-prefixed mirror of every method except the two streams. |
| Transport | `httpx`. |
| Retried | `429`, `500`, `502`, `503`, `504` and network failures, with exponential backoff from 200 ms. |
| Never retried | Plan refusals, and streams. |
| Errors | `MisarMailError`, `MisarMailNetworkError` (package root); `MisarMailPlanLimitError` (`misarmail.errors`). |
| Also exported | `McpClient`, `MisarMailSocket`, `verify_webhook_signature`. |

---

## Quick start

```python
from misarmail import MisarMailClient
from misarmail.errors import MisarMailPlanLimitError

mail = MisarMailClient("msk_your_key")

mail.email.send({
    "from": {"email": "you@yourdomain.com"},
    "to": [{"email": "someone@example.com"}],
    "subject": "Hello",
    "html": "<p>Hi there</p>",
})

contacts = mail.contacts.list(page=1, limit=50)
campaign = mail.campaigns.create({
    "name": "Launch",
    "subject": "We just shipped",
    "fromName": "Your Name",
    "fromEmail": "you@yourdomain.com",
})
```

## Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**,
carrying `code: "plan_limit_exceeded"`. The SDK keys on that code rather than
the status, which is why a refusal is typed correctly even though 403 is
otherwise an authorization failure. The SDK raises
`MisarMailPlanLimitError` for either, and **does not retry** it — retrying cannot
help until the allowance resets or the plan changes. Read `upgrade_url` to
send the user somewhere useful.

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps),
`usage` — an array with one entry per metered feature, each carrying `used`,
`limit` and `remaining` — and `upgrade`, which is null until a quota is tight.
A null `limit` means unlimited, and `remaining` is null alongside it rather than
0. Read it before an expensive call rather than discovering the ceiling through
a refusal.

The key needs the `read` or `subscription` scope.

```python
plan = mail.plan.get()
print(plan["sending"], plan["usage"])   # usage is a list, one entry per metered feature

try:
    mail.campaigns.create({"name": "Blast", "subject": "Hi",
                           "fromName": "You", "fromEmail": "you@yourdomain.com"})
except MisarMailPlanLimitError as e:
    print(f"{e.feature} exhausted on {e.plan}", e.upgrade_url)
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1`, which the
SDK handles for you:

| Method | Route |
| --- | --- |
| `streaming.generate_email` | `POST /api/ai/generate-email/stream` |
| `streaming.campaign_send` | `GET /api/campaigns/{id}/send-stream` |

Frames are unnamed (`data: {…}`) and the stream ends with `data: [DONE]`, which
the SDK consumes rather than handing on. A stream is never retried: replaying one
that failed mid-flight would duplicate whatever you had already read.

```python
for chunk in mail.streaming.generate_email(prompt="a launch email"):
    print(chunk.get("delta", ""), end="")

for progress in mail.streaming.campaign_send(campaign["data"]["id"]):
    print(progress)
```

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- PyPI — https://pypi.org/project/misarmail/

MIT © [Misar AI](https://misar.io)
