# MisarMail Rust SDK

Official Rust SDK for the [MisarMail](https://misarmail.com) API — transactional
send, campaigns, contacts, templates, automations, deliverability, warmup,
monetization and the two AI streams.

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

## Install

```toml
misarmail = "1"
```

## Auth

Use a MisarMail developer key (`msk_…`), created at
[misarmail.com/developers](https://misarmail.com/developers). It is sent as
`Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer.

## Quick start

```rust
use misarmail::{MisarMailClient, MisarMailError};
use serde_json::json;

#[tokio::main]
async fn main() -> Result<(), misarmail::MisarMailError> {
    let mail = MisarMailClient::new("msk_your_key");

    mail.email.send(json!({
        "from": { "email": "you@yourdomain.com" },
        "to": [{ "email": "someone@example.com" }],
        "subject": "Hello",
        "html": "<p>Hi there</p>",
    })).await?;

    let contacts = mail.contacts.list(None).await?;
    Ok(())
}
```

## Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**,
carrying `code: "plan_limit_exceeded"`. The SDK keys on that code rather than
the status, which is why a refusal is typed correctly even though 403 is
otherwise an authorization failure. The SDK raises
`MisarMailError::PlanLimit` for either, and **does not retry** it — retrying cannot
help until the allowance resets or the plan changes. Read ``upgrade_url`` to
send the user somewhere useful.

`GET /plan` returns `plan`, `sending` (the per-day and per-month email caps),
`usage` — an array with one entry per metered feature, each carrying `used`,
`limit` and `remaining` — and `upgrade`, which is null until a quota is tight.
A null `limit` means unlimited, and `remaining` is null alongside it rather than
0. Read it before an expensive call rather than discovering the ceiling through
a refusal.

The key needs the `read` or `subscription` scope.

```rust
let plan = mail.plan.get().await?;

match mail.campaigns.create(json!({
        "name": "Blast", "subject": "We just shipped",
        "fromName": "Your Name", "fromEmail": "you@yourdomain.com",
    })).await {
    Err(MisarMailError::PlanLimit { feature, plan, upgrade_url, .. }) => {
        eprintln!("{feature:?} exhausted on {plan:?}: {upgrade_url:?}");
    }
    other => { other?; }
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

```rust
use futures_util::StreamExt;

let mut stream = mail.streaming.generate_email(json!({"prompt": "a launch email"})).await?;
while let Some(frame) = stream.next().await {
    let frame = frame?;
    print!("{}", frame.data["delta"].as_str().unwrap_or(""));
}
```

## License

MIT — see [LICENSE](LICENSE).
