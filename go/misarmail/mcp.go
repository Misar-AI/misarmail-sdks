package misarmail

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
)

// MCPClient speaks the Model Context Protocol to the MisarMail server at
// /api/mcp.
//
// The MCP endpoint is part of the same API surface as everything else and takes
// the same account API key, so it lives in this SDK rather than a separate
// module — an agent author should not need a second dependency and a second
// credential to reach the same account.
type MCPClient struct {
	url         string
	apiKey      string
	httpClient  *http.Client
	sessionID   string
	nextID      int
	initialized bool
}

// MCP returns an MCP client bound to this account's key.
func (c *Client) MCP() *MCPClient {
	return &MCPClient{
		url:        c.baseURL + "/mcp",
		apiKey:     c.apiKey,
		httpClient: c.httpClient,
		nextID:     1,
	}
}

// MCPTool describes one tool the server exposes.
type MCPTool struct {
	Name        string         `json:"name"`
	Description string         `json:"description,omitempty"`
	InputSchema map[string]any `json:"inputSchema,omitempty"`
}

// Initialize starts the session and returns the server's capabilities.
func (m *MCPClient) Initialize(ctx context.Context) (map[string]any, error) {
	result, err := m.rpc(ctx, "initialize", map[string]any{
		"protocolVersion": mcpProtocolVersion,
		"capabilities":    map[string]any{},
		"clientInfo":      map[string]any{"name": "misarmail-sdk", "version": "1.0.0"},
	})
	if err != nil {
		return nil, err
	}
	m.initialized = true
	return result, nil
}

// ListTools returns the tools this API key may call.
func (m *MCPClient) ListTools(ctx context.Context) ([]MCPTool, error) {
	if err := m.ensureInitialized(ctx); err != nil {
		return nil, err
	}
	result, err := m.rpc(ctx, "tools/list", map[string]any{})
	if err != nil {
		return nil, err
	}
	// Round-trip through JSON rather than hand-asserting each field.
	raw, err := json.Marshal(result["tools"])
	if err != nil {
		return nil, err
	}
	var tools []MCPTool
	if err := json.Unmarshal(raw, &tools); err != nil {
		return nil, err
	}
	return tools, nil
}

// CallTool invokes a tool by name.
func (m *MCPClient) CallTool(ctx context.Context, name string, args map[string]any) (map[string]any, error) {
	if err := m.ensureInitialized(ctx); err != nil {
		return nil, err
	}
	if args == nil {
		args = map[string]any{}
	}
	return m.rpc(ctx, "tools/call", map[string]any{"name": name, "arguments": args})
}

func (m *MCPClient) ensureInitialized(ctx context.Context) error {
	if m.initialized {
		return nil
	}
	_, err := m.Initialize(ctx)
	return err
}

func (m *MCPClient) rpc(ctx context.Context, method string, params any) (map[string]any, error) {
	payload, err := json.Marshal(map[string]any{
		"jsonrpc": "2.0",
		"id":      m.nextID,
		"method":  method,
		"params":  params,
	})
	if err != nil {
		return nil, err
	}
	m.nextID++

	req, err := http.NewRequestWithContext(ctx, "POST", m.url, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+m.apiKey)
	req.Header.Set("Content-Type", "application/json")
	// The server may answer either way; accepting both lets it stream when it
	// wants to without the client rejecting the response.
	req.Header.Set("Accept", "application/json, text/event-stream")
	// The server issues a session id on the first response; echoing it keeps
	// later calls on the same session rather than re-initializing per call.
	if m.sessionID != "" {
		req.Header.Set("Mcp-Session-Id", m.sessionID)
	}

	resp, err := m.httpClient.Do(req)
	if err != nil {
		return nil, &Error{Status: 0, Message: err.Error(), ErrorType: "network_error"}
	}

	if session := resp.Header.Get("Mcp-Session-Id"); session != "" {
		m.sessionID = session
	}

	body, err := decode(resp)
	if err != nil {
		return nil, err
	}

	if rpcErr, ok := body["error"].(map[string]any); ok {
		message, _ := rpcErr["message"].(string)
		return nil, &Error{Status: 400, Message: message, ErrorType: "mcp_error", Details: rpcErr}
	}

	result, ok := body["result"].(map[string]any)
	if !ok {
		return map[string]any{}, nil
	}
	return result, nil
}
