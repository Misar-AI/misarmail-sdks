# MisarMail Kotlin SDK

> Send transactional email and run marketing campaigns from Kotlin — suspend functions and Flow-based SSE.

[![Maven Central](https://img.shields.io/badge/maven--central-io.misar%3Amisarmail--kotlin-blue)](https://central.sonatype.com/artifact/io.misar/misarmail-kotlin)
[![kotlin](https://img.shields.io/badge/kotlin-1.9%2B-7F52FF)](https://central.sonatype.com/artifact/io.misar/misarmail-kotlin)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 90 suspend functions · Flow-based SSE streaming**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

JVM toolchain 17, built on `java.net.http` with coroutines and Jackson. Every call is a `suspend fun`; both streams return a `Flow<StreamEvent>`.

---

## Install

### Gradle (Kotlin DSL)

```kotlin
implementation("io.misar:misarmail-kotlin:5.0.1")
```

### Gradle (Groovy)

```groovy
implementation 'io.misar:misarmail-kotlin:5.0.1'
```

### Maven

```xml
<dependency>
  <groupId>io.misar</groupId>
  <artifactId>misarmail-kotlin</artifactId>
  <version>5.0.1</version>
</dependency>
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```kotlin
val mail = MisarMailClient(System.getenv("MISARMAIL_API_KEY"))
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
| `mail.abTests` | `list`, `create`, `get`, `setWinner` | Subject, content, send-time, from-name and preheader splits, and winner selection. |

### Audience

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.contacts` | `list`, `create`, `get`, `update`, `delete`, `importContacts` | Subscribers, plus bulk import. |
| `mail.segments` | `members` | Dynamic audience segments and their membership. |
| `mail.landingPages` | `create` | Hosted landing pages with an email capture form. |

### Content

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.templates` | `list`, `create`, `get`, `update`, `delete`, `render` | Reusable templates and server-side variable rendering. |
| `mail.ai` | `subjectLines` | AI-generated subject lines. |

### Automations

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.automations` | `list`, `create`, `get`, `update`, `delete`, `activate` | Trigger-based workflows — welcome series, drips, re-engagement. |

### Deliverability and sending infrastructure

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.domains` | `list`, `create`, `get`, `verify`, `delete` | Sending domains and their DNS verification. |
| `mail.dmarc` | `check`, `listDomains`, `addDomain`, `removeDomain` | Live SPF/DKIM/DMARC record checks and monitored domains. |
| `mail.deliverability` | `audit`, `score` | Deliverability score, audit and remediation guidance. |
| `mail.dedicatedIps` | `list`, `create`, `update`, `delete` | Dedicated sending IPs. |
| `mail.warmup` | `get` | IP/domain warm-up progress and today's remaining capacity. |
| `mail.inbound` | `list`, `create`, `get`, `delete` | Inbound routing domains, so replies land in the unified inbox. |

### Mailbox and inbox

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.emails` | `list`, `get`, `update` | Stored messages in the mailbox. |
| `mail.emailAccounts` | `list` | Connected mailbox accounts. |

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
| `mail.creditRates` | `list` | What each metered action costs in credits. |
| `mail.teamMembers` | `get` | Team members on the account. |
| `mail.monetization` | `tip` | Newsletter tips. |

### Developer

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.keys` | `list`, `create`, `get`, `revoke` | API keys — create, list, revoke. |
| `mail.webhooks` | `list`, `create`, `get`, `update`, `delete`, `test` | Webhook endpoints, plus a test delivery. |
| `mail.streaming` | `generateEmail`, `campaignSend` | The two Server-Sent Events endpoints. |

---

## Client

| Thing | Detail |
| --- | --- |
| Entry point | `MisarMailClient(apiKey)` — every resource is a `val` on it. |
| Base URL | `https://api.misar.io/mail/v1` |
| Calls | `suspend fun`, returning `Map<String, Any>`. |
| Streams | `Flow<StreamEvent>`. |
| Retried | `429`, `500`, `502`, `503`, `504` and transport failures, with exponential backoff. |
| Never retried | Plan refusals, and streams. |
| Errors | `MisarMailException`, with `PlanLimitException` extending it. |

---

## Quick start

```kotlin
val mail = MisarMailClient("msk_your_key")

mail.email.send(mapOf(
    "from" to mapOf("email" to "you@yourdomain.com"),
    "to" to listOf(mapOf("email" to "someone@example.com")),
    "subject" to "Hello",
    "html" to "<p>Hi there</p>",
))

val contacts = mail.contacts.list()
```

## Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**,
carrying `code: "plan_limit_exceeded"`. The SDK keys on that code rather than
the status, which is why a refusal is typed correctly even though 403 is
otherwise an authorization failure. The SDK raises
`PlanLimitException` for either, and **does not retry** it — retrying cannot
help until the allowance resets or the plan changes. Read `upgradeUrl` to
send the user somewhere useful.

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps),
`usage` — an array with one entry per metered feature, each carrying `used`,
`limit` and `remaining` — and `upgrade`, which is null until a quota is tight.
A null `limit` means unlimited, and `remaining` is null alongside it rather than
0. Read it before an expensive call rather than discovering the ceiling through
a refusal.

The key needs the `read` or `subscription` scope.

```kotlin
val plan = mail.plan.get()

try {
    mail.campaigns.create(mapOf(
        "name" to "Blast", "subject" to "We just shipped",
        "fromName" to "Your Name", "fromEmail" to "you@yourdomain.com",
    ))
} catch (e: PlanLimitException) {
    println("${e.feature} exhausted on ${e.plan}: ${e.upgradeUrl}")
}
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1`, which the
SDK handles for you:

| Method | Route |
| --- | --- |
| `streaming.generateEmail` | `POST /api/ai/generate-email/stream` |
| `streaming.campaignSend` | `GET /api/campaigns/{id}/send-stream` |

Frames are unnamed (`data: {…}`) and the stream ends with `data: [DONE]`, which
the SDK consumes rather than handing on. A stream is never retried: replaying one
that failed mid-flight would duplicate whatever you had already read.

```kotlin
mail.streaming.generateEmail(mapOf("prompt" to "a launch email"))
    .collect { print(it.data?.get("delta")) }
```

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- Maven Central — https://central.sonatype.com/artifact/io.misar/misarmail-kotlin

MIT © [Misar AI](https://misar.io)
