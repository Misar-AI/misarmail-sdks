# MisarMail .NET SDK

> Send transactional email and run marketing campaigns from C# — async/await, cancellation, no dependencies.

[![NuGet](https://img.shields.io/nuget/v/MisarMail)](https://www.nuget.org/packages/MisarMail)
[![net](https://img.shields.io/badge/.NET-8.0-512BD4)](https://www.nuget.org/packages/MisarMail)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 91 methods · SSE streaming · no dependencies beyond the BCL**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

Targets `net8.0`. The surface is flat — `Group_MethodAsync`, not nested resource objects — and every method takes an optional `CancellationToken` and returns `Task<JsonElement>`.

---

## Install

### dotnet CLI

```bash
dotnet add package MisarMail --version 5.0.1
```

### PackageReference

```xml
<PackageReference Include="MisarMail" Version="5.0.1" />
```

### Package Manager

```powershell
Install-Package MisarMail -Version 5.0.1
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```csharp
using MisarMail;

using var mail = new MisarMailClient(Environment.GetEnvironmentVariable("MISARMAIL_API_KEY")!);
```

---

## Resources

The surface is flat: you call `mail.Group_MethodAsync(…)`. The **Methods** column lists the middle segment — `Email` + `Send` is `mail.Email_SendAsync`.

### Send

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Email_…Async` | `Send` | Transactional send — cc/bcc/reply-to, tags, metadata, `idempotency_key`. |
| `Sandbox_…Async` | `Send`, `List`, `Delete` | Test sends captured instead of delivered. |

### Campaigns and tests

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Campaigns_…Async` | `List`, `Create`, `Get`, `Update`, `SendCampaign`, `Delete` | Marketing campaigns: draft, edit, queue for send. |
| `AbTests_…Async` | `List`, `Create`, `Get`, `SetWinner` | Subject, content, send-time, from-name and preheader splits, and winner selection. |

### Audience

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Contacts_…Async` | `List`, `Create`, `Get`, `Update`, `Delete`, `ImportContacts` | Subscribers, plus bulk import. |
| `Segments_…Async` | `Members` | Dynamic audience segments and their membership. |
| `LandingPages_…Async` | `Create` | Hosted landing pages with an email capture form. |

### Content

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Templates_…Async` | `List`, `Create`, `Get`, `Update`, `Delete`, `Render` | Reusable templates and server-side variable rendering. |
| `Ai_…Async` | `SubjectLines` | AI-generated subject lines. |

### Automations

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Automations_…Async` | `List`, `Create`, `Get`, `Update`, `Delete`, `Activate` | Trigger-based workflows — welcome series, drips, re-engagement. |

### Deliverability and sending infrastructure

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Domains_…Async` | `List`, `Create`, `Get`, `Verify`, `Delete` | Sending domains and their DNS verification. |
| `Dmarc_…Async` | `Check`, `ListDomains`, `AddDomain`, `RemoveDomain` | Live SPF/DKIM/DMARC record checks and monitored domains. |
| `Deliverability_…Async` | `Audit`, `Score` | Deliverability score, audit and remediation guidance. |
| `DedicatedIPs_…Async` | `List`, `Create`, `Update`, `Delete` | Dedicated sending IPs. |
| `Warmup_…Async` | `Get` | IP/domain warm-up progress and today's remaining capacity. |
| `Inbound_…Async` | `List`, `Create`, `Get`, `Delete` | Inbound routing domains, so replies land in the unified inbox. |

### Mailbox and inbox

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Emails_…Async` | `List`, `Get`, `Update` | Stored messages in the mailbox. |
| `EmailAccounts_…Async` | `List` | Connected mailbox accounts. |

### Analytics and attribution

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Analytics_…Async` | `Overview` | Delivery and engagement stats — aggregate, or one campaign. |
| `Track_…Async` | `Event`, `Purchase` | Custom events and ecommerce purchases. |
| `Revenue_…Async` | `Attribution` | Revenue attributed back to email. |
| `Usage_…Async` | `Get` | Metered usage for a period. |

### Validation

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Validate_…Async` | `Email` | Address validation, and the credit balance behind it. |

### Plan, billing and credits

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Plan_…Async` | `Get`, `Monetization`, `Limits` | Current plan, quotas and monetization stats. |
| `Billing_…Async` | `Subscription`, `Checkout` | Subscription state and checkout. |
| `Subscription_…Async` | `Get`, `Upsert`, `Cancel` | Subscription read/write and per-product plan limits. |
| `Wallet_…Async` | `Get`, `Credit`, `Debit` | Credit balance, credit and debit. |
| `CreditRates_…Async` | `List` | What each metered action costs in credits. |
| `TeamMembers_…Async` | `Get` | Team members on the account. |
| `Monetization_…Async` | `Tip` | Newsletter tips. |

### Developer

| Resource | Methods | What it covers |
| --- | --- | --- |
| `Keys_…Async` | `List`, `Create`, `Get`, `Revoke` | API keys — create, list, revoke. |
| `Webhooks_…Async` | `List`, `Create`, `Get`, `Update`, `Delete`, `Test` | Webhook endpoints, plus a test delivery. |
| `Streaming_…Async` | `GenerateEmail`, `CampaignSend` | The two Server-Sent Events endpoints. |

---

## Client

| Thing | Detail |
| --- | --- |
| Entry point | `new MisarMailClient(apiKey, baseUrl, maxRetries, httpClient)`. Implements `IDisposable` and owns its `HttpClient` unless you pass one. |
| Defaults | `https://api.misar.io/mail/v1`, `maxRetries` 3, a fresh `HttpClient` with a 30-second timeout. |
| Validation | A blank `apiKey` throws `ArgumentException` immediately. |
| Payloads | Any `object`, serialized with `System.Text.Json` — anonymous objects work as-is. |
| Results | `Task<JsonElement>`; read with `GetProperty` or deserialize into your own records. |
| Cancellation | Every method takes an optional `CancellationToken`. |
| Retried | `429`, `500`, `502`, `503`, `504`, `HttpRequestException` and `TaskCanceledException` — 500 ms then 1 s. |
| Never retried | Plan refusals, and streams. |
| Errors | `MisarMailException`, `MisarMailNetworkException`, `MisarMailPlanLimitException`. |
| Webhook verifier | Not shipped here — verify `HMAC-SHA256(timestamp + "." + rawBody)` yourself with `HMACSHA256` and `CryptographicOperations.FixedTimeEquals`. (Go, Python, Ruby and Dart ship one.) |

---

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

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- NuGet — https://www.nuget.org/packages/MisarMail

MIT © [Misar AI](https://misar.io)
