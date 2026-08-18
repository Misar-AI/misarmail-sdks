# MisarMail Java SDK

Official Java SDK for the [MisarMail](https://misarmail.com) API — transactional
send, campaigns, contacts, templates, automations, deliverability, warmup,
monetization and the two AI streams.

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

## Install

```xml
<dependency>
  <groupId>io.misar</groupId>
  <artifactId>misarmail</artifactId>
  <version>1.0.0</version>
</dependency>
```

## Auth

Use a MisarMail developer key (`msk_…`), created at
[misarmail.com/developers](https://misarmail.com/developers). It is sent as
`Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer.

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
help until the allowance resets or the plan changes. Read ``getUpgradeUrl()`` to
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

## License

MIT — see [LICENSE](LICENSE).
