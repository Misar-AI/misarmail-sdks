# MisarMail PHP SDK

> Send transactional email and run marketing campaigns from PHP — one client, ext-curl and ext-json only.

[![Packagist](https://img.shields.io/packagist/v/misarai/misarmail-php)](https://packagist.org/packages/misarai/misarmail-php)
[![php](https://img.shields.io/badge/php-%3E%3D%208.1-777BB4)](https://packagist.org/packages/misarai/misarmail-php)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 90 methods · SSE streaming · typed plan-limit errors**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

PHP 8.1+, with nothing but `ext-curl` and `ext-json` underneath. Requests take plain associative arrays and every method returns a decoded `array` — no DTOs to learn.

---

## Install

### Composer

```bash
composer require misarai/misarmail-php
```

### composer.json

```json
{ "require": { "misarai/misarmail-php": "^1.0" } }
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```php
use MisarMail\Client;

$mail = new Client(getenv('MISARMAIL_API_KEY'));
```

---

## Resources

Every group the client exposes, and every public method on it.

### Send

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->email` | `send` | Transactional send — cc/bcc/reply-to, tags, metadata, `idempotency_key`. |
| `$mail->sandbox` | `send`, `list`, `delete` | Test sends captured instead of delivered. |

### Campaigns and tests

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->campaigns` | `list`, `create`, `get`, `update`, `send`, `delete` | Marketing campaigns: draft, edit, queue for send. |
| `$mail->abTests` | `list`, `create`, `get`, `setWinner` | Subject, content, send-time, from-name and preheader splits, and winner selection. |

### Audience

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->contacts` | `list`, `create`, `get`, `update`, `delete`, `import` | Subscribers, plus bulk import. |
| `$mail->segments` | `members` | Dynamic audience segments and their membership. |
| `$mail->landingPages` | `create` | Hosted landing pages with an email capture form. |

### Content

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->templates` | `list`, `create`, `get`, `update`, `delete`, `render` | Reusable templates and server-side variable rendering. |
| `$mail->ai` | `subjectLines` | AI-generated subject lines. |

### Automations

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->automations` | `list`, `create`, `get`, `update`, `delete`, `activate` | Trigger-based workflows — welcome series, drips, re-engagement. |

### Deliverability and sending infrastructure

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->domains` | `list`, `create`, `get`, `verify`, `delete` | Sending domains and their DNS verification. |
| `$mail->dmarc` | `check`, `listDomains`, `addDomain`, `removeDomain` | Live SPF/DKIM/DMARC record checks and monitored domains. |
| `$mail->deliverability` | `audit`, `score` | Deliverability score, audit and remediation guidance. |
| `$mail->dedicatedIps` | `list`, `create`, `update`, `delete` | Dedicated sending IPs. |
| `$mail->warmup` | `get` | IP/domain warm-up progress and today's remaining capacity. |
| `$mail->inbound` | `list`, `create`, `get`, `delete` | Inbound routing domains, so replies land in the unified inbox. |

### Mailbox and inbox

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->emails` | `list`, `get`, `update` | Stored messages in the mailbox. |
| `$mail->emailAccounts` | `list` | Connected mailbox accounts. |

### Analytics and attribution

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->analytics` | `overview` | Delivery and engagement stats — aggregate, or one campaign. |
| `$mail->track` | `event`, `purchase` | Custom events and ecommerce purchases. |
| `$mail->revenue` | `attribution` | Revenue attributed back to email. |
| `$mail->usage` | `get` | Metered usage for a period. |

### Validation

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->validate` | `email` | Address validation, and the credit balance behind it. |

### Plan, billing and credits

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->plan` | `get`, `monetization` | Current plan, quotas and monetization stats. |
| `$mail->billing` | `subscription`, `checkout` | Subscription state and checkout. |
| `$mail->subscription` | `get`, `upsert`, `cancel` | Subscription read/write and per-product plan limits. |
| `$mail->wallet` | `get`, `credit`, `debit` | Credit balance, credit and debit. |
| `$mail->creditRates` | `list` | What each metered action costs in credits. |
| `$mail->teamMembers` | `get` | Team members on the account. |
| `$mail->monetization` | `tip` | Newsletter tips. |

### Developer

| Resource | Methods | What it covers |
| --- | --- | --- |
| `$mail->keys` | `list`, `create`, `get`, `revoke` | API keys — create, list, revoke. |
| `$mail->webhooks` | `list`, `create`, `get`, `update`, `delete`, `test` | Webhook endpoints, plus a test delivery. |
| `$mail->streaming` | `generateEmail`, `campaignSend` | The two Server-Sent Events endpoints. |

---

## Client

| Thing | Detail |
| --- | --- |
| Entry point | `new MisarMail\Client($apiKey, $timeout = 30, $baseUrl = null)` — every resource is a readonly property. |
| `$baseUrl` / `$apiBase` | `https://api.misar.io/mail/v1` and the derived base for routes outside `/v1`; both readable on the client. |
| Results | A decoded `array`. `204`/empty comes back as `[]`. |
| Transport | cURL, 10-second connect timeout, `$timeout` for the rest. |
| Retried | `429`, `500`, `502`, `503`, `504` and cURL failures — 3 attempts, 300 ms then 600 ms. |
| Never retried | Plan refusals, and streams. |
| Errors | `MisarMail\ApiError`, with `NetworkError` and `PlanLimitError` extending it. |
| Webhook verifier | Not shipped here — verify `HMAC-SHA256(timestamp . "." . rawBody)` yourself with `hash_hmac()` and `hash_equals()`. (Go, Python, Ruby and Dart ship one.) |
| Escape hatch | `$mail->request($method, $path, $data, $baseOverride)` is public. |

---

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

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- Packagist — https://packagist.org/packages/misarai/misarmail-php

MIT © [Misar AI](https://misar.io)
