# MisarMail Java SDK

> Send transactional email and run marketing campaigns from Java 17 — blocking or CompletableFuture, from one client.

[![Maven Central](https://img.shields.io/maven-central/v/io.misar/misarmail)](https://central.sonatype.com/artifact/io.misar/misarmail)
[![java](https://img.shields.io/badge/java-17%2B-007396)](https://central.sonatype.com/artifact/io.misar/misarmail)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 90 methods · 62 async mirrors · SSE streaming**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

Java 17+ on `java.net.http` with Jackson. The first seventeen resource groups also expose a `…Async` mirror returning `CompletableFuture<Map<String, Object>>`.

---

## Install

### Maven

```xml
<dependency>
  <groupId>io.misar</groupId>
  <artifactId>misarmail</artifactId>
  <version>5.0.3</version>
</dependency>
```

### Gradle (Kotlin DSL)

```kotlin
implementation("io.misar:misarmail:5.0.3")
```

### Gradle (Groovy)

```groovy
implementation 'io.misar:misarmail:5.0.3'
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```java
MisarMailClient mail = new MisarMailClient.Builder(System.getenv("MISARMAIL_API_KEY")).build();
```

---

## Resources

Every group the client exposes, and every public method on it. The groups from `email` through `billing` also expose a `…Async` mirror of each method returning `CompletableFuture<Map<String, Object>>`.

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
| Entry point | `new MisarMailClient.Builder(apiKey).build()` — every resource is a public final field. |
| Builder options | `.baseUrl(..)`, `.apiBase(..)`, `.maxRetries(..)`, `.httpClient(..)`. |
| Base URL | `https://api.misar.io/mail/v1` |
| Async | `contacts.listAsync(..)` → `CompletableFuture<Map<String, Object>>`. |
| Results | `Map<String, Object>`, decoded with Jackson. |
| Retried | `429`, `500`, `502`, `503`, `504` and transport failures, with exponential backoff. |
| Never retried | Plan refusals, and streams. |
| Errors | `MisarMailException`, with `PlanLimitException` extending it. |

---

## Quick start

```java
MisarMailClient mail = new MisarMailClient.Builder("msk_your_key").build();

mail.email.send(Map.of(
    "from", Map.of("email", "you@yourdomain.com"),
    "to", List.of(Map.of("email", "someone@example.com")),
    "subject", "Hello",
    "html", "<p>Hi there</p>"
));

Map<String, Object> contacts = mail.contacts.list(Map.of("page", 1));
```

## Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**,
carrying `code: "plan_limit_exceeded"`. The SDK keys on that code rather than
the status, which is why a refusal is typed correctly even though 403 is
otherwise an authorization failure. The SDK raises
`PlanLimitException` for either, and **does not retry** it — retrying cannot
help until the allowance resets or the plan changes. Read `getUpgradeUrl()` to
send the user somewhere useful.

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps),
`usage` — an array with one entry per metered feature, each carrying `used`,
`limit` and `remaining` — and `upgrade`, which is null until a quota is tight.
A null `limit` means unlimited, and `remaining` is null alongside it rather than
0. Read it before an expensive call rather than discovering the ceiling through
a refusal.

The key needs the `read` or `subscription` scope.

```java
Map<String, Object> plan = mail.plan.get();

try {
    mail.campaigns.create(Map.of(
        "name", "Blast", "subject", "We just shipped",
        "fromName", "Your Name", "fromEmail", "you@yourdomain.com"));
} catch (PlanLimitException e) {
    System.err.printf("%s exhausted on %s: %s%n",
        e.getFeature(), e.getPlan(), e.getUpgradeUrl());
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

```java
mail.streaming.generateEmail(
    Map.of("prompt", "a launch email"),
    frame -> System.out.print(frame.data().get("delta")));
```

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- Maven Central — https://central.sonatype.com/artifact/io.misar/misarmail

MIT © [Misar AI](https://misar.io)
