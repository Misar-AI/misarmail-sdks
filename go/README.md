# MisarMail Go SDK

> Send transactional email and run marketing campaigns from Go — context-aware, standard library only.

[![Go Reference](https://pkg.go.dev/badge/github.com/Misar-AI/misarmail-sdks/go/v5.svg)](https://pkg.go.dev/github.com/Misar-AI/misarmail-sdks/go/v5)
[![go](https://img.shields.io/badge/go-1.22%2B-00ADD8)](https://pkg.go.dev/github.com/Misar-AI/misarmail-sdks/go/v5)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**33 resource groups · 91 methods · SSE streaming · webhook signature verification**

MisarMail is one API for both halves of your email: the receipts and password resets your product sends, and the campaigns, segments and automations your marketing team runs on the same contact list and the same verified domains.

Go 1.22+, nothing outside the standard library, and every call takes a `context.Context`. Most calls return a typed struct pointer; the route-spec endpoints return `map[string]any`.

---

## Install

### go get

```bash
go get github.com/Misar-AI/misarmail-sdks/go/v5
```

### Import

```go
import "github.com/Misar-AI/misarmail-sdks/go/v5/misarmail"
```

---

## Authentication

Create a developer key at https://mail.misar.io/developers. It starts with `msk_` and is
sent as `Authorization: Bearer msk_…`.

Every call is metered against the subscription attached to that key. There is no
client-side limit checking — the server decides, and the SDK surfaces its answer. A plan
refusal answers **403** with `code: "plan_limit_exceeded"` and is never retried.

```go
mail := misarmail.New(os.Getenv("MISARMAIL_API_KEY"))
```

---

## Resources

Every group the client exposes, and every public method on it.

### Send

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Email` | `Send` | Transactional send — cc/bcc/reply-to, tags, metadata, `idempotency_key`. |
| `mail.Sandbox` | `Send`, `List`, `Delete` | Test sends captured instead of delivered. |

### Campaigns and tests

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Campaigns` | `List`, `Create`, `Get`, `Update`, `Send`, `Delete` | Marketing campaigns: draft, edit, queue for send. |
| `mail.ABTests` | `List`, `Create`, `Get`, `SetWinner` | Subject, content, send-time, from-name and preheader splits, and winner selection. |

### Audience

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Contacts` | `List`, `Create`, `Get`, `Update`, `Delete`, `Import` | Subscribers, plus bulk import. |
| `mail.Segments` | `Members` | Dynamic audience segments and their membership. |
| `mail.LandingPages` | `Create` | Hosted landing pages with an email capture form. |

### Content

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Templates` | `List`, `Create`, `Get`, `Update`, `Delete`, `Render` | Reusable templates and server-side variable rendering. |
| `mail.Ai` | `SubjectLines` | AI-generated subject lines. |

### Automations

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Automations` | `List`, `Create`, `Get`, `Update`, `Delete`, `Activate` | Trigger-based workflows — welcome series, drips, re-engagement. |

### Deliverability and sending infrastructure

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Domains` | `List`, `Create`, `Get`, `Verify`, `Delete` | Sending domains and their DNS verification. |
| `mail.Dmarc` | `Check`, `ListDomains`, `AddDomain`, `RemoveDomain` | Live SPF/DKIM/DMARC record checks and monitored domains. |
| `mail.Deliverability` | `Audit`, `Score` | Deliverability score, audit and remediation guidance. |
| `mail.DedicatedIPs` | `List`, `Create`, `Update`, `Delete` | Dedicated sending IPs. |
| `mail.Warmup` | `Get` | IP/domain warm-up progress and today's remaining capacity. |
| `mail.Inbound` | `List`, `Create`, `Get`, `Delete` | Inbound routing domains, so replies land in the unified inbox. |

### Mailbox and inbox

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Emails` | `List`, `Get`, `Update` | Stored messages in the mailbox. |
| `mail.EmailAccounts` | `List` | Connected mailbox accounts. |

### Analytics and attribution

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Analytics` | `Overview` | Delivery and engagement stats — aggregate, or one campaign. |
| `mail.Track` | `Event`, `Purchase` | Custom events and ecommerce purchases. |
| `mail.Revenue` | `Attribution` | Revenue attributed back to email. |
| `mail.Usage` | `Get` | Metered usage for a period. |

### Validation

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Validate` | `Email` | Address validation, and the credit balance behind it. |

### Plan, billing and credits

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Plan` | `Get`, `Monetization`, `Limits` | Current plan, quotas and monetization stats. |
| `mail.Billing` | `Subscription`, `Checkout` | Subscription state and checkout. |
| `mail.Subscription` | `Get`, `Upsert`, `Cancel` | Subscription read/write and per-product plan limits. |
| `mail.Wallet` | `Get`, `Credit`, `Debit` | Credit balance, credit and debit. |
| `mail.CreditRates` | `List` | What each metered action costs in credits. |
| `mail.TeamMembers` | `Get` | Team members on the account. |
| `mail.Monetization` | `Tip` | Newsletter tips. |

### Developer

| Resource | Methods | What it covers |
| --- | --- | --- |
| `mail.Keys` | `List`, `Create`, `Get`, `Revoke` | API keys — create, list, revoke. |
| `mail.Webhooks` | `List`, `Create`, `Get`, `Update`, `Delete`, `Test` | Webhook endpoints, plus a test delivery. |
| `mail.Streaming` | `GenerateEmail`, `CampaignSend` | The two Server-Sent Events endpoints. |

---

## Client

| Thing | Detail |
| --- | --- |
| Entry point | `misarmail.New(apiKey string, opts ...Option) *Client` — every resource is an exported field. |
| Options | `WithBaseURL`, `WithAPIBase`, `WithMaxRetries`, `WithTimeout`, `WithHTTPClient`. |
| Base URL | `https://api.misar.io/mail/v1` |
| API base (outside `/v1`) | `https://api.misar.io/mail` |
| Attempts / backoff | 3, doubling from 200 ms. |
| HTTP timeout | 30s |
| Retried | `429`, `500`, `502`, `503`, `504` |
| Never retried | Plan refusals, and streams. |
| Errors | `*APIError`, `*NetworkError`, `*PlanLimitError` — match with `errors.As`. |
| Webhook verifier | `VerifyWebhookSignature` / `SignWebhook`, tolerance `DefaultWebhookTolerance` (300s). |

---

## Quick start

```go
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/Misar-AI/misarmail-sdks/go/v5/misarmail"
)

func main() {
	mail := misarmail.New("msk_your_key")
	ctx := context.Background()

	sent, err := mail.Email.Send(ctx, &misarmail.SendEmailRequest{
		From:    "you@yourdomain.com",
		To:      []string{"someone@example.com"},
		Subject: "Hello",
		HTML:    "<p>Hi there</p>",
	})
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(sent.MessageID)
}
```

## Primary functions

Send a transactional email, with tags and metadata for later attribution:

```go
sent, err := mail.Email.Send(ctx, &misarmail.SendEmailRequest{
	From:     "you@yourdomain.com",
	To:       []string{"someone@example.com"},
	ReplyTo:  "support@yourdomain.com",
	Subject:  "Welcome aboard",
	HTML:     "<p>Thanks for signing up.</p>",
	Text:     "Thanks for signing up.",
	Tags:     []string{"onboarding"},
	Metadata: map[string]string{"user_id": "u_123"},
})
```

List contacts a page at a time:

```go
page, err := mail.Contacts.List(ctx, &misarmail.ListParams{Page: 1, Limit: 50})
for _, c := range page.Data {
	fmt.Println(c.Email, c.Status)
}
```

Create one:

```go
contact, err := mail.Contacts.Create(ctx, &misarmail.ContactInput{
	Email:     "someone@example.com",
	FirstName: "Ada",
	LastName:  "Lovelace",
	Tags:      []string{"beta"},
})
```

Create a campaign and send it. Campaigns carry `FromName` and `FromEmail`
directly — there is no nested from object:

```go
campaign, err := mail.Campaigns.Create(ctx, &misarmail.CreateCampaignRequest{
	Name:      "August launch",
	Subject:   "We just shipped",
	FromName:  "Ada at Example",
	FromEmail: "ada@yourdomain.com",
	BodyHTML:  "<h1>It is live</h1>",
})
if err == nil {
	_, err = mail.Campaigns.Send(ctx, campaign.ID)
}
```

Validate an address before you send to it:

```go
check, err := mail.Validate.Email(ctx, "someone@exmaple.com")
fmt.Println(check.Valid, check.Disposable, check.MXFound, check.Suggestion)
```

Render a template with variables:

```go
rendered, err := mail.Templates.Render(ctx, &misarmail.RenderTemplateRequest{
	TemplateID: "tmpl_123",
	Variables:  map[string]any{"first_name": "Ada"},
})
fmt.Println(rendered.HTML)
```

Read the plan before an expensive call rather than discovering the ceiling
through a refusal. A nil `Limit` means unlimited, and `Remaining` is nil
alongside it rather than 0:

```go
plan, err := mail.Plan.Get(ctx)
for _, u := range plan.Usage {
	if u.Limit == nil {
		fmt.Printf("%s: %d used, unlimited\n", u.Feature, u.Used)
		continue
	}
	fmt.Printf("%s: %d of %d used\n", u.Feature, u.Used, *u.Limit)
}
```

Verify an inbound webhook against the raw request body. MisarMail signs each
delivery as `HMAC-SHA256(timestamp + "." + rawBody)` and sends the digest in
`X-Misar-Signature` with the Unix timestamp in `X-Misar-Timestamp`; the check
rejects anything more than `DefaultWebhookTolerance` (300s) out of date and
compares in constant time. `SignWebhook` produces the same digest, which is how
you fabricate a valid delivery in your own tests:

```go
func handler(w http.ResponseWriter, r *http.Request) {
	raw, _ := io.ReadAll(r.Body) // the raw bytes, not a re-marshalled struct
	ok := misarmail.VerifyWebhookSignature(
		raw,
		r.Header.Get("X-Misar-Signature"),
		r.Header.Get("X-Misar-Timestamp"),
		os.Getenv("MISARMAIL_WEBHOOK_SECRET"),
		misarmail.DefaultWebhookTolerance,
	)
	if !ok {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}
}
```

## Errors

Every call returns one of three concrete error types; match with `errors.As`.

| Type | Raised for |
| --- | --- |
| `*misarmail.APIError` | any other non-2xx: `Status`, `Message` |
| `*misarmail.NetworkError` | transport failure; `Unwrap` gives the cause |
| `*misarmail.PlanLimitError` | the subscription blocks the call |

A plan refusal answers **403** carrying `code: "plan_limit_exceeded"`. The
client keys on that marker rather than on the status — 403 is otherwise an
authorization failure, and a spent-allowance 429 is indistinguishable from a
rate limit by status alone — so a refusal is typed correctly wherever it
arrives. It is **never retried**: retrying cannot help until the allowance
resets or the plan changes. `PlanLimitError` carries `Status`, `Message`,
`Plan`, `Feature`, `UpgradeURL` and `RetryAfter` (seconds, 0 when the API did
not supply one), so you can send the user somewhere useful:

```go
_, err := mail.Campaigns.Send(ctx, campaign.ID)

var limit *misarmail.PlanLimitError
var apiErr *misarmail.APIError
switch {
case errors.As(err, &limit):
	log.Printf("%s exhausted on %s: %s", limit.Feature, limit.Plan, limit.UpgradeURL)
case errors.As(err, &apiErr):
	log.Printf("API error %d: %s", apiErr.Status, apiErr.Message)
}
```

## Streaming

Two endpoints stream Server-Sent Events. Both sit **outside** `/v1` and use the
API base, which the SDK handles for you:

| Method | Route |
| --- | --- |
| `Streaming.GenerateEmail` | `POST /api/ai/generate-email/stream` |
| `Streaming.CampaignSend` | `GET /api/campaigns/{id}/send-stream` |

Frames are unnamed (`data: {…}`, no `event:` line) and the stream ends with
`data: [DONE]`, which the SDK consumes rather than handing on. Each frame
arrives as a `StreamEvent` with `Data` (the decoded JSON, nil when the payload
was not JSON) and `Raw` (the payload as received). Returning an error from the
callback stops the stream and returns that error — the way to break out early.
A stream is never retried: replaying one that failed mid-flight would duplicate
whatever you had already read.

```go
err := mail.Streaming.GenerateEmail(ctx,
	map[string]any{"prompt": "a launch email"},
	func(e misarmail.StreamEvent) error {
		if delta, ok := e.Data["delta"].(string); ok {
			fmt.Print(delta)
		}
		return nil // returning an error stops the stream
	})
```

---

## Links

- Website — https://www.misarmail.com
- App — https://mail.misar.io
- Parent — https://misar.io
- Documentation — https://docs.misar.io/mail
- Source — https://github.com/Misar-AI/misarmail-sdks
- pkg.go.dev — https://pkg.go.dev/github.com/Misar-AI/misarmail-sdks/go/v5

MIT © [Misar AI](https://misar.io)
