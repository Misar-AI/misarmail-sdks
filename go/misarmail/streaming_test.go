package misarmail_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Misar-AI/misarmail-sdks/go/v5/misarmail"
)

// sseServer replays a fixed body, optionally flushing it in pieces so a frame
// straddles two reads.
func sseServer(t *testing.T, status int, chunks ...string) *misarmail.Client {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if status != 200 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(status)
			w.Write([]byte(chunks[0]))
			return
		}
		w.Header().Set("Content-Type", "text/event-stream")
		flusher, _ := w.(http.Flusher)
		for _, c := range chunks {
			w.Write([]byte(c))
			if flusher != nil {
				flusher.Flush()
			}
		}
	}))
	t.Cleanup(srv.Close)
	return misarmail.New("mmk_test", misarmail.WithAPIBase(srv.URL))
}

func collect(t *testing.T, c *misarmail.Client) ([]misarmail.StreamEvent, error) {
	t.Helper()
	var got []misarmail.StreamEvent
	err := c.Streaming.GenerateEmail(context.Background(), map[string]any{"prompt": "hi"},
		func(e misarmail.StreamEvent) error { got = append(got, e); return nil })
	return got, err
}

func TestStreamYieldsFramesAndStopsAtDone(t *testing.T) {
	c := sseServer(t, 200,
		"data: {\"delta\":\"Hel\",\"type\":\"body\"}\n\n",
		"data: {\"delta\":\"lo\",\"type\":\"body\"}\n\n",
		"data: {\"done\":true,\"type\":\"body\"}\n\n",
		"data: [DONE]\n\n",
		"data: {\"delta\":\"after-done\"}\n\n", // must never be delivered
	)
	got, err := collect(t, c)
	if err != nil {
		t.Fatalf("stream: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("got %d frames, want 3: %+v", len(got), got)
	}
	if got[0].Data["delta"] != "Hel" || got[1].Data["delta"] != "lo" {
		t.Errorf("unexpected deltas: %+v", got)
	}
	if got[2].Data["done"] != true {
		t.Errorf("third frame = %+v", got[2])
	}
}

func TestStreamReassemblesSplitFrames(t *testing.T) {
	c := sseServer(t, 200, "data: {\"del", "ta\":\"x\"}\n", "\ndata: [DONE]\n\n")
	got, err := collect(t, c)
	if err != nil {
		t.Fatalf("stream: %v", err)
	}
	if len(got) != 1 || got[0].Data["delta"] != "x" {
		t.Fatalf("got %+v", got)
	}
}

func TestStreamSkipsKeepalivesAndHandlesCRLF(t *testing.T) {
	c := sseServer(t, 200,
		": keepalive\n\n",
		"data: {\"delta\":\"a\"}\r\n\r\n",
		": keepalive\n\n",
		"data: [DONE]\r\n\r\n",
	)
	got, err := collect(t, c)
	if err != nil {
		t.Fatalf("stream: %v", err)
	}
	if len(got) != 1 || got[0].Data["delta"] != "a" {
		t.Fatalf("got %+v", got)
	}
}

func TestStreamSurfacesServerErrorFrame(t *testing.T) {
	c := sseServer(t, 200, "data: {\"error\":\"generation_failed\"}\n\n", "data: [DONE]\n\n")
	got, err := collect(t, c)
	if err != nil {
		t.Fatalf("stream: %v", err)
	}
	if len(got) != 1 || got[0].Data["error"] != "generation_failed" {
		t.Fatalf("got %+v", got)
	}
}

// Returning an error from the callback is how a caller breaks out early.
func TestStreamStopsWhenCallbackErrors(t *testing.T) {
	stop := errors.New("enough")
	c := sseServer(t, 200,
		"data: {\"delta\":\"a\"}\n\n",
		"data: {\"delta\":\"b\"}\n\n",
		"data: [DONE]\n\n",
	)
	var seen int
	err := c.Streaming.GenerateEmail(context.Background(), nil,
		func(e misarmail.StreamEvent) error { seen++; return stop })
	if !errors.Is(err, stop) {
		t.Fatalf("err = %v, want the callback's error", err)
	}
	if seen != 1 {
		t.Errorf("callback ran %d times, want 1", seen)
	}
}

func TestStreamUnauthorizedIsAnAPIError(t *testing.T) {
	c := sseServer(t, 401, `{"error":"Invalid or missing API key"}`)
	_, err := collect(t, c)
	var apiErr *misarmail.APIError
	if !errors.As(err, &apiErr) || apiErr.Status != 401 {
		t.Fatalf("err = %#v, want *APIError(401)", err)
	}
}

func TestStreamPlanRefusalIsTyped(t *testing.T) {
	c := sseServer(t, 429,
		`{"error":"spent","code":"plan_limit_exceeded","upgrade":{"feature":"ai"}}`)
	_, err := collect(t, c)
	var limit *misarmail.PlanLimitError
	if !errors.As(err, &limit) {
		t.Fatalf("err = %#v, want *PlanLimitError", err)
	}
	if limit.Feature != "ai" {
		t.Errorf("Feature = %q, want ai", limit.Feature)
	}
}
