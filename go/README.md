# MisarMail Go SDK

Official Go SDK for the [MisarMail](https://misarmail.com) API — transactional
send, campaigns, contacts, templates, automations, deliverability, warmup,
monetization and the two AI streams.

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

## Install

```bash
go get github.com/Misar-AI/misarmail-sdks/go
```

## Auth

Use a MisarMail developer key (`msk_…`), created at
[misarmail.com/developers](https://misarmail.com/developers). It is sent as
`Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer.

## Quick start

```go
package main

import (
    "context"
    "log"

    "github.com/Misar-AI/misarmail-sdks/go/misarmail"
)

func main() {
    mail := misarmail.New("msk_your_key")
    ctx := context.Background()

    if _, err := mail.Email.Send(ctx, map[string]any{
        "from":    map[string]any{"email": "you@yourdomain.com"},
        "to":      []map[string]any{{"email": "someone@example.com"}},
        "subject": "Hello",
        "html":    "<p>Hi there</p>",
    }); err != nil {
        log.Fatal(err)
    }
}
```

## Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**,
carrying `code: "plan_limit_exceeded"`. The SDK keys on that code rather than
the status, which is why a refusal is typed correctly even though 403 is
otherwise an authorization failure. The SDK raises
`*PlanLimitError` for either, and **does not retry** it — retrying cannot
help until the allowance resets or the plan changes. Read ``UpgradeURL`` to
send the user somewhere useful.

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps),
`usage` — an array with one entry per metered feature, each carrying `used`,
`limit` and `remaining` — and `upgrade`, which is null until a quota is tight.
A null `limit` means unlimited, and `remaining` is null alongside it rather than
0. Read it before an expensive call rather than discovering the ceiling through
a refusal.

The key needs the `read` or `subscription` scope.

```go
plan, err := mail.Plan.Get(ctx)

_, err = mail.Campaigns.Create(ctx, map[string]any{"name": "Blast", "subject": "Hi",
        "fromName": "You", "fromEmail": "you@yourdomain.com"})
var limit *misarmail.PlanLimitError
if errors.As(err, &limit) {
    log.Printf("%s exhausted on %s: %s", limit.Feature, limit.Plan, limit.UpgradeURL)
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

```go
err := mail.Streaming.GenerateEmail(ctx,
    map[string]any{"prompt": "a launch email"},
    func(e misarmail.StreamEvent) error {
        fmt.Print(e.Data["delta"])
        return nil   // returning an error stops the stream
    })
```

## License

MIT — see [LICENSE](LICENSE).
