# MisarMail C# SDK

Official C# SDK for the [MisarMail](https://misarmail.com) API — transactional
send, campaigns, contacts, templates, automations, deliverability, warmup,
monetization and the two AI streams.

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

## Install

```bash
dotnet add package MisarMail
```

## Auth

Use a MisarMail developer key (`msk_…`), created at
[misarmail.com/developers](https://misarmail.com/developers). It is sent as
`Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer.

## Quick start

```csharp
using MisarMail;

var mail = new MisarMailClient("msk_your_key");

await mail.Email_SendAsync(new {
    from = new { email = "you@yourdomain.com" },
    to = new[] { new { email = "someone@example.com" } },
    subject = "Hello",
    html = "<p>Hi there</p>",
});

var contacts = await mail.Contacts_ListAsync();
```

## Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**,
carrying `code: "plan_limit_exceeded"`. The SDK keys on that code rather than
the status, which is why a refusal is typed correctly even though 403 is
otherwise an authorization failure. The SDK raises
`MisarMailPlanLimitException` for either, and **does not retry** it — retrying cannot
help until the allowance resets or the plan changes. Read ``UpgradeUrl`` to
send the user somewhere useful.

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps),
`usage` — an array with one entry per metered feature, each carrying `used`,
`limit` and `remaining` — and `upgrade`, which is null until a quota is tight.
A null `limit` means unlimited, and `remaining` is null alongside it rather than
0. Read it before an expensive call rather than discovering the ceiling through
a refusal.

The key needs the `read` or `subscription` scope.

```csharp
var plan = await mail.Plan_GetAsync();

try {
    await mail.Campaigns_CreateAsync(new {
        name = "Blast", subject = "We just shipped",
        fromName = "Your Name", fromEmail = "you@yourdomain.com",
    });
} catch (MisarMailPlanLimitException e) {
    Console.Error.WriteLine($"{e.Feature} exhausted on {e.Plan}: {e.UpgradeUrl}");
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

```csharp
await foreach (var frame in mail.Streaming_GenerateEmailAsync(new { prompt = "a launch email" }))
    Console.Write(frame.Data?.GetProperty("delta").GetString());
```

## License

MIT — see [LICENSE](LICENSE).
