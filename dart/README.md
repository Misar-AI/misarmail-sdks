# MisarMail Dart SDK

MisarMail is a transactional **and** marketing email platform. This package is the
Dart client for its HTTP API at `https://api.misar.io/mail/v1`: transactional
sends, marketing campaigns with A/B tests, contacts and segments, templates,
automations, sending-domain and DMARC verification, deliverability scoring,
address validation, event and revenue tracking, analytics, wallet and plan
standing, API keys and webhooks. It targets Dart `>=3.0.0 <4.0.0` and depends only
on `package:http` and `package:crypto`, so it runs in servers, CLIs and background
isolates alike. Flutter apps should use
[`misarmail_flutter`](https://pub.dev/packages/misarmail_flutter), which adds
secure on-device key storage.

Product: [misarmail.com](https://misarmail.com) · Full reference:
[misarmail.com/docs](https://misarmail.com/docs)

## Features

Only what this package actually exposes is listed.

- **Transactional send** — `email.send`, with `cc`/`bcc`/`reply_to`, `tags`,
  `metadata` and an `idempotency_key`. `sandbox.send`, `sandbox.list` and
  `sandbox.delete` cover the test mailbox.
- **Campaigns** — `campaigns` list/create/get/update/send/delete, plus `abTests`
  list/create/get/setWinner.
- **Audience** — `contacts` list/create/get/update/delete/importContacts,
  `segments.members`, `landingPages.create`.
- **Content** — `templates` list/create/get/update/delete/render (variable
  substitution server-side) and `ai.subjectLines`.
- **Automations** — `automations` list/create/get/update/delete/activate.
- **Deliverability and sending infrastructure** — `domains` list/create/get/
  verify/delete, `dmarc` check/listDomains/addDomain/removeDomain,
  `deliverability.audit` and `deliverability.score`, `dedicatedIps`,
  `warmup.get`, `inbound`.
- **Stored mail** — `emails` list/get/update and `emailAccounts.list`.
- **Analytics and attribution** — `analytics.overview`, `track.event`,
  `track.purchase`, `revenue.attribution`, `usage.get`.
- **Validation** — `validate.email` for a single address.
- **Plan, billing and credits** — `plan.get`, `plan.monetization`, `subscription`
  get/upsert/cancel, `wallet` get/credit/debit, `creditRates.list`,
  `teamMembers.get`, `monetization.tip`, `billing.subscription`,
  `billing.checkout`.
- **Developer** — `keys` list/create/get/revoke, `webhooks`
  list/create/get/update/delete/test, `streaming`.

Absent from this package, though the API has them: the shared inbox, forms, the
template marketplace, drafts, labels, notifications, integrations, referrals, the
subscriber preference centre, batch address validation and the `settings` group.
Call those over plain HTTP for now.

## What's in the package

`MisarMailClient` is the only entry point. Resources hang off it as plain fields
(`mail.contacts`, `mail.campaigns`, …) and every method returns
`Future<Map<String, dynamic>>` — the decoded JSON envelope, not a generated model.
Responses are enveloped, so read `response['data']`, `response['pagination']`, and
so on.

```dart
MisarMailClient(
  apiKey: 'msk_…',                      // required
  baseUrl: 'https://api.misar.io/mail/v1', // default
  maxRetries: 3,                        // default
  httpClient: myClient,                 // optional package:http Client
);
```

- **Transport.** One `http.Client`, reused for every call. Call `mail.close()`
  when you are done. The SDK sets no request timeout of its own — supply an
  `http.Client` that imposes one if you need it.
- **Retries.** `429`, `500`, `502`, `503` and `504` are retried up to `maxRetries`
  attempts in total (3 by default, so two retries), with an exponential backoff of
  500 ms then 1 s. Transport failures follow the same budget.
- **Streaming routes.** Both SSE endpoints live outside `/v1`; the client derives
  that base by stripping the trailing `/v1` from `baseUrl`, so overriding
  `baseUrl` moves both together.
- **Errors.** `MisarMailError`, plus the subclasses `MisarMailPlanLimitError` and
  `MisarMailNetworkError`.

### Webhook signature verification

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

## Install

```bash
dart pub add misarmail
```

Or in `pubspec.yaml`:

```yaml
dependencies:
  misarmail: ^1.0.0
```

## Auth

Use a MisarMail developer key with the `msk_` prefix, created at
[misarmail.com/developers](https://misarmail.com/developers). The client sends it
as `Authorization: Bearer msk_…` on every request, including the SSE streams.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides and the SDK surfaces its answer.

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

## License

MIT — see [LICENSE](LICENSE).
