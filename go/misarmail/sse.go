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

const sseDone = "[DONE]"

// StreamEvent is one decoded SSE frame. Raw is populated instead of Data when
// a frame is not valid JSON, so one malformed frame does not discard
// everything already streamed.
type StreamEvent struct {
	Data map[string]any
	Raw  string
}

// stream opens an SSE endpoint and pushes each decoded frame onto the returned
// channel, which is closed when the stream terminates. Errors arrive on the
// error channel; both channels are closed before the function's goroutine exits.
func (c *Client) stream(ctx context.Context, method, path string, body any) (<-chan StreamEvent, <-chan error) {
	events := make(chan StreamEvent)
	errs := make(chan error, 1)

	go func() {
		defer close(events)
		defer close(errs)

		var reader io.Reader
		if body != nil {
			payload, err := json.Marshal(body)
			if err != nil {
				errs <- fmt.Errorf("misarmail: encoding stream body: %w", err)
				return
			}
			reader = bytes.NewReader(payload)
		}

		req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, reader)
		if err != nil {
			errs <- err
			return
		}
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
		req.Header.Set("Accept", "text/event-stream")
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}

		// A stream has no useful deadline, so it must not inherit the client's
		// per-request timeout.
		streamClient := &http.Client{Transport: c.httpClient.Transport}
		resp, err := streamClient.Do(req)
		if err != nil {
			errs <- &Error{Status: 0, Message: err.Error(), ErrorType: "network_error"}
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode >= 400 {
			// Errors arrive as a normal JSON body, not as an SSE frame.
			if _, decodeErr := decode(resp); decodeErr != nil {
				errs <- decodeErr
			}
			return
		}

		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)

		for scanner.Scan() {
			line := scanner.Text()
			if !strings.HasPrefix(line, "data:") {
				continue
			}
			payload := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
			if payload == sseDone {
				return
			}
			if payload == "" {
				continue
			}

			var decoded map[string]any
			if err := json.Unmarshal([]byte(payload), &decoded); err != nil {
				select {
				case events <- StreamEvent{Raw: payload}:
				case <-ctx.Done():
					return
				}
				continue
			}
			select {
			case events <- StreamEvent{Data: decoded}:
			case <-ctx.Done():
				return
			}
		}
		if err := scanner.Err(); err != nil {
			errs <- err
		}
	}()

	return events, errs
}

// StreamGenerateEmail streams AI-generated email content.
// POST /api/ai/generate-email/stream
func (c *Client) StreamGenerateEmail(ctx context.Context, body map[string]any) (<-chan StreamEvent, <-chan error) {
	return c.stream(ctx, "POST", "/ai/generate-email/stream", body)
}

// StreamCampaignProgress streams a campaign's send progress until it reaches a
// terminal state. GET /api/campaigns/:id/send-stream
func (c *Client) StreamCampaignProgress(ctx context.Context, campaignID string) (<-chan StreamEvent, <-chan error) {
	return c.stream(ctx, "GET", "/campaigns/"+url.PathEscape(campaignID)+"/send-stream", nil)
}
