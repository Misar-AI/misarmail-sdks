"""MCP (Model Context Protocol) client for the MisarMail server at /api/mcp.

The MCP endpoint is part of the same API surface as everything else and takes
the same account API key, so it lives in this SDK rather than a separate
package — an agent author should not need a second dependency and a second
credential to reach the same account.

Streamable HTTP transport: each call is a JSON-RPC POST, and the server issues a
session id on the first response which is echoed on later calls so the session
is not re-initialized per request.
"""

from __future__ import annotations

from typing import Any

import httpx

from ..errors import MisarMailError, MisarMailNetworkError


class McpClient:
    def __init__(
        self,
        url: str,
        api_key: str,
        protocol_version: str = "2025-06-18",
        timeout: float = 60.0,
    ) -> None:
        self.url = url
        self.api_key = api_key
        self.protocol_version = protocol_version
        self.timeout = timeout
        self._session_id: str | None = None
        self._next_id = 1
        self._initialized = False

    def initialize(self) -> dict[str, Any]:
        """Initialize the session and return the server's capabilities."""
        result = self._rpc(
            "initialize",
            {
                "protocolVersion": self.protocol_version,
                "capabilities": {},
                "clientInfo": {"name": "misarmail-sdk", "version": "1.0.0"},
            },
        )
        self._initialized = True
        return result

    def list_tools(self) -> list[dict[str, Any]]:
        """List the tools this API key may call."""
        self._ensure_initialized()
        return self._rpc("tools/list", {}).get("tools", [])

    def call_tool(self, name: str, arguments: dict[str, Any] | None = None) -> dict[str, Any]:
        """Invoke a tool by name."""
        self._ensure_initialized()
        return self._rpc("tools/call", {"name": name, "arguments": arguments or {}})

    def _ensure_initialized(self) -> None:
        if not self._initialized:
            self.initialize()

    def _rpc(self, method: str, params: Any) -> dict[str, Any]:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            # The server may answer either way; accepting both lets it stream
            # when it wants to without the client rejecting the response.
            "Accept": "application/json, text/event-stream",
        }
        if self._session_id:
            headers["Mcp-Session-Id"] = self._session_id

        body = {"jsonrpc": "2.0", "id": self._next_id, "method": method, "params": params}
        self._next_id += 1

        try:
            response = httpx.post(self.url, headers=headers, json=body, timeout=self.timeout)
        except httpx.HTTPError as exc:
            raise MisarMailNetworkError(str(exc)) from exc

        session = response.headers.get("Mcp-Session-Id")
        if session:
            self._session_id = session

        if response.status_code >= 400:
            try:
                data = response.json()
            except ValueError:
                data = {}
            raise MisarMailError(
                response.status_code,
                str(data.get("error") or response.reason_phrase),
                "mcp_error",
                data,
            )

        payload = response.json()
        if "error" in payload:
            error = payload["error"]
            raise MisarMailError(400, str(error.get("message")), "mcp_error", error)
        return payload.get("result", {})
