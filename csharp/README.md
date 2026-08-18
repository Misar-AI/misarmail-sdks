# MisarMail C# SDK

[MisarMail](https://misarmail.com) is a transactional **and** marketing email platform:
one API for the receipts and password resets your product sends, and for the campaigns,
segments and automations your marketing team runs on the same contact list and the same
verified domains. This package is the .NET client for that API — an async/await client
covering 33 resource groups, targeting `net8.0` with no dependencies beyond the base
class library.

Full reference: [`misarmail.com/docs`](https://misarmail.com/docs).

## Features

Grouped the way the client exposes them. Every name below is the prefix of a real method
on `MisarMailClient` — the surface is flat (`Group_MethodAsync`), not nested resources.

- **Transactional send** — `Email_SendAsync`; `Sandbox_SendAsync`/`ListAsync`/`DeleteAsync`
  for test sends that never leave the building.
- **Campaigns** — `Campaigns_ListAsync`/`CreateAsync`/`GetAsync`/`UpdateAsync`/
  `SendCampaignAsync`/`DeleteAsync`; `AbTests_ListAsync`/`CreateAsync`/`GetAsync`/
  `SetWinnerAsync`.
- **Audience** — `Contacts_ListAsync`/`CreateAsync`/`GetAsync`/`UpdateAsync`/`DeleteAsync`/
  `ImportContactsAsync` and `Segments_MembersAsync`.
- **Content** — `Templates_ListAsync`/`CreateAsync`/`GetAsync`/`UpdateAsync`/`DeleteAsync`/
  `RenderAsync`, `LandingPages_CreateAsync`, and `Ai_SubjectLinesAsync` for generated
  subject lines.
- **Automations** — `Automations_ListAsync`/`CreateAsync`/`GetAsync`/`UpdateAsync`/
  `DeleteAsync`/`ActivateAsync`.
- **Deliverability and sending infrastructure** — `Domains_*` (add, `VerifyAsync`,
  delete), `Dmarc_CheckAsync`/`ListDomainsAsync`/`AddDomainAsync`/`RemoveDomainAsync`,
  `Deliverability_AuditAsync`/`ScoreAsync`, `DedicatedIPs_*`, `Warmup_GetAsync`,
  `Inbound_*`.
- **Mailbox** — `Emails_ListAsync`/`GetAsync`/`UpdateAsync`, `EmailAccounts_ListAsync`.
- **Analytics and attribution** — `Analytics_OverviewAsync` (aggregate, or per-campaign
  when you pass `campaignId`), `Track_EventAsync`, `Track_PurchaseAsync`,
  `Revenue_AttributionAsync`, `Usage_GetAsync`.
- **Validation** — `Validate_EmailAsync` for one address at a time.
- **Plan, billing and credits** — `Plan_GetAsync`, `Plan_LimitsAsync`,
  `Plan_MonetizationAsync`, `Billing_SubscriptionAsync`/`CheckoutAsync`,
  `Subscription_GetAsync`/`UpsertAsync`/`CancelAsync`, `Wallet_GetAsync`/`CreditAsync`/
  `DebitAsync`, `CreditRates_ListAsync`, `TeamMembers_GetAsync`, `Monetization_TipAsync`.
- **Developer** — `Keys_ListAsync`/`CreateAsync`/`GetAsync`/`RevokeAsync`, `Webhooks_*`
  (CRUD plus `TestAsync`), `Streaming_*`.

Narrower than the TypeScript SDK, which is the reference implementation: forms, labels,
drafts, marketplace, inbox conversations, preferences, referrals, notifications,
integrations and workspace settings have no C# methods yet, `Segments_MembersAsync` is
the only segments call, and there is no batch address validation. Call those routes over
HTTP directly if you need them.

## What's in the package

- **`MisarMailClient`** — the one type you construct. Every call is a method on it; it
  implements `IDisposable` and owns its `HttpClient` unless you pass your own.
- **Options** — `new MisarMailClient(apiKey, baseUrl, maxRetries, httpClient)`. Defaults:
  `baseUrl` `https://api.misar.io/mail/v1`, `maxRetries` `3`, a fresh `HttpClient` with a
  30-second timeout. A blank `apiKey` throws `ArgumentException` immediately. The handful
  of routes that live outside `/v1` (domains, billing) are derived from `baseUrl` for you.
- **Payloads and results** — requests take any `object` and are serialized with
  `System.Text.Json`, so anonymous objects work as-is. Every method returns
  `Task<JsonElement>`; there are no generated DTOs, so read fields with `GetProperty` or
  deserialize into your own records.
- **Cancellation** — every method takes an optional `CancellationToken`.
- **Transport** — `429`, `500`, `502`, `503` and `504` are retried with exponential
  backoff (500 ms, then 1 s), as are `HttpRequestException` and `TaskCanceledException`.
  A plan refusal is never retried.
- **Errors** — `MisarMailException`, `MisarMailNetworkException`,
  `MisarMailPlanLimitException`.
- **SSE streaming** — `Streaming_GenerateEmailAsync` and `Streaming_CampaignSendAsync`
  return `IAsyncEnumerable<MisarMailStreamEvent>`; see [Streaming](#streaming).
- **No webhook signature verifier.** `Webhooks_*` manages webhook *endpoints*
  (list/create/get/update/delete/test). MisarMail signs deliveries as
  `HMAC-SHA256(timestamp + "." + rawBody)` in the `X-Misar-Signature` header alongside
  `X-Misar-Timestamp`, but this package ships no helper to check it — verify it yourself
  with `System.Security.Cryptography.HMACSHA256` and
  `CryptographicOperations.FixedTimeEquals`. (The Go, Python, Ruby, Dart and Flutter SDKs
  do ship one.)

## Install

```bash
dotnet add package MisarMail --version 1.0.0
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

using var mail = new MisarMailClient(Environment.GetEnvironmentVariable("MISARMAIL_API_KEY")!);

var sent = await mail.Email_SendAsync(new {
    from = new { email = "you@yourdomain.com", name = "Your App" },
    to = new[] { new { email = "someone@example.com" } },
    subject = "Hello",
    html = "<p>Hi there</p>",
});

Console.WriteLine(sent.GetProperty("message_id").GetString());
```

## Primary functions

### Send a transactional email

`from` is a single address object and `to` is an array of them. Pass an
`idempotency_key` and a retry can never send twice — the response comes back with
`idempotent: true` the second time.

```csharp
var res = await mail.Email_SendAsync(new {
    from = new { email = "receipts@yourdomain.com", name = "Acme" },
    to = new[] { new { email = "customer@example.com" } },
    reply_to = new { email = "support@yourdomain.com" },
    subject = "Your receipt",
    html = "<p>Thanks for your order.</p>",
    text = "Thanks for your order.",
    tags = new[] { "receipt" },
    metadata = new { order_id = "ord-1041" },
    idempotency_key = "ord-1041-receipt",
});

res.GetProperty("message_id").GetString();   // "msg-…"
```

### List and create contacts

Responses are enveloped. `Contacts_ListAsync` returns `{ success, data, pagination }`
and takes the filters as a raw query string; `Contacts_CreateAsync` returns
`{ success, data }` with the contact under `data`.

```csharp
var page = await mail.Contacts_ListAsync("page=1&limit=50&status=subscribed");
Console.WriteLine($"{page.GetProperty("data").GetArrayLength()} of {page.GetProperty("pagination").GetProperty("total")}");

var created = await mail.Contacts_CreateAsync(new {
    email = "new@example.com",
    firstName = "Ada",
    lastName = "Lovelace",
    tags = new[] { "beta" },
    customFields = new { plan = "pro" },
});

Console.WriteLine(created.GetProperty("data").GetProperty("id").GetString());
```

`Contacts_GetAsync` and `Contacts_DeleteAsync` take the contact id, which the route reads
from the query string rather than a path segment. `Contacts_UpdateAsync` is different
again: it identifies the contact by **email address**, not by id, and merges that address
into whatever payload you pass.

```csharp
await mail.Contacts_UpdateAsync("ada@example.com", new { status = "unsubscribed" });
```

### Bulk import contacts

Counts come back under `summary`, and `errors` is a separate list of messages.

```csharp
var imported = await mail.Contacts_ImportContactsAsync(new {
    contacts = new[] {
        new { email = "a@example.com", firstName = "A" },
        new { email = "b@example.com", firstName = "B" },
    },
    updateExisting = true,
});

imported.GetProperty("summary");   // { imported, updated, skipped, errors }
imported.GetProperty("errors");    // array of strings
```

### Create and send a campaign

Campaigns take `fromName` and `fromEmail` as separate fields — there is no `from` object
here, unlike `Email_SendAsync`. `Campaigns_SendCampaignAsync` queues it and reports it as
`scheduled`.

```csharp
var campaign = await mail.Campaigns_CreateAsync(new {
    name = "March launch",
    subject = "We just shipped",
    fromName = "Ada at Acme",
    fromEmail = "hello@yourdomain.com",
    replyTo = "support@yourdomain.com",
    bodyHtml = "<h1>It's live</h1>",
    segmentId = "seg-123",
});

string id = campaign.GetProperty("data").GetProperty("id").GetString()!;
var queued = await mail.Campaigns_SendCampaignAsync(id);
Console.WriteLine($"{queued.GetProperty("campaignId")} {queued.GetProperty("status")}");  // … scheduled
```

Only `draft`, `scheduled` or `paused` campaigns can be updated, and only `draft`
campaigns can be deleted.

### Validate an address

Each call spends a credit, and the response tells you what is left.

```csharp
var check = await mail.Validate_EmailAsync("someone@example.com");
var verdict = check.GetProperty("data");

verdict.GetProperty("is_valid").GetBoolean();
verdict.GetProperty("score").GetDouble();                       // 0–1 confidence
verdict.GetProperty("checks");                                  // { syntax, mx, smtp }
verdict.GetProperty("flags").GetProperty("disposable").GetBoolean();
check.GetProperty("credits").GetProperty("balance_after").GetInt32();
```

### Render a template

```csharp
var rendered = await mail.Templates_RenderAsync(new {
    template_id = "tpl-123",
    variables = new { name = "Ada", plan = "Pro" },
});

rendered.GetProperty("data").GetProperty("subject").GetString();   // "Welcome, Ada"
rendered.GetProperty("data").GetProperty("html");
```

### Track events and revenue

The event name field is `event_name`, and purchase totals are integer **cents** in
`total_cents`.

```csharp
await mail.Track_EventAsync(new {
    email = "customer@example.com",
    event_name = "viewed_pricing",
    event_data = new { plan = "pro" },
});

var purchase = await mail.Track_PurchaseAsync(new {
    email = "customer@example.com",
    order_id = "ord-1041",
    total_cents = 9900,
    currency = "USD",
    items = new[] { new { name = "Pro annual", quantity = 1, price_cents = 9900 } },
});

purchase.GetProperty("attribution");   // which campaign or automation earned it
```

### Read analytics and manage keys

Without `campaignId` you get aggregate usage and totals for the period; with one you get
that campaign's stats and rates. `Keys_ListAsync` returns the keys under **`keys`**, not
`data`, and `Keys_CreateAsync` returns the raw key exactly once.

```csharp
var overall = await mail.Analytics_OverviewAsync("startDate=2026-04-01&endDate=2026-04-30");
var one = await mail.Analytics_OverviewAsync($"campaignId={id}");

var keys = await mail.Keys_ListAsync();
keys.GetProperty("keys").GetArrayLength();

var fresh = await mail.Keys_CreateAsync(new { name = "CI", scopes = new[] { "send", "read" } });
fresh.GetProperty("key").GetString();   // shown once and never again
```

## Errors

Three exception types, all in the `MisarMail` namespace:

| Type | When |
| --- | --- |
| `MisarMailException` | Any non-2xx API response. Carries `Status`. |
| `MisarMailNetworkException` | The request never got an answer, or every retry was spent. `Status` is `0`. |
| `MisarMailPlanLimitException` | The subscription behind the key does not cover the call. |

Both narrower types derive from `MisarMailException`, so `catch (MisarMailException)`
catches everything the SDK throws. The base type exposes three properties so you don't
have to compare status codes by hand: `IsUnauthorized` (401), `IsPlanDenied`
(402/403/429) and `IsRetryable` (429 or 5xx).

### Plan limits

Both a spent allowance and a feature that is not on the plan answer **`403`**, carrying
`code: "plan_limit_exceeded"`. The SDK keys on that code rather than the status, which is
why a refusal is typed correctly even though 403 is otherwise an authorization failure.
It throws `MisarMailPlanLimitException` and **does not retry** — retrying cannot help
until the allowance resets or the plan changes. Read `UpgradeUrl` to send the user
somewhere useful.

```csharp
try {
    await mail.Campaigns_CreateAsync(new {
        name = "Blast", subject = "We just shipped",
        fromName = "Your Name", fromEmail = "you@yourdomain.com",
    });
} catch (MisarMailPlanLimitException e) {
    Console.Error.WriteLine($"{e.Feature} exhausted on {e.Plan}: {e.UpgradeUrl} (retry after {e.RetryAfter})");
}
```

`Plan_GetAsync` returns `plan`, `sending` (the per-day and per-month email caps), `usage`
— an array with one entry per metered feature, each carrying `used`, `limit` and
`remaining` — and `upgrade`, which is null until a quota is tight. A null `limit` means
unlimited, and `remaining` is null alongside it rather than 0. Read it before an
expensive call rather than discovering the ceiling through a refusal.

The key needs the `read` or `subscription` scope.

```csharp
var plan = await mail.Plan_GetAsync();
Console.WriteLine($"{plan.GetProperty("sending")} {plan.GetProperty("usage")}");
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1`, which the SDK
handles for you:

| Method | Route |
| --- | --- |
| `Streaming_GenerateEmailAsync` | `POST /api/ai/generate-email/stream` |
| `Streaming_CampaignSendAsync` | `GET /api/campaigns/{id}/send-stream` |

Frames are unnamed (`data: {…}`, with no `event:` line) and the stream ends with
`data: [DONE]`, which the SDK consumes rather than handing on. Each
`MisarMailStreamEvent` carries `Event` (normally null), `Data` (the parsed
`JsonElement?`) and `Raw` (the payload exactly as received). A stream is never retried:
replaying one that failed mid-flight would duplicate whatever you had already read.

```csharp
await foreach (var frame in mail.Streaming_GenerateEmailAsync(new { prompt = "a launch email" }))
    Console.Write(frame.Data?.GetProperty("delta").GetString());

await foreach (var frame in mail.Streaming_CampaignSendAsync(id))
    Console.WriteLine(frame.Raw);
```

## License

MIT — see [LICENSE](LICENSE).
