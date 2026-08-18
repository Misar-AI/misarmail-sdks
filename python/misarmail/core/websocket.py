"""WebSocket client for the MisarMail push channels.

Channels (see server.mjs):
    /ws/inbox           — new messages and read receipts
    /ws/campaigns/:id   — campaign send progress

Auth is the same account API key used everywhere else, sent as an Authorization
header on the handshake.

``websockets`` is an optional dependency: most callers of this SDK never open a
socket, and making them install it would be a tax on the common case. Install
with ``pip install misarmail[websocket]``.
"""

from __future__ import annotations

import asyncio
import json
from typing import Any, AsyncIterator


class MisarMailSocket:
    """A single subscription to one channel, with automatic reconnection.

    Reconnection backs off exponentially and resets on a clean open, so a brief
    network blip does not burn the attempt budget a genuinely dead endpoint
    needs in order to stop retrying.
    """

    def __init__(
        self,
        url: str,
        api_key: str,
        *,
        heartbeat_seconds: float = 25.0,
        max_reconnect_attempts: int = 5,
    ) -> None:
        self.url = url
        self.api_key = api_key
        self.heartbeat_seconds = heartbeat_seconds
        self.max_reconnect_attempts = max_reconnect_attempts
        self._closed = False

    async def listen(self) -> AsyncIterator[dict[str, Any]]:
        """Yield each message until the channel is closed or retries run out."""
        try:
            import websockets
        except ImportError as exc:  # pragma: no cover - dependency guidance
            raise ImportError(
                "WebSocket support needs the `websockets` package. "
                "Install it with: pip install misarmail[websocket]"
            ) from exc

        attempts = 0
        while not self._closed:
            try:
                async with websockets.connect(
                    self.url,
                    additional_headers={"Authorization": f"Bearer {self.api_key}"},
                    ping_interval=self.heartbeat_seconds,
                ) as socket:
                    attempts = 0  # a clean open resets the budget
                    async for raw in socket:
                        try:
                            message = json.loads(raw)
                        except (TypeError, ValueError):
                            continue  # malformed frame — don't tear down the channel
                        if message.get("type") == "pong":
                            continue
                        yield message
            except asyncio.CancelledError:
                raise
            except Exception:
                if self._closed or attempts >= self.max_reconnect_attempts:
                    return
                await asyncio.sleep(min(2**attempts, 30))
                attempts += 1

    def close(self) -> None:
        """Stop listening and stop reconnecting."""
        self._closed = True
