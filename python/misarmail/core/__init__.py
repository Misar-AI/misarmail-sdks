"""Hand-written runtime core: transport, streams, MCP, webhook verification.

The resource layer above it is generated from sdks/manifest.json; this half is
written by hand because idiom matters most here and generated code reads worst.
"""

from .mcp import McpClient
from .transport import Transport
from .webhooks import verify_webhook_signature
from .websocket import MisarMailSocket

__all__ = ["Transport", "McpClient", "MisarMailSocket", "verify_webhook_signature"]
