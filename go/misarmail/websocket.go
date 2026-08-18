package misarmail

import (
	"net/http"
	"net/url"
)

// WebSocketChannel describes an authenticated push channel: the URL to dial and
// the headers to dial it with.
//
// This SDK deliberately does not vendor a WebSocket implementation. Go has no
// WebSocket client in the standard library, and picking one for callers would
// force gorilla/websocket or nhooyr/websocket into every dependency tree that
// only wanted to send email. Returning dial parameters instead lets callers use
// whichever library they already have:
//
//	ch := client.InboxChannel()
//	conn, _, err := websocket.DefaultDialer.Dial(ch.URL, ch.Header)
//
// Channels (see server.mjs):
//
//	/ws/inbox          — new messages and read receipts
//	/ws/campaigns/:id  — campaign send progress
type WebSocketChannel struct {
	URL    string
	Header http.Header
}

func (c *Client) channel(path string) WebSocketChannel {
	header := http.Header{}
	// The server accepts the key as a header or as ?token=. Go dialers can set
	// headers, so use the header form and keep the key out of the URL.
	header.Set("Authorization", "Bearer "+c.apiKey)
	return WebSocketChannel{URL: c.websocketURL + path, Header: header}
}

// InboxChannel returns dial parameters for real-time inbox updates.
func (c *Client) InboxChannel() WebSocketChannel {
	return c.channel("/ws/inbox")
}

// CampaignChannel returns dial parameters for a campaign's send progress.
func (c *Client) CampaignChannel(campaignID string) WebSocketChannel {
	return c.channel("/ws/campaigns/" + url.PathEscape(campaignID))
}
