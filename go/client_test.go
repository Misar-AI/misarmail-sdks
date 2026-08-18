package misarmail_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Misar-AI/misarmail-sdks/go/v5/misarmail"
)

// newClient points the SDK at a test server.
func newClient(t *testing.T, h http.HandlerFunc) *misarmail.Client {
	t.Helper()
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	return misarmail.New("mmk_test", misarmail.WithBaseURL(srv.URL))
}

func TestPlanGet(t *testing.T) {
	c := newClient(t, func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/plan" {
			t.Errorf("path = %q, want /plan", r.URL.Path)
		}
		if got := r.Header.Get("Authorization"); got != "Bearer mmk_test" {
			t.Errorf("Authorization = %q", got)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"plan": {"slug":"starter","name":"Starter"},
			"sending": {"emails_per_day":500,"emails_per_month":10000},
			"usage": [{"feature":"emails","used":120,"limit":500,"remaining":380}],
			"upgrade": null
		}`))
	})

	got, err := c.Plan.Get(context.Background())
	if err != nil {
		t.Fatalf("Plan.Get: %v", err)
	}
	if got.Plan.Slug != "starter" {
		t.Errorf("plan slug = %q, want starter", got.Plan.Slug)
	}
	if len(got.Usage) != 1 || got.Usage[0].Used != 120 {
		t.Errorf("usage = %+v", got.Usage)
	}
	if got.Upgrade != nil {
		t.Errorf("upgrade should be nil while the plan has headroom")
	}
}

// A spent allowance answers 429 — identical by status to a rate limit — so the
// client must distinguish them by body and refuse to retry the plan refusal.
func TestPlanLimitIsNotRetried(t *testing.T) {
	attempts := 0
	c := newClient(t, func(w http.ResponseWriter, r *http.Request) {
		attempts++
		w.Header().Set("X-Misar-Plan", "starter")
		w.Header().Set("X-Misar-Upgrade-Url", "https://misarmail.com/pricing")
		w.Header().Set("Retry-After", "600")
		w.WriteHeader(http.StatusTooManyRequests)
		w.Write([]byte(`{
			"error": "Monthly send allowance spent.",
			"code": "plan_limit_exceeded",
			"upgrade": {"feature":"emails","currentPlanSlug":"starter"}
		}`))
	})

	_, err := c.Plan.Get(context.Background())

	var limit *misarmail.PlanLimitError
	if !errors.As(err, &limit) {
		t.Fatalf("error = %T (%v), want *PlanLimitError", err, err)
	}
	if attempts != 1 {
		t.Errorf("attempts = %d, want 1 — a plan refusal must not burn the retry budget", attempts)
	}
	if limit.Plan != "starter" {
		t.Errorf("Plan = %q, want starter", limit.Plan)
	}
	if limit.UpgradeURL != "https://misarmail.com/pricing" {
		t.Errorf("UpgradeURL = %q", limit.UpgradeURL)
	}
	if limit.RetryAfter != 600 {
		t.Errorf("RetryAfter = %d, want 600", limit.RetryAfter)
	}
	if limit.Feature != "emails" {
		t.Errorf("Feature = %q, want emails", limit.Feature)
	}
}

// A plain rate-limit 429 carries no plan marker and must still be retried.
func TestRateLimitIsStillRetried(t *testing.T) {
	attempts := 0
	c := newClient(t, func(w http.ResponseWriter, r *http.Request) {
		attempts++
		if attempts == 1 {
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error":"Rate limit exceeded"}`))
			return
		}
		w.Write([]byte(`{"plan":{"slug":"starter","name":"Starter"}}`))
	})

	if _, err := c.Plan.Get(context.Background()); err != nil {
		t.Fatalf("Plan.Get after retry: %v", err)
	}
	if attempts != 2 {
		t.Errorf("attempts = %d, want 2", attempts)
	}
}

func TestAPIErrorOnUnauthorized(t *testing.T) {
	c := newClient(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error":"Invalid or missing API key"}`))
	})

	_, err := c.Plan.Get(context.Background())

	var apiErr *misarmail.APIError
	if !errors.As(err, &apiErr) {
		t.Fatalf("error = %T, want *APIError", err)
	}
	if apiErr.Status != http.StatusUnauthorized {
		t.Errorf("status = %d", apiErr.Status)
	}
}
