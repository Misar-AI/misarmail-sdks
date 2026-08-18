# MisarMail PHP SDK

Official PHP SDK for the [MisarMail](https://misarmail.com) API — transactional
send, campaigns, contacts, templates, automations, deliverability, warmup,
monetization and the two AI streams.

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

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
use MisarMail\Client;

$mail = new Client('msk_your_key');

$mail->email->send([
    'from'    => ['email' => 'you@yourdomain.com'],
    'to'      => [['email' => 'someone@example.com']],
    'subject' => 'Hello',
    'html'    => '<p>Hi there</p>',
]);

$contacts = $mail->contacts->list();
```

## Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**,
carrying `code: "plan_limit_exceeded"`. The SDK keys on that code rather than
the status, which is why a refusal is typed correctly even though 403 is
otherwise an authorization failure. The SDK raises
`PlanLimitError` for either, and **does not retry** it — retrying cannot
help until the allowance resets or the plan changes. Read ``$upgradeUrl`` to
send the user somewhere useful.

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps),
`usage` — an array with one entry per metered feature, each carrying `used`,
`limit` and `remaining` — and `upgrade`, which is null until a quota is tight.
A null `limit` means unlimited, and `remaining` is null alongside it rather than
0. Read it before an expensive call rather than discovering the ceiling through
a refusal.

The key needs the `read` or `subscription` scope.

```php
$plan = $mail->plan->get();

try {
    $mail->campaigns->create([
        'name'      => 'Blast',
        'subject'   => 'We just shipped',
        'fromName'  => 'Your Name',
        'fromEmail' => 'you@yourdomain.com',
    ]);
} catch (MisarMail\PlanLimitError $e) {
    fwrite(STDERR, "{$e->feature} exhausted on {$e->plan}: {$e->upgradeUrl}\n");
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

```php
$mail->streaming->generateEmail(['prompt' => 'a launch email'],
    function (MisarMail\StreamEvent $e) {
        echo $e->data['delta'] ?? '';
        // return false to stop the stream early
    });
```

## License

MIT — see [LICENSE](LICENSE).
