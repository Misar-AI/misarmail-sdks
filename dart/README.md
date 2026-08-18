# MisarMail Dart SDK

> Send transactional email and run marketing campaigns from Dart — servers, CLIs and background isolates.

[![pub](https://img.shields.io/pub/v/misarmail)](https://pub.dev/packages/misarmail)
[![dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-0175C2)](https://pub.dev/packages/misarmail)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 90 methods · SSE streaming · webhook signature verification**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

Dart `>=3.0.0 <4.0.0`, depending only on `package:http` and `package:crypto`. Every method returns `Future<Map<String, dynamic>>` — the decoded JSON envelope, not a generated model.

---

## Install

### dart pub

```bash
dart pub add misarmail
```

### pubspec.yaml

```yaml
dependencies:
  misarmail: ^5.0.2
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```dart
import 'package:misarmail/misarmail.dart';

final mail = MisarMailClient(apiKey: Platform.environment['MISARMAIL_API_KEY']!);
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
| Entry point | `MisarMailClient(apiKey:, baseUrl:, maxRetries:, httpClient:)` — every resource is a field. |
| `baseUrl` | `https://api.misar.io/mail/v1` |
| Results | `Future<Map<String, dynamic>>` — read `response['data']`, `response['pagination']`, … |
| Transport | One `http.Client`, reused. Call `mail.close()` when done. No timeout of its own — supply an `http.Client` that imposes one. |
| Retried | `429`, `500`, `502`, `503`, `504` and transport failures — `maxRetries` attempts in total (3 by default), 500 ms then 1 s. |
| Never retried | Plan refusals, and streams. |
| Errors | `MisarMailError`, with `MisarMailPlanLimitError` and `MisarMailNetworkError` extending it. |
| Webhook verifier | `verifyWebhookSignature` / `signWebhook`, `defaultToleranceSeconds` 300. |
| Flutter | Use this package. [`misarmail_flutter`](https://pub.dev/packages/misarmail_flutter) is discontinued on pub.dev and marked `replacedBy: misarmail`. |

---

## Quick start

```dart
import 'package:misarmail/misarmail.dart';

Future<void> main() async {
  final mail = MisarMailClient(apiKey: 'msk_your_key');

  final sent = await mail.email.send({
    'from': {'email': 'you@yourdomain.com', 'name': 'Your App'},
    'to': [
      {'email': 'someone@example.com'}
    ],
    'subject': 'Hello',
    'html': '<p>Hi there</p>',
  });

  print(sent['message_id']);
  mail.close();
}
```

## Primary calls

Send a transactional email, safely repeatable:

```dart
await mail.email.send({
  'from': {'email': 'you@yourdomain.com'},
  'to': [
    {'email': 'someone@example.com'}
  ],
  'subject': 'Your receipt',
  'html': '<p>Thanks for your order.</p>',
  'text': 'Thanks for your order.',
  'idempotency_key': 'order-1001-receipt',
  'tags': ['receipt'],
  'metadata': {'order_id': '1001'},
});
```

List contacts (the response carries `data` and `pagination`):

```dart
final page = await mail.contacts.list(
  params: {'page': 1, 'limit': 50, 'status': 'subscribed'},
);

for (final contact in page['data'] as List) {
  print(contact['email']);
}
print(page['pagination']['total']);
```

Create a contact:

```dart
final created = await mail.contacts.create({
  'email': 'new@example.com',
  'firstName': 'Ada',
  'lastName': 'Lovelace',
  'tags': ['beta'],
});

final contactId = created['data']['id'] as String;
```

Bulk import (max 5000 rows per call):

```dart
final result = await mail.contacts.importContacts({
  'contacts': [
    {'email': 'a@example.com', 'firstName': 'A'},
    {'email': 'b@example.com', 'firstName': 'B'},
  ],
  'updateExisting': true,
});

print(result['summary']); // {imported, updated, skipped, errors}
```

Create a campaign and send it. Campaigns take `fromName` and `fromEmail` — there
is no `from` object here, unlike a transactional send:

```dart
final campaign = await mail.campaigns.create({
  'name': 'August launch',
  'subject': 'We just shipped',
  'fromName': 'Your Name',
  'fromEmail': 'you@yourdomain.com',
  'bodyHtml': '<h1>New release</h1>',
});

final queued = await mail.campaigns.send(campaign['data']['id'] as String);
print(queued['status']); // scheduled
```

Validate an address:

```dart
final check = await mail.validate.email('someone@example.com');
print(check['data']['is_valid']);
print(check['credits']['balance_after']);
```

Render a template with variables:

```dart
final rendered = await mail.templates.render({
  'template_id': 'tmpl_123',
  'variables': {'first_name': 'Ada'},
});

print(rendered['data']['subject']);
print(rendered['data']['html']);
```

Track an event and a purchase. Note `event_name` (not `event`) and `total_cents`
(not `amount`):

```dart
await mail.track.event({
  'email': 'someone@example.com',
  'event_name': 'trial_started',
  'event_data': {'plan': 'pro'},
});

await mail.track.purchase({
  'email': 'someone@example.com',
  'order_id': 'ord_1001',
  'total_cents': 4900,
  'currency': 'USD',
  'items': [
    {'name': 'Pro plan', 'quantity': 1, 'price_cents': 4900},
  ],
});
```

Check plan standing before an expensive call, rather than discovering the ceiling
through a refusal:

```dart
final plan = await mail.plan.get();
print(plan['plan']);    // current plan
print(plan['sending']); // per-day and per-month email caps
print(plan['usage']);   // one entry per metered feature: used / limit / remaining
```

A null `limit` means unlimited, and `remaining` is null alongside it rather than 0.

## Errors

Every non-2xx response raises `MisarMailError`, which carries `status`, `message`,
`errorType` and `details`, plus the convenience getters `isUnauthorized`,
`isPlanDenied` and `isRetryable`. Two subclasses narrow it:

- `MisarMailPlanLimitError` — the subscription behind the key does not cover the
  call. Adds `plan`, `upgradeUrl`, `retryAfter` and `feature`.
- `MisarMailNetworkError` — a transport failure, reported with `status` 0.

A plan refusal answers **403** carrying `code: "plan_limit_exceeded"` in the body.
The client keys on that body marker rather than on the status, so the same refusal
arriving as 402 or 429 is still typed as a plan limit — and it is **never
retried**, because retrying cannot help until the allowance resets or the plan
changes. A plain rate-limit 429, which carries no such marker, still is retried.

Catch from most specific to least:

```dart
try {
  await mail.campaigns.send(campaignId);
} on MisarMailPlanLimitError catch (e) {
  print('${e.feature} exhausted on ${e.plan} — upgrade at ${e.upgradeUrl}');
  if (e.retryAfter != null) print('resets in ${e.retryAfter}s');
} on MisarMailNetworkError catch (e) {
  print('transport failure: ${e.message}');
} on MisarMailError catch (e) {
  print('${e.status} ${e.errorType}: ${e.message}');
}
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1`, which the SDK
handles for you.

| Method | Route |
| --- | --- |
| `streaming.generateEmail(options)` | `POST /api/ai/generate-email/stream` |
| `streaming.campaignSend(campaignId)` | `GET /api/campaigns/{id}/send-stream` |

Frames are unnamed — `data: {…}` with no `event:` line — so
`MisarMailStreamEvent.event` is normally null and `MisarMailStreamEvent.data` holds
the decoded JSON. The stream ends at the `data: [DONE]` sentinel, which the SDK
consumes rather than handing on, and keepalive comments are skipped. A stream is
never retried: replaying one that failed mid-flight would duplicate whatever you
had already read.

```dart
import 'dart:io';
import 'package:misarmail/misarmail.dart';

await for (final event in mail.streaming.generateEmail({'prompt': 'a launch email'})) {
  stdout.write(event.data['delta'] ?? '');
}

await for (final event in mail.streaming.campaignSend(campaignId)) {
  print(event.data);
}
```

A plan refusal on opening the stream raises `MisarMailPlanLimitError` before any
frame arrives.

---

## Webhook signature verification

This SDK does ship a verifier. MisarMail signs each webhook as
`HMAC-SHA256(timestamp + "." + rawBody)` and sends the digest in
`X-Misar-Signature` with the unix timestamp in `X-Misar-Timestamp`. Verify against
the **raw** body — re-encoding a decoded map changes key order and whitespace, and
therefore the digest. The comparison is constant-time and stale timestamps are
rejected (`defaultToleranceSeconds` is 300).

```dart
import 'package:misarmail/misarmail.dart';

final ok = verifyWebhookSignature(
  payload: rawBody,
  signature: headers['x-misar-signature']!,
  timestamp: headers['x-misar-timestamp']!,
  secret: endpointSigningSecret,
  // toleranceSeconds: 300,
);
```

`signWebhook(payload, timestamp, secret)` produces the same digest, which is what
you want when writing tests for your own webhook consumer.

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- pub.dev — https://pub.dev/packages/misarmail

MIT © [Misar AI](https://misar.io)
