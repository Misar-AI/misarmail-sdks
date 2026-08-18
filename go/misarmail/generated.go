package misarmail

import (
	"context"
	"net/http"
	"net/url"
)

// encodeQuery renders a query string with a leading "?", or "" when empty.
// The hand-written resources inline this; the generated ones share it.
func encodeQuery(q url.Values) string {
	if s := q.Encode(); s != "" {
		return "?" + s
	}
	return ""
}

// ── Generated from scripts/sdk-endpoint-spec.json ─────────────────────────────
//
// These twenty endpoints were missing from every SDK except TypeScript. The
// spec is derived from the route handlers, so this stays in step with the API.

type AiResource struct{ c *Client }

// SubjectLines calls POST /ai/subject-lines.
func (r *AiResource) SubjectLines(ctx context.Context, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodPost, "/ai/subject-lines", body, &out)
}

type CreditRatesResource struct{ c *Client }

// List calls GET /credit-rates.
func (r *CreditRatesResource) List(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/credit-rates", nil, &out)
}

type DeliverabilityResource struct{ c *Client }

// Audit calls GET /deliverability/audit.
func (r *DeliverabilityResource) Audit(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/deliverability/audit", nil, &out)
}

// Score calls GET /deliverability/score.
func (r *DeliverabilityResource) Score(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/deliverability/score", nil, &out)
}

type DmarcResource struct{ c *Client }

// Check calls GET /dmarc/check.
func (r *DmarcResource) Check(ctx context.Context, domain string, dkimSelector string) (map[string]any, error) {
	q := url.Values{}
	if domain != "" {
		q.Set("domain", domain)
	}
	if dkimSelector != "" {
		q.Set("dkim_selector", dkimSelector)
	}
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/dmarc/check"+encodeQuery(q), nil, &out)
}

// ListDomains calls GET /dmarc/domains.
func (r *DmarcResource) ListDomains(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/dmarc/domains", nil, &out)
}

// AddDomain calls POST /dmarc/domains.
func (r *DmarcResource) AddDomain(ctx context.Context, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodPost, "/dmarc/domains", body, &out)
}

// RemoveDomain calls DELETE /dmarc/domains.
func (r *DmarcResource) RemoveDomain(ctx context.Context, domainId string) (map[string]any, error) {
	q := url.Values{}
	if domainId != "" {
		q.Set("domain_id", domainId)
	}
	var out map[string]any
	return out, r.c.request(ctx, http.MethodDelete, "/dmarc/domains"+encodeQuery(q), nil, &out)
}

type EmailAccountsResource struct{ c *Client }

// List calls GET /email-accounts.
func (r *EmailAccountsResource) List(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/email-accounts", nil, &out)
}

type EmailsResource struct{ c *Client }

// List calls GET /emails.
func (r *EmailsResource) List(ctx context.Context, folder string, search string, limit string) (map[string]any, error) {
	q := url.Values{}
	if folder != "" {
		q.Set("folder", folder)
	}
	if search != "" {
		q.Set("search", search)
	}
	if limit != "" {
		q.Set("limit", limit)
	}
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/emails"+encodeQuery(q), nil, &out)
}

// Get calls GET /emails/:id.
func (r *EmailsResource) Get(ctx context.Context, id string) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/emails/"+url.PathEscape(id), nil, &out)
}

// Update calls PATCH /emails/:id.
func (r *EmailsResource) Update(ctx context.Context, id string, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodPatch, "/emails/"+url.PathEscape(id), body, &out)
}

type LandingPagesResource struct{ c *Client }

// Create calls POST /landing-pages.
func (r *LandingPagesResource) Create(ctx context.Context, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodPost, "/landing-pages", body, &out)
}

type MonetizationResource struct{ c *Client }

// Tip calls POST /monetization/tip.
func (r *MonetizationResource) Tip(ctx context.Context, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodPost, "/monetization/tip", body, &out)
}

// Limits calls GET /plan-limits.
func (r *PlanResource) Limits(ctx context.Context, product string) (map[string]any, error) {
	q := url.Values{}
	if product != "" {
		q.Set("product", product)
	}
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/plan-limits"+encodeQuery(q), nil, &out)
}

type RevenueResource struct{ c *Client }

// Attribution calls GET /revenue/attribution.
func (r *RevenueResource) Attribution(ctx context.Context, campaignId string, period string) (map[string]any, error) {
	q := url.Values{}
	if campaignId != "" {
		q.Set("campaign_id", campaignId)
	}
	if period != "" {
		q.Set("period", period)
	}
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/revenue/attribution"+encodeQuery(q), nil, &out)
}

type SegmentsResource struct{ c *Client }

// Members calls GET /segments/:id/members.
func (r *SegmentsResource) Members(ctx context.Context, id string, page string, limit string) (map[string]any, error) {
	q := url.Values{}
	if page != "" {
		q.Set("page", page)
	}
	if limit != "" {
		q.Set("limit", limit)
	}
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/segments/"+url.PathEscape(id)+"/members"+encodeQuery(q), nil, &out)
}

type SubscriptionResource struct{ c *Client }

// Get calls GET /subscription.
func (r *SubscriptionResource) Get(ctx context.Context, product string) (map[string]any, error) {
	q := url.Values{}
	if product != "" {
		q.Set("product", product)
	}
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/subscription"+encodeQuery(q), nil, &out)
}

// Upsert calls POST /subscription.
func (r *SubscriptionResource) Upsert(ctx context.Context, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodPost, "/subscription", body, &out)
}

// Cancel calls DELETE /subscription.
func (r *SubscriptionResource) Cancel(ctx context.Context, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodDelete, "/subscription", body, &out)
}

type TeamMembersResource struct{ c *Client }

// Get calls GET /team-members.
func (r *TeamMembersResource) Get(ctx context.Context, ownerId string) (map[string]any, error) {
	q := url.Values{}
	if ownerId != "" {
		q.Set("owner_id", ownerId)
	}
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/team-members"+encodeQuery(q), nil, &out)
}

type WalletResource struct{ c *Client }

// Get calls GET /wallet.
func (r *WalletResource) Get(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/wallet", nil, &out)
}

// Credit calls POST /wallet/credit.
func (r *WalletResource) Credit(ctx context.Context, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodPost, "/wallet/credit", body, &out)
}

// Debit calls POST /wallet/debit.
func (r *WalletResource) Debit(ctx context.Context, body map[string]any) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodPost, "/wallet/debit", body, &out)
}

type WarmupResource struct{ c *Client }

// Get calls GET /warmup.
func (r *WarmupResource) Get(ctx context.Context) (map[string]any, error) {
	var out map[string]any
	return out, r.c.request(ctx, http.MethodGet, "/warmup", nil, &out)
}
