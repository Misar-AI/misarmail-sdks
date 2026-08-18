"""HTTP transport shared by the generated resource layer.

Everything the SDK does goes through one of three transports — HTTP for the
REST surface, SSE for streaming, WebSocket for push — and all three
authenticate the same way: the account API key, sent as a bearer token. There
is no second credential path. What a key may do, and how much of it, is decided
server-side from the subscription behind that key; the SDK carries the key and
surfaces the answer rather than deciding locally what a plan allows.
"""

from __future__ import annotations

import time
from typing import Any, Iterable, Mapping

import httpx

from ..errors import MisarMailError, MisarMailNetworkError

RETRYABLE_STATUSES = frozenset({429, 500, 502, 503, 504})


def _clean_params(params: Mapping[str, Any] | None) -> dict[str, Any]:
    """Drop None values so optional filters stay out of the URL entirely."""
    if not params:
        return {}
    return {k: v for k, v in params.items() if v is not None}


def _backoff_seconds(attempt: int, response: httpx.Response | None = None) -> float:
    """Exponential backoff, but honour Retry-After when the server sends one.

    On a 429 the server knows when the window reopens; guessing wastes the
    caller's remaining budget.
    """
    if response is not None:
        header = response.headers.get("retry-after")
        if header:
            try:
                return min(float(header), 60.0)
            except ValueError:
                pass
    return 0.2 * (2**attempt)


class Transport:
    """Low-level request plumbing. Generated resources are written against this."""

    def __init__(
        self,
        api_key: str,
        base_url: str = "https://api.misar.io/mail",
        *,
        max_retries: int = 3,
        timeout: float = 30.0,
    ) -> None:
        if not api_key:
            raise ValueError(
                "A MisarMail API key is required. "
                "Create one at https://mail.misar.io/settings/api-keys."
            )
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.max_retries = max_retries
        self.timeout = timeout

    @property
    def headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

    # ── Sync ────────────────────────────────────────────────────────────────

    def request(
        self,
        method: str,
        path: str,
        json: Any | None = None,
        params: Mapping[str, Any] | None = None,
    ) -> Any:
        url = f"{self.base_url}{path}"
        attempt = 0

        while True:
            try:
                response = httpx.request(
                    method,
                    url,
                    headers=self.headers,
                    json=json,
                    params=_clean_params(params),
                    timeout=self.timeout,
                )
            except httpx.HTTPError as exc:
                if attempt < self.max_retries - 1:
                    time.sleep(_backoff_seconds(attempt))
                    attempt += 1
                    continue
                raise MisarMailNetworkError(str(exc)) from exc

            if response.status_code in RETRYABLE_STATUSES and attempt < self.max_retries - 1:
                time.sleep(_backoff_seconds(attempt, response))
                attempt += 1
                continue

            return _decode(response)

    # ── Async ───────────────────────────────────────────────────────────────

    async def arequest(
        self,
        method: str,
        path: str,
        json: Any | None = None,
        params: Mapping[str, Any] | None = None,
    ) -> Any:
        import asyncio

        url = f"{self.base_url}{path}"
        attempt = 0

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            while True:
                try:
                    response = await client.request(
                        method,
                        url,
                        headers=self.headers,
                        json=json,
                        params=_clean_params(params),
                    )
                except httpx.HTTPError as exc:
                    if attempt < self.max_retries - 1:
                        await asyncio.sleep(_backoff_seconds(attempt))
                        attempt += 1
                        continue
                    raise MisarMailNetworkError(str(exc)) from exc

                if response.status_code in RETRYABLE_STATUSES and attempt < self.max_retries - 1:
                    await asyncio.sleep(_backoff_seconds(attempt, response))
                    attempt += 1
                    continue

                return _decode(response)


def _decode(response: httpx.Response) -> Any:
    """Raise on error status, otherwise return the decoded body."""
    if response.status_code >= 400:
        try:
            data = response.json()
        except ValueError:
            data = {}
        raise MisarMailError(
            response.status_code,
            str(data.get("error") or data.get("message") or response.reason_phrase),
            str(data.get("error_type") or "api_error"),
            data,
        )
    if response.status_code == 204 or not response.content:
        return None
    return response.json()
