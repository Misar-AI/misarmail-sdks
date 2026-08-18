# MisarMail Go SDK

MisarMail is a transactional **and** marketing email platform. This is its
official Go client for the HTTP API at `https://api.misar.io/mail/v1`:
transactional sends, marketing campaigns with A/B tests, contacts, templates,
automations, sending-domain and DMARC verification, deliverability scoring,
address validation, event and revenue tracking, analytics, webhooks, keys,
wallet and plan/billing.

It targets **Go 1.22 or newer** (`go.mod`) and pulls in nothing outside the
standard library. Every call takes a `context.Context`.

Full reference: [misarmail.com/docs](https://misarmail.com/docs).

## Features

Grouped by the resource fields on `*misarmail.Client`:

- **Transactional send** — `Email.Send`; `Sandbox` (`Send`, `List`, `Delete`)
  for a send that is captured instead of delivered.
- **Campaigns** — `Campaigns` (`List`, `Create`, `Get`, `Update`, `Send`,
  `Delete`) and `ABTests` (`List`, `Create`, `Get`, `SetWinner`).
- **Audience** — `Contacts` (`List`, `Create`, `Get`, `Update`, `Delete`,
  `Import`), `Segments.Members`, `LandingPages.Create`.
- **Content** — `Templates` (`List`, `Create`, `Get`, `Update`, `Delete`,
  `Render` with variable substitution) and `Ai.SubjectLines`.
- **Automations** — `Automations` (`List`, `Create`, `Get`, `Update`, `Delete`,
  `Activate`).
- **Deliverability and sending infrastructure** — `Domains` (`List`, `Create`,
  `Get`, `Verify`, `Delete`), `Dmarc` (`Check`, `ListDomains`, `AddDomain`,
  `RemoveDomain`), `Deliverability` (`Audit`, `Score`), `DedicatedIPs`,
  `Warmup.Get`, `Inbound` routes, `EmailAccounts.List`, `Emails` (`List`,
  `Get`, `Update`).
- **Analytics and attribution** — `Analytics.Overview`, `Track` (`Event`,
  `Purchase`), `Revenue.Attribution`, `Usage.Get`.
- **Validation** — `Validate.Email`.
- **Plan, billing and credits** — `Plan` (`Get`, `Limits`, `Monetization`),
  `Billing` (`Subscription`, `Checkout`), `Subscription` (`Get`, `Upsert`,
  `Cancel`), `Wallet` (`Get`, `Credit`, `Debit`), `CreditRates.List`,
  `TeamMembers.Get`, `Monetization.Tip`.
- **Developer** — `Keys` (`List`, `Create`, `Get`, `Revoke`), `Webhooks`
  (`List`, `Create`, `Get`, `Update`, `Delete`, `Test`), `Streaming`.

Some route groups that other MisarMail SDKs expose are **not** in this client:
forms, the subscriber preference centre, the template marketplace, drafts and
labels, the shared inbox, notifications, integrations, workspace settings,
referrals, batch address validation, and segment CRUD beyond
`Segments.Members`. Call those over HTTP directly until they land here.

Aliases and workspaces are deliberately absent everywhere: those routes accept
a browser session only, never an `msk_` key.

## What's in the package

`misarmail.New(apiKey string, opts ...Option) *Client` builds the client. Each
resource hangs off it as an exported field (`mail.Contacts`, `mail.Campaigns`,
…), and most calls return a typed struct pointer; the endpoints added from the
route spec return `map[string]any`.

Options, all with `With` prefixes: `WithBaseURL`, `WithAPIBase`,
`WithMaxRetries`, `WithTimeout`, `WithHTTPClient`.

Transport defaults, read from `misarmail/client.go`:

| Behaviour | Default |
| --- | --- |
| Base URL | `https://api.misar.io/mail/v1` |
| API base (routes outside `/v1`) | `https://api.misar.io/mail` |
| Attempts | 3 (`WithMaxRetries`) |
| Back-off | 200ms doubling per attempt |
| HTTP timeout | 30s (`WithTimeout`) |
| Retried statuses | 429, 500, 502, 503, 504 |

Errors are three concrete types — `*APIError`, `*NetworkError` and
`*PlanLimitError` — matched with `errors.As`. `Streaming` reads the two
Server-Sent Events endpoints. Inbound webhooks are verified in-package with
`VerifyWebhookSignature` / `SignWebhook`.

## Install

```bash
go get github.com/Misar-AI/misarmail-sdks/go
```

```go
import "github.com/Misar-AI/misarmail-sdks/go/misarmail"
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
	"fmt"
	"log"

	"github.com/Misar-AI/misarmail-sdks/go/misarmail"
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

## License

MIT — see [LICENSE](LICENSE).
