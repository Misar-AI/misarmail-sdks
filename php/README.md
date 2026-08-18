# MisarMail PHP SDK

[MisarMail](https://misarmail.com) is a transactional **and** marketing email platform:
one API for the receipts and password resets your product sends, and for the campaigns,
segments and automations your marketing team runs on the same contact list and the same
verified domains. This package is the PHP client for that API — 33 resource groups on
one client object, for PHP 8.1+ with nothing but ext-curl and ext-json underneath.

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

## Features

Grouped the way the client exposes them. Every name below is a readonly property on
`MisarMail\Client`.

- **Transactional send** — `email->send()`; `sandbox` (`send`, `list`, `delete`) for test
  sends that never leave the building.
- **Campaigns** — `campaigns` `list`/`create`/`get`/`update`/`send`/`delete`; `abTests`
  `list`/`create`/`get`/`setWinner`.
- **Audience** — `contacts` (`list`, `create`, `get`, `update`, `delete`, `import`) and
  `segments->members()`.
- **Content** — `templates` (`list`, `create`, `get`, `update`, `delete`, `render`),
  `landingPages->create()`, and `ai->subjectLines()` for generated subject lines.
- **Automations** — `automations` `list`/`create`/`get`/`update`/`delete`/`activate`.
- **Deliverability and sending infrastructure** — `domains` (add, `verify`, delete),
  `dmarc` (`check`, `listDomains`, `addDomain`, `removeDomain`), `deliverability`
  (`audit`, `score`), `dedicatedIps`, `warmup->get()`, `inbound` addresses.
- **Mailbox** — `emails` (`list`, `get`, `update`), `emailAccounts->list()`.
- **Analytics and attribution** — `analytics->overview()` (aggregate, or per-campaign
  when you pass `campaignId`), `track->event()`, `track->purchase()`,
  `revenue->attribution()`, `usage->get()`.
- **Validation** — `validate->email()` for one address at a time.
- **Plan, billing and credits** — `plan` (`get`, `monetization`), `billing`
  (`subscription`, `checkout`), `subscription` (`get`, `upsert`, `cancel`), `wallet`
  (`get`, `credit`, `debit`), `creditRates->list()`, `teamMembers->get()`,
  `monetization->tip()`.
- **Developer** — `keys` (`list`, `create`, `get`, `revoke`), `webhooks` (CRUD plus
  `test`), `streaming`.

Narrower than the TypeScript SDK, which is the reference implementation: forms, labels,
drafts, marketplace, inbox conversations, preferences, referrals, notifications,
integrations and workspace settings have no PHP methods yet, `segments->members()` is the
only segments call, and there is no batch address validation. Call `$mail->request()`
directly for anything else — it is public and takes `(method, path, data, baseOverride)`.

## What's in the package

- **`MisarMail\Client`** — the one entry point. Every resource is a readonly property on
  it (`$mail->contacts`, `$mail->campaigns`, …); there is nothing else to construct.
- **Options** — `new Client($apiKey, $timeout = 30, $baseUrl = null)`. `$baseUrl` is for
  tests and self-hosted deployments; leave it null in production. `$baseUrl` and the
  derived `$apiBase` (the routes outside `/v1`) are both readable on the client.
- **Payloads and results** — requests take plain associative arrays and every method
  returns a decoded `array`. There are no DTO classes to learn, and nothing breaks when
  the API adds a field. A `204` or an empty body comes back as `[]`.
- **Transport** — cURL with a 10-second connect timeout and your `$timeout` for the rest.
  `429`, `500`, `502`, `503` and `504` are retried up to 3 attempts with exponential
  backoff (300 ms, then 600 ms), as are cURL-level failures. A plan refusal is never
  retried.
- **Errors** — `MisarMail\ApiError`, with `MisarMail\NetworkError` and
  `MisarMail\PlanLimitError` extending it.
- **SSE streaming** — `$mail->streaming->generateEmail()` and `campaignSend()` are
  callback-driven and hand you a `MisarMail\StreamEvent` per frame; see
  [Streaming](#streaming).
- **No webhook signature verifier.** `$mail->webhooks` manages webhook *endpoints*
  (list/create/get/update/delete/test). MisarMail signs deliveries as
  `HMAC-SHA256(timestamp . "." . rawBody)` in the `X-Misar-Signature` header alongside
  `X-Misar-Timestamp`, but this package ships no helper to check it — verify it yourself
  with `hash_hmac()` and `hash_equals()`. (The Go, Python, Ruby, Dart and Flutter SDKs do
  ship one.)

## Install

```bash
composer require misarai/misarmail-php
```

## Auth

Use a MisarMail developer key (`msk_…`), created at
[misarmail.com/developers](https://misarmail.com/developers). It is sent as
`Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer.

## Quick start

```php
<?php
require 'vendor/autoload.php';

use MisarMail\Client;

$mail = new Client(getenv('MISARMAIL_API_KEY'));

$sent = $mail->email->send([
    'from'    => ['email' => 'you@yourdomain.com', 'name' => 'Your App'],
    'to'      => [['email' => 'someone@example.com']],
    'subject' => 'Hello',
    'html'    => '<p>Hi there</p>',
]);

echo $sent['message_id'];
```

## Primary functions

### Send a transactional email

`from` is a single address array and `to` is a list of them. Pass an `idempotency_key`
and a retry can never send twice — the response comes back with `idempotent: true` the
second time.

```php
$res = $mail->email->send([
    'from'            => ['email' => 'receipts@yourdomain.com', 'name' => 'Acme'],
    'to'              => [['email' => 'customer@example.com']],
    'reply_to'        => ['email' => 'support@yourdomain.com'],
    'subject'         => 'Your receipt',
    'html'            => '<p>Thanks for your order.</p>',
    'text'            => 'Thanks for your order.',
    'tags'            => ['receipt'],
    'metadata'        => ['order_id' => 'ord-1041'],
    'idempotency_key' => 'ord-1041-receipt',
]);

$res['message_id'];   // "msg-…"
```

### List and create contacts

Responses are enveloped. `list()` returns `['success', 'data', 'pagination']` and takes
`page`/`limit` as named integers, not an options array; `create()` returns
`['success', 'data']` with the contact under `data`.

```php
$page = $mail->contacts->list(page: 1, limit: 50);
echo count($page['data']), ' of ', $page['pagination']['total'];

$created = $mail->contacts->create([
    'email'        => 'new@example.com',
    'firstName'    => 'Ada',
    'lastName'     => 'Lovelace',
    'tags'         => ['beta'],
    'customFields' => ['plan' => 'pro'],
]);

echo $created['data']['id'];
```

`get()` and `delete()` take the contact id, which the route reads from the query string
rather than a path segment. `update()` is different again: it identifies the contact by
**email address**, not by id.

```php
$mail->contacts->update('ada@example.com', ['status' => 'unsubscribed']);
```

### Bulk import contacts

Counts come back under `summary`, and `errors` is a separate list of messages.

```php
$imported = $mail->contacts->import([
    'contacts' => [
        ['email' => 'a@example.com', 'firstName' => 'A'],
        ['email' => 'b@example.com', 'firstName' => 'B'],
    ],
    'updateExisting' => true,
]);

$imported['summary'];   // ['imported' => …, 'updated' => …, 'skipped' => …, 'errors' => …]
$imported['errors'];    // list of strings
```

### Create and send a campaign

Campaigns take `fromName` and `fromEmail` as separate fields — there is no `from` array
here, unlike `email->send()`. `send()` queues the campaign and reports it as `scheduled`.

```php
$campaign = $mail->campaigns->create([
    'name'      => 'March launch',
    'subject'   => 'We just shipped',
    'fromName'  => 'Ada at Acme',
    'fromEmail' => 'hello@yourdomain.com',
    'replyTo'   => 'support@yourdomain.com',
    'bodyHtml'  => '<h1>It is live</h1>',
    'segmentId' => 'seg-123',
]);

$queued = $mail->campaigns->send($campaign['data']['id']);
echo $queued['campaignId'], ' ', $queued['status'];   // … scheduled
```

Only `draft`, `scheduled` or `paused` campaigns can be updated, and only `draft`
campaigns can be deleted.

### Validate an address

Each call spends a credit, and the response tells you what is left.

```php
$check = $mail->validate->email('someone@example.com');

$check['data']['is_valid'];             // bool
$check['data']['score'];                // 0–1 confidence
$check['data']['checks'];               // ['syntax' => …, 'mx' => …, 'smtp' => …]
$check['data']['flags']['disposable'];  // bool
$check['credits']['balance_after'];     // credits remaining
```

### Render a template

```php
$rendered = $mail->templates->render([
    'template_id' => 'tpl-123',
    'variables'   => ['name' => 'Ada', 'plan' => 'Pro'],
]);

$rendered['data']['subject'];   // "Welcome, Ada"
$rendered['data']['html'];
```

### Track events and revenue

The event name field is `event_name`, and purchase totals are integer **cents** in
`total_cents`.

```php
$mail->track->event([
    'email'      => 'customer@example.com',
    'event_name' => 'viewed_pricing',
    'event_data' => ['plan' => 'pro'],
]);

$purchase = $mail->track->purchase([
    'email'       => 'customer@example.com',
    'order_id'    => 'ord-1041',
    'total_cents' => 9900,
    'currency'    => 'USD',
    'items'       => [['name' => 'Pro annual', 'quantity' => 1, 'price_cents' => 9900]],
]);

$purchase['attribution'];   // which campaign or automation earned it
```

### Read analytics and manage keys

Without `campaignId` you get aggregate usage and totals for the period; with one you get
that campaign's stats and rates. `keys->list()` returns the keys under **`keys`**, not
`data`, and `create()` returns the raw key exactly once.

```php
$overall = $mail->analytics->overview(['startDate' => '2026-04-01', 'endDate' => '2026-04-30']);
$one     = $mail->analytics->overview(['campaignId' => $campaignId]);

$keys = $mail->keys->list();
count($keys['keys']);

$fresh = $mail->keys->create(['name' => 'CI', 'scopes' => ['send', 'read']]);
echo $fresh['key'];   // shown once and never again
```

## Errors

Three classes, all in the `MisarMail` namespace:

| Class | When |
| --- | --- |
| `ApiError` | Any non-2xx API response. Carries `$status`. Extends `RuntimeException`. |
| `NetworkError` | cURL never got an answer, or every retry was spent. `$status` is `0`. |
| `PlanLimitError` | The subscription behind the key does not cover the call. |

`NetworkError` and `PlanLimitError` both extend `ApiError`, so
`catch (MisarMail\ApiError $e)` catches everything the SDK throws.

### Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**, carrying
`code: "plan_limit_exceeded"`. The SDK keys on that code rather than the status, which is
why a refusal is typed correctly even though 403 is otherwise an authorization failure.
It throws `PlanLimitError` and **does not retry** — retrying cannot help until the
allowance resets or the plan changes. Read `$upgradeUrl` to send the user somewhere
useful.

```php
try {
    $mail->campaigns->create([
        'name'      => 'Blast',
        'subject'   => 'We just shipped',
        'fromName'  => 'Your Name',
        'fromEmail' => 'you@yourdomain.com',
    ]);
} catch (MisarMail\PlanLimitError $e) {
    fwrite(STDERR, "{$e->feature} exhausted on {$e->plan}: {$e->upgradeUrl}\n");
    // $e->retryAfter is seconds until the allowance resets, when the API says so
}
```

`$mail->plan->get()` returns `plan`, `sending` (the per-day and per-month email caps),
`usage` — an array with one entry per metered feature, each carrying `used`, `limit` and
`remaining` — and `upgrade`, which is null until a quota is tight. A null `limit` means
unlimited, and `remaining` is null alongside it rather than 0. Read it before an
expensive call rather than discovering the ceiling through a refusal.

The key needs the `read` or `subscription` scope.

```php
$plan = $mail->plan->get();
print_r($plan['sending']);
print_r($plan['usage']);
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1`, which the SDK
handles for you:

| Method | Route |
| --- | --- |
| `streaming->generateEmail()` | `POST /api/ai/generate-email/stream` |
| `streaming->campaignSend()` | `GET /api/campaigns/{id}/send-stream` |

PHP has no async iterator here, so both take a callback and block until the stream ends.
Return `false` from the callback to stop early. Frames are unnamed (`data: {…}`, with no
`event:` line) and the stream ends with `data: [DONE]`, which the SDK consumes rather
than handing on. Each `StreamEvent` carries `$event` (normally null), `$data` (the
decoded array, or null when the payload was not JSON) and `$raw`. A stream is never
retried: replaying one that failed mid-flight would duplicate whatever you had already
read.

```php
$mail->streaming->generateEmail(['prompt' => 'a launch email'],
    function (MisarMail\StreamEvent $e) {
        echo $e->data['delta'] ?? '';
    });

$mail->streaming->campaignSend($campaignId, function (MisarMail\StreamEvent $e) {
    echo $e->raw, "\n";
});
```

## License

MIT — see [LICENSE](LICENSE).
