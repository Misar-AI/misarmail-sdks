package misarmail

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

// StreamEvent is one decoded Server-Sent Events frame.
//
// MisarMail emits unnamed frames — `data: {...}` with no `event:` line — so
// Event is normally empty. Data holds the decoded JSON, or Raw when the payload
// was not JSON.
type StreamEvent struct {
	// Event is the SSE `event:` name when the server sends one.
	Event string
	// Data is the decoded JSON payload. Nil when the payload was not JSON.
	Data map[string]any
	// Raw is the payload exactly as received, always populated.
	Raw string
}

// StreamingResource covers the two Server-Sent Events endpoints.
//
// Both live outside /v1 — /api/ai/generate-email/stream and
// /api/campaigns/{id}/send-stream — so they use the API base rather than the
// versioned one. Both are API-key authenticated and metered like any other
// call, so a plan refusal surfaces as *PlanLimitError here too.
type StreamingResource struct{ c *Client }

// GenerateEmail calls POST /api/ai/generate-email/stream and invokes onEvent
// for each frame until the stream ends.
//
// Returning an error from onEvent stops the stream and is returned to the
// caller — the way to break out early.
//
//	err := c.Streaming.GenerateEmail(ctx, map[string]any{"prompt": "…"},
//	    func(e misarmail.StreamEvent) error {
//	        fmt.Print(e.Data["delta"])
//	        return nil
//	    })
func (r *StreamingResource) GenerateEmail(ctx context.Context, body map[string]any, onEvent func(StreamEvent) error) error {
	return r.c.stream(ctx, http.MethodPost, "/ai/generate-email/stream", body, onEvent)
}

// CampaignSend calls GET /api/campaigns/{id}/send-stream, reporting progress
// while a campaign sends.
func (r *StreamingResource) CampaignSend(ctx context.Context, campaignID string, onEvent func(StreamEvent) error) error {
	path := "/campaigns/" + url.PathEscape(campaignID) + "/send-stream"
	return r.c.stream(ctx, http.MethodGet, path, nil, onEvent)
}

// stream opens an SSE connection and dispatches each frame to onEvent.
//
// Deliberately not retried: replaying a stream that failed mid-flight would
// duplicate whatever the caller already consumed.
func (c *Client) stream(ctx context.Context, method, path string, body map[string]any, onEvent func(StreamEvent) error) error {
	var bodyReader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		bodyReader = bytes.NewReader(b)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.apiBase+path, bodyReader)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Accept", "text/event-stream")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return &NetworkError{Message: err.Error(), Cause: err}
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		raw, _ := io.ReadAll(resp.Body)
		if isPlanLimit(raw) {
			return planLimitFrom(resp, raw)
		}
		var envelope struct {
			Error string `json:"error"`
		}
		json.Unmarshal(raw, &envelope) //nolint:errcheck
		msg := envelope.Error
		if msg == "" {
			msg = strings.TrimSpace(string(raw))
		}
		if msg == "" {
			msg = resp.Status
		}
		return &APIError{Status: resp.StatusCode, Message: msg}
	}

	// A frame ends at a blank line, so scan line by line and flush on one.
	// bufio.Scanner's default 64KB token limit is ample for a frame; the buffer
	// is raised anyway because a single delta could in principle be large.
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

	var eventName string
	var dataLines []string

	flush := func() (bool, error) {
		if len(dataLines) == 0 {
			eventName = ""
			return false, nil
		}
		raw := strings.Join(dataLines, "\n")
		eventName, dataLines = "", nil

		if raw == "[DONE]" {
			return true, nil // sentinel: stop, do not dispatch
		}
		ev := StreamEvent{Event: eventName, Raw: raw}
		var decoded map[string]any
		if json.Unmarshal([]byte(raw), &decoded) == nil {
			ev.Data = decoded
		}
		return false, onEvent(ev)
	}

	for scanner.Scan() {
		line := strings.TrimRight(scanner.Text(), "\r")

		if line == "" {
			done, err := flush()
			if err != nil {
				return err
			}
			if done {
				return nil
			}
			continue
		}
		// Comments are keepalives.
		if strings.HasPrefix(line, ":") {
			continue
		}
		if rest, ok := strings.CutPrefix(line, "event:"); ok {
			eventName = strings.TrimSpace(rest)
			continue
		}
		if rest, ok := strings.CutPrefix(line, "data:"); ok {
			dataLines = append(dataLines, strings.TrimPrefix(rest, " "))
		}
	}

	if err := scanner.Err(); err != nil {
		return &NetworkError{Message: fmt.Sprintf("stream read: %v", err), Cause: err}
	}

	// A final frame with no trailing blank line.
	if _, err := flush(); err != nil {
		return err
	}
	return nil
}
