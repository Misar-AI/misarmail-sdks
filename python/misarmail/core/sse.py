"""Server-Sent Events client for the MisarMail streaming endpoints.

Both streams frame events as ``data: <json>`` and close with the sentinel
``data: [DONE]``. One of the two is a POST, so this is driven off httpx rather
than an EventSource-style helper, and it carries the same API key as every
other call.
"""

from __future__ import annotations

from typing import Any, AsyncIterator, Iterator

import httpx

from ..errors import MisarMailError, MisarMailNetworkError

DONE = "[DONE]"


def _headers(api_key: str, has_body: bool) -> dict[str, str]:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Accept": "text/event-stream",
    }
    if has_body:
        headers["Content-Type"] = "application/json"
    return headers


def _raise_for_status(response: httpx.Response) -> None:
    """Errors arrive as a normal JSON body, not as an SSE frame."""
    if response.status_code < 400:
        return
    response.read()
    try:
        data = response.json()
    except ValueError:
        data = {}
    raise MisarMailError(
        response.status_code,
        str(data.get("error") or response.reason_phrase),
        str(data.get("error_type") or "api_error"),
        data,
    )


def _parse(line: str) -> tuple[bool, Any]:
    """Return (should_stop, payload). Non-data lines yield (False, None)."""
    if not line.startswith("data:"):
        return False, None
    payload = line[5:].strip()
    if payload == DONE:
        return True, None
    if not payload:
        return False, None
    import json

    try:
        return False, json.loads(payload)
    except ValueError:
        # A malformed frame should not destroy everything already streamed.
        return False, {"raw": payload}


def stream(
    url: str,
    api_key: str,
    method: str = "GET",
    json_body: Any | None = None,
    timeout: float = 300.0,
) -> Iterator[Any]:
    """Yield one decoded payload per SSE event."""
    try:
        with httpx.stream(
            method,
            url,
            headers=_headers(api_key, json_body is not None),
            json=json_body,
            timeout=timeout,
        ) as response:
            _raise_for_status(response)
            for line in response.iter_lines():
                stop, payload = _parse(line)
                if stop:
                    return
                if payload is not None:
                    yield payload
    except httpx.HTTPError as exc:
        raise MisarMailNetworkError(str(exc)) from exc


async def astream(
    url: str,
    api_key: str,
    method: str = "GET",
    json_body: Any | None = None,
    timeout: float = 300.0,
) -> AsyncIterator[Any]:
    """Async variant of :func:`stream`."""
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            async with client.stream(
                method,
                url,
                headers=_headers(api_key, json_body is not None),
                json=json_body,
            ) as response:
                if response.status_code >= 400:
                    await response.aread()
                    try:
                        data = response.json()
                    except ValueError:
                        data = {}
                    raise MisarMailError(
                        response.status_code,
                        str(data.get("error") or response.reason_phrase),
                        str(data.get("error_type") or "api_error"),
                        data,
                    )
                async for line in response.aiter_lines():
                    stop, payload = _parse(line)
                    if stop:
                        return
                    if payload is not None:
                        yield payload
    except httpx.HTTPError as exc:
        raise MisarMailNetworkError(str(exc)) from exc
