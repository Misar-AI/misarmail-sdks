package misarmail_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"

	"github.com/misar-ai/misarmail-go/misarmail"
)

func newTestClient(server *httptest.Server) *misarmail.Client {
	return misarmail.New("test-key",
		misarmail.WithBaseURL(server.URL),
		misarmail.WithMaxRetries(3),
		misarmail.WithHTTPClient(server.Client()),
	)
}

func TestSendEmail(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/send" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"success": true, "message_id": "msg_123"})
	}))
	defer srv.Close()

	c := newTestClient(srv)
	resp, err := c.SendEmail(context.Background(), &misarmail.SendEmailRequest{
		From:    "sender@example.com",
		To:      []string{"recipient@example.com"},
		Subject: "Test",
		HTML:    "<p>Hello</p>",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !resp.Success {
		t.Error("expected Success to be true")
	}
	if resp.MessageID != "msg_123" {
		t.Errorf("expected message_id msg_123, got %s", resp.MessageID)
	}
}

func TestContactsList(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/contacts" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"data": []map[string]any{
				{"id": "c1", "email": "a@b.com", "status": "active", "created_at": "", "updated_at": ""},
			},
			"total": 1, "page": 1, "limit": 10,
		})
	}))
	defer srv.Close()

	c := newTestClient(srv)
	resp, err := c.ContactsList(context.Background(), 1, 10)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Data) != 1 {
		t.Errorf("expected 1 contact, got %d", len(resp.Data))
	}
	if resp.Data[0].Email != "a@b.com" {
		t.Errorf("expected email a@b.com, got %s", resp.Data[0].Email)
	}
}

func TestCampaignsList(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/campaigns" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"data": []map[string]any{
				{"id": "camp1", "name": "Test", "status": "draft", "subject": "Hi", "created_at": ""},
			},
			"total": 1,
		})
	}))
	defer srv.Close()

	c := newTestClient(srv)
	resp, err := c.CampaignsList(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Data) != 1 {
		t.Errorf("expected 1 campaign, got %d", len(resp.Data))
	}
}

func TestAnalyticsGet(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/analytics" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"sent": 100, "delivered": 95, "opens": 40, "clicks": 10,
			"bounces": 5, "unsubscribes": 2, "open_rate": 0.42, "click_rate": 0.10,
		})
	}))
	defer srv.Close()

	c := newTestClient(srv)
	resp, err := c.AnalyticsGet(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Sent != 100 {
		t.Errorf("expected Sent 100, got %d", resp.Sent)
	}
}

func TestValidateEmail(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/validate" {
			t.Errorf("unexpected request: %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"valid": true, "disposable": false, "mx_found": true, "suggestion": "",
		})
	}))
	defer srv.Close()

	c := newTestClient(srv)
	resp, err := c.ValidateEmail(context.Background(), "user@example.com")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !resp.Valid {
		t.Error("expected Valid to be true")
	}
}

func TestAPIError401(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]any{"error": "unauthorized"})
	}))
	defer srv.Close()

	c := newTestClient(srv)
	_, err := c.SendEmail(context.Background(), &misarmail.SendEmailRequest{
		From:    "a@b.com",
		To:      []string{"c@d.com"},
		Subject: "Test",
	})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	apiErr, ok := err.(*misarmail.APIError)
	if !ok {
		t.Fatalf("expected *APIError, got %T", err)
	}
	if apiErr.Status != 401 {
		t.Errorf("expected status 401, got %d", apiErr.Status)
	}
}

func TestRetry503(t *testing.T) {
	var counter atomic.Int32

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := counter.Add(1)
		if n < 3 {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"success": true, "message_id": "msg_retry"})
	}))
	defer srv.Close()

	c := newTestClient(srv)
	resp, err := c.SendEmail(context.Background(), &misarmail.SendEmailRequest{
		From:    "a@b.com",
		To:      []string{"c@d.com"},
		Subject: "Retry test",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !resp.Success {
		t.Error("expected Success to be true")
	}
	if counter.Load() != 3 {
		t.Errorf("expected 3 attempts, got %d", counter.Load())
	}
}
