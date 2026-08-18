from __future__ import annotations

import asyncio
import time
from typing import Any, Optional
from urllib.parse import quote

import httpx

from .errors import MisarMailError, MisarMailNetworkError, MisarMailPlanLimitError

__all__ = ["MisarMailClient"]

DEFAULT_BASE_URL = "https://api.misar.io/mail/v1"
RETRY_BASE_S = 0.2
RETRYABLE = {429, 500, 502, 503, 504}


def _decode(resp) -> dict:
    try:
        return resp.json() if resp.content else {}
    except ValueError:
        return {}


def _is_plan_limit(data: dict) -> bool:
    """A plan refusal, not a rate limit — retrying it cannot help."""
    return (
        data.get("code") == "plan_limit_exceeded"
        or data.get("error_type") == "plan_limit_exceeded"
        or isinstance(data.get("upgrade"), dict)
    )


def _clean(d: dict | None) -> dict | None:
    if d is None:
        return None
    return {k: v for k, v in d.items() if v is not None}


# ── SSE parsing ────────────────────────────────────────────────────────────────

_DONE = object()
"""Sentinel for the ``data: [DONE]`` frame that ends a MisarMail stream."""


def _frame_end(buffer: str) -> int:
    """Index of the blank line ending the first complete frame, or -1."""
    lf = buffer.find("\n\n")
    crlf = buffer.find("\r\n\r\n")
    if lf == -1:
        return crlf
    if crlf == -1:
        return lf
    return min(lf, crlf)


def _parse_sse_frame(frame: str):
    """Decode one SSE frame.

    Returns the payload, ``_DONE`` for the terminating sentinel, or ``None`` for
    a keepalive comment or an empty frame.
    """
    import json as _json

    event = None
    data_lines = []
    for line in frame.replace("\r\n", "\n").split("\n"):
        if not line or line.startswith(":"):
            continue
        if line.startswith("event:"):
            event = line[6:].strip()
        elif line.startswith("data:"):
            data_lines.append(line[5:].lstrip())
    if not data_lines:
        return None
    raw = "\n".join(data_lines)
    if raw == "[DONE]":
        return _DONE
    try:
        decoded = _json.loads(raw)
    except ValueError:
        decoded = raw
    return {"data": decoded, "event": event} if event else decoded


class _MisarMailCore:
    _api_key: str
    _base_url: str
    _api_base: str
    _max_retries: int
    _timeout: float

    def _request(
        self,
        method: str,
        path: str,
        body: dict | None = None,
        *,
        params: dict | None = None,
        use_api_base: bool = False,
    ) -> dict:
        base = self._api_base if use_api_base else self._base_url
        url = base + path
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }
        last_exc: Exception | None = None
        for attempt in range(self._max_retries):
            try:
                resp = httpx.request(
                    method,
                    url,
                    headers=headers,
                    params=_clean(params),
                    json=body,
                    timeout=self._timeout,
                )
                status = resp.status_code
                data = {} if resp.is_success else _decode(resp)
                # The body must be read before deciding to retry: a rate-limit
                # 429 and a spent-allowance 429 are identical by status.
                if _is_plan_limit(data):
                    raise MisarMailPlanLimitError(
                        status,
                        data.get("error") or "plan limit exceeded",
                        data,
                        dict(resp.headers),
                    )
                if status in RETRYABLE and attempt < self._max_retries - 1:
                    time.sleep(RETRY_BASE_S * (2**attempt))
                    continue
                if not resp.is_success:
                    raise MisarMailError(
                        status,
                        data.get("error") or resp.reason_phrase or "unknown error",
                    )
                return resp.json() if resp.content else {}
            except MisarMailError:
                raise
            except Exception as exc:
                last_exc = exc
                if attempt < self._max_retries - 1:
                    time.sleep(RETRY_BASE_S * (2**attempt))
                    continue
                raise MisarMailNetworkError(str(exc), exc) from exc
        raise MisarMailNetworkError("max retries exceeded", last_exc)

    async def _arequest(
        self,
        method: str,
        path: str,
        body: dict | None = None,
        *,
        params: dict | None = None,
        use_api_base: bool = False,
    ) -> dict:
        base = self._api_base if use_api_base else self._base_url
        url = base + path
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }
        last_exc: Exception | None = None
        async with httpx.AsyncClient(timeout=self._timeout) as http:
            for attempt in range(self._max_retries):
                try:
                    resp = await http.request(
                        method,
                        url,
                        headers=headers,
                        params=_clean(params),
                        json=body,
                    )
                    status = resp.status_code
                    data = {} if resp.is_success else _decode(resp)
                    # The body must be read before deciding to retry: a rate-limit
                    # 429 and a spent-allowance 429 are identical by status.
                    if _is_plan_limit(data):
                        raise MisarMailPlanLimitError(
                            status,
                            data.get("error") or "plan limit exceeded",
                            data,
                            dict(resp.headers),
                        )
                    if status in RETRYABLE and attempt < self._max_retries - 1:
                        await asyncio.sleep(RETRY_BASE_S * (2**attempt))
                        continue
                    if not resp.is_success:
                        raise MisarMailError(
                            status,
                            data.get("error") or resp.reason_phrase or "unknown error",
                        )
                    return resp.json() if resp.content else {}
                except MisarMailError:
                    raise
                except Exception as exc:
                    last_exc = exc
                    if attempt < self._max_retries - 1:
                        await asyncio.sleep(RETRY_BASE_S * (2**attempt))
                        continue
                    raise MisarMailNetworkError(str(exc), exc) from exc
        raise MisarMailNetworkError("max retries exceeded", last_exc)



    def _sse_frames(self, method: str, path: str, body: Optional[dict] = None):
        """Yield decoded SSE frames from a streaming endpoint.

        Both MisarMail streams live outside ``/v1``, so this uses the API base.
        Frames end at a blank line, may span several ``data:`` lines, and the
        stream terminates at the ``[DONE]`` sentinel, which is consumed here
        rather than yielded.

        Deliberately not retried: replaying a stream that failed mid-flight
        would duplicate whatever the caller already consumed.
        """
        import json as _json

        url = self._api_base + path
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Accept": "text/event-stream",
            "Content-Type": "application/json",
        }
        try:
            with httpx.stream(
                method, url, headers=headers, json=body, timeout=self._timeout
            ) as resp:
                if not resp.is_success:
                    raw = resp.read().decode("utf-8", "replace")
                    try:
                        data = _json.loads(raw) if raw else {}
                    except ValueError:
                        data = {}
                    if not isinstance(data, dict):
                        data = {}
                    if _is_plan_limit(data):
                        raise MisarMailPlanLimitError(
                            resp.status_code,
                            data.get("error") or "plan limit exceeded",
                            data,
                            dict(resp.headers),
                        )
                    raise MisarMailError(
                        resp.status_code,
                        data.get("error") or raw or "stream error",
                    )

                buffer = ""
                for chunk in resp.iter_text():
                    buffer += chunk
                    while True:
                        end = _frame_end(buffer)
                        if end == -1:
                            break
                        frame = buffer[:end]
                        buffer = buffer[end:].lstrip("\r\n")
                        parsed = _parse_sse_frame(frame)
                        if parsed is _DONE:
                            return
                        if parsed is not None:
                            yield parsed
                tail = _parse_sse_frame(buffer)
                if tail is not None and tail is not _DONE:
                    yield tail
        except MisarMailError:
            raise
        except Exception as exc:
            raise MisarMailNetworkError(str(exc), exc) from exc

class _Resource:
    def __init__(self, client: _MisarMailCore) -> None:
        self._c = client


# ── Email ──────────────────────────────────────────────────────────────────────

class _EmailResource(_Resource):
    def send(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/send", data)

    async def asend(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/send", data)


# ── Contacts ───────────────────────────────────────────────────────────────────

class _ContactsResource(_Resource):
    def list(self, page: int | None = None, limit: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/contacts", params={"page": page, "limit": limit})

    async def alist(self, page: int | None = None, limit: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/contacts", params={"page": page, "limit": limit})

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/contacts", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/contacts", data)

    def get(self, id: str) -> dict[str, Any]:
        """``GET /contacts?id=<uuid>``.

        The id is a query parameter, not a path segment: /v1/contacts has no
        dynamic route, so /contacts/<id> is a 404.
        """
        return self._c._request("GET", f"/contacts?id={quote(id, safe='')}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/contacts?id={quote(id, safe='')}")

    def update(self, email: str, data: dict[str, Any]) -> dict[str, Any]:
        """``PATCH /contacts`` — the contact is identified by ``email`` in the body.

        Not by id, and not by a path segment. Passing an id here silently failed
        validation, since the schema requires a valid email address.
        """
        return self._c._request("PATCH", "/contacts", {**data, "email": email})

    async def aupdate(self, email: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", "/contacts", {**data, "email": email})

    def delete(self, id: str) -> dict[str, Any]:
        """``DELETE /contacts?id=<uuid>`` — query parameter, not a path segment."""
        return self._c._request("DELETE", f"/contacts?id={quote(id, safe='')}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/contacts?id={quote(id, safe='')}")

    def import_contacts(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/contacts/import", data)

    async def aimport_contacts(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/contacts/import", data)


# ── Campaigns ──────────────────────────────────────────────────────────────────

class _CampaignsResource(_Resource):
    def list(self, page: int | None = None, limit: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/campaigns", params={"page": page, "limit": limit})

    async def alist(self, page: int | None = None, limit: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/campaigns", params={"page": page, "limit": limit})

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/campaigns", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/campaigns", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/campaigns/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/campaigns/{id}")

    def update(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/campaigns/{id}", data)

    async def aupdate(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/campaigns/{id}", data)

    def send(self, id: str) -> dict[str, Any]:
        return self._c._request("POST", f"/campaigns/{id}/send", {})

    async def asend(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("POST", f"/campaigns/{id}/send", {})

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/campaigns/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/campaigns/{id}")


# ── Templates ──────────────────────────────────────────────────────────────────

class _TemplatesResource(_Resource):
    def list(self) -> dict[str, Any]:
        return self._c._request("GET", "/templates")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/templates")

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/templates", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/templates", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/templates/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/templates/{id}")

    def update(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/templates/{id}", data)

    async def aupdate(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/templates/{id}", data)

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/templates/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/templates/{id}")

    def render(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/templates/render", data)

    async def arender(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/templates/render", data)


# ── Automations ────────────────────────────────────────────────────────────────

class _AutomationsResource(_Resource):
    def list(self, page: int | None = None, limit: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/automations", params={"page": page, "limit": limit})

    async def alist(self, page: int | None = None, limit: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/automations", params={"page": page, "limit": limit})

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/automations", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/automations", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/automations/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/automations/{id}")

    def update(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/automations/{id}", data)

    async def aupdate(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/automations/{id}", data)

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/automations/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/automations/{id}")

    def activate(self, id: str, active: bool) -> dict[str, Any]:
        return self._c._request("PATCH", f"/automations/{id}/activate", {"active": active})

    async def aactivate(self, id: str, active: bool) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/automations/{id}/activate", {"active": active})


# ── Domains ────────────────────────────────────────────────────────────────────

class _DomainsResource(_Resource):
    def list(self) -> dict[str, Any]:
        return self._c._request("GET", "/domains", use_api_base=True)

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/domains", use_api_base=True)

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/domains", data, use_api_base=True)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/domains", data, use_api_base=True)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/domains/{id}", use_api_base=True)

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/domains/{id}", use_api_base=True)

    def verify(self, id: str) -> dict[str, Any]:
        return self._c._request("POST", f"/domains/{id}/verify", {}, use_api_base=True)

    async def averify(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("POST", f"/domains/{id}/verify", {}, use_api_base=True)

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/domains/{id}", use_api_base=True)

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/domains/{id}", use_api_base=True)


# ── Aliases ────────────────────────────────────────────────────────────────────


class _DedicatedIPsResource(_Resource):
    def list(self) -> dict[str, Any]:
        return self._c._request("GET", "/dedicated-ips")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/dedicated-ips")

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/dedicated-ips", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/dedicated-ips", data)

    def update(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/dedicated-ips/{id}", data)

    async def aupdate(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/dedicated-ips/{id}", data)

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/dedicated-ips/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/dedicated-ips/{id}")


# ── A/B Tests ──────────────────────────────────────────────────────────────────

class _ABTestsResource(_Resource):
    def list(self) -> dict[str, Any]:
        return self._c._request("GET", "/ab-tests")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/ab-tests")

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/ab-tests", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/ab-tests", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/ab-tests/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/ab-tests/{id}")

    def set_winner(self, id: str, variant_id: str) -> dict[str, Any]:
        return self._c._request("POST", f"/ab-tests/{id}/winner", {"variant_id": variant_id})

    async def aset_winner(self, id: str, variant_id: str) -> dict[str, Any]:
        return await self._c._arequest("POST", f"/ab-tests/{id}/winner", {"variant_id": variant_id})


# ── Sandbox ────────────────────────────────────────────────────────────────────

class _SandboxResource(_Resource):
    def send(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/sandbox/send", data)

    async def asend(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/sandbox/send", data)

    def list(self, page: int | None = None, limit: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/sandbox", params={"page": page, "limit": limit})

    async def alist(self, page: int | None = None, limit: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/sandbox", params={"page": page, "limit": limit})

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/sandbox/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/sandbox/{id}")


# ── Inbound ────────────────────────────────────────────────────────────────────

class _InboundResource(_Resource):
    def list(self, page: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/inbound", params={"page": page})

    async def alist(self, page: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/inbound", params={"page": page})

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/inbound", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/inbound", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/inbound/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/inbound/{id}")

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/inbound/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/inbound/{id}")


# ── Analytics ──────────────────────────────────────────────────────────────────

class _AnalyticsResource(_Resource):
    def overview(
        self,
        start_date: str | None = None,
        end_date: str | None = None,
        campaign_id: str | None = None,
        group_by: str | None = None,
    ) -> dict[str, Any]:
        return self._c._request(
            "GET",
            "/analytics",
            params={"start_date": start_date, "end_date": end_date, "campaign_id": campaign_id, "group_by": group_by},
        )

    async def aoverview(
        self,
        start_date: str | None = None,
        end_date: str | None = None,
        campaign_id: str | None = None,
        group_by: str | None = None,
    ) -> dict[str, Any]:
        return await self._c._arequest(
            "GET",
            "/analytics",
            params={"start_date": start_date, "end_date": end_date, "campaign_id": campaign_id, "group_by": group_by},
        )


# ── Track ──────────────────────────────────────────────────────────────────────

class _TrackResource(_Resource):
    def event(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/track/event", data)

    async def aevent(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/track/event", data)

    def purchase(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/track/purchase", data)

    async def apurchase(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/track/purchase", data)


# ── API Keys ───────────────────────────────────────────────────────────────────

class _KeysResource(_Resource):
    def list(self) -> dict[str, Any]:
        return self._c._request("GET", "/keys")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/keys")

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/keys", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/keys", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/keys/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/keys/{id}")

    def revoke(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/keys/{id}")

    async def arevoke(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/keys/{id}")


# ── Validate ───────────────────────────────────────────────────────────────────

class _ValidateResource(_Resource):
    def email(self, address: str) -> dict[str, Any]:
        return self._c._request("GET", "/validate", params={"address": address})

    async def aemail(self, address: str) -> dict[str, Any]:
        return await self._c._arequest("GET", "/validate", params={"address": address})


# ── Webhooks ───────────────────────────────────────────────────────────────────

class _WebhooksResource(_Resource):
    def list(self) -> dict[str, Any]:
        return self._c._request("GET", "/webhooks")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/webhooks")

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/webhooks", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/webhooks", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/webhooks/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/webhooks/{id}")

    def update(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/webhooks/{id}", data)

    async def aupdate(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/webhooks/{id}", data)

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/webhooks/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/webhooks/{id}")

    def test(self, id: str) -> dict[str, Any]:
        return self._c._request("POST", f"/webhooks/{id}/test", {})

    async def atest(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("POST", f"/webhooks/{id}/test", {})


# ── Usage ──────────────────────────────────────────────────────────────────────

class _UsageResource(_Resource):
    def get(self, start_date: str | None = None, end_date: str | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/usage", params={"start_date": start_date, "end_date": end_date})

    async def aget(self, start_date: str | None = None, end_date: str | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/usage", params={"start_date": start_date, "end_date": end_date})


# ── Billing ────────────────────────────────────────────────────────────────────

class _BillingResource(_Resource):
    def subscription(self) -> dict[str, Any]:
        return self._c._request("GET", "/billing/subscription", use_api_base=True)

    async def asubscription(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/billing/subscription", use_api_base=True)

    def checkout(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/billing/checkout", data, use_api_base=True)

    async def acheckout(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/billing/checkout", data, use_api_base=True)


# ── Workspaces ─────────────────────────────────────────────────────────────────


class _PlanResource(_Resource):
    """Live subscription standing for the key's owner.

    Read this before an expensive call rather than discovering the ceiling
    through a MisarMailPlanLimitError. ``usage`` reports every metered feature
    and ``upgrade`` is non-null as soon as one of them is spent.
    """

    def get(self) -> dict[str, Any]:
        """GET /plan — plan, sending allowances, per-feature usage, upgrade offer."""
        return self._c._request("GET", "/plan")

    async def aget(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/plan")

    def limits(self, product: Optional[str] = None) -> dict[str, Any]:
        """GET /plan-limits"""
        return self._c._request("GET", "/plan-limits", params={"product": product})

    async def alimits(self, product: Optional[str] = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/plan-limits", params={"product": product})

    def monetization(self) -> dict[str, Any]:
        """GET /monetization/stats — revenue and monetization counters."""
        return self._c._request("GET", "/monetization/stats")

    async def amonetization(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/monetization/stats")


# ── Generated from scripts/sdk-endpoint-spec.json ─────────────────────────────

class _AiResource(_Resource):
    """ai — generated from scripts/sdk-endpoint-spec.json."""

    def subject_lines(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """POST /ai/subject-lines"""
        return self._c._request("POST", "/ai/subject-lines", data or {})

    async def asubject_lines(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", "/ai/subject-lines", data or {})


class _CreditRatesResource(_Resource):
    """creditRates — generated from scripts/sdk-endpoint-spec.json."""

    def list(self) -> dict[str, Any]:
        """GET /credit-rates"""
        return self._c._request("GET", "/credit-rates")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/credit-rates")


class _DeliverabilityResource(_Resource):
    """deliverability — generated from scripts/sdk-endpoint-spec.json."""

    def audit(self) -> dict[str, Any]:
        """GET /deliverability/audit"""
        return self._c._request("GET", "/deliverability/audit")

    async def aaudit(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/deliverability/audit")

    def score(self) -> dict[str, Any]:
        """GET /deliverability/score"""
        return self._c._request("GET", "/deliverability/score")

    async def ascore(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/deliverability/score")


class _DmarcResource(_Resource):
    """dmarc — generated from scripts/sdk-endpoint-spec.json."""

    def check(self, domain: Optional[str] = None, dkim_selector: Optional[str] = None) -> dict[str, Any]:
        """GET /dmarc/check"""
        return self._c._request("GET", "/dmarc/check", params={"domain": domain, "dkim_selector": dkim_selector})

    async def acheck(self, domain: Optional[str] = None, dkim_selector: Optional[str] = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/dmarc/check", params={"domain": domain, "dkim_selector": dkim_selector})

    def list_domains(self) -> dict[str, Any]:
        """GET /dmarc/domains"""
        return self._c._request("GET", "/dmarc/domains")

    async def alist_domains(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/dmarc/domains")

    def add_domain(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """POST /dmarc/domains"""
        return self._c._request("POST", "/dmarc/domains", data or {})

    async def aadd_domain(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", "/dmarc/domains", data or {})

    def remove_domain(self, domain_id: Optional[str] = None) -> dict[str, Any]:
        """DELETE /dmarc/domains"""
        return self._c._request("DELETE", "/dmarc/domains", params={"domain_id": domain_id})

    async def aremove_domain(self, domain_id: Optional[str] = None) -> dict[str, Any]:
        return await self._c._arequest("DELETE", "/dmarc/domains", params={"domain_id": domain_id})


class _EmailAccountsResource(_Resource):
    """emailAccounts — generated from scripts/sdk-endpoint-spec.json."""

    def list(self) -> dict[str, Any]:
        """GET /email-accounts"""
        return self._c._request("GET", "/email-accounts")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/email-accounts")


class _EmailsResource(_Resource):
    """emails — generated from scripts/sdk-endpoint-spec.json."""

    def list(self, folder: Optional[str] = None, search: Optional[str] = None, limit: Optional[int] = None) -> dict[str, Any]:
        """GET /emails"""
        return self._c._request("GET", "/emails", params={"folder": folder, "search": search, "limit": limit})

    async def alist(self, folder: Optional[str] = None, search: Optional[str] = None, limit: Optional[int] = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/emails", params={"folder": folder, "search": search, "limit": limit})

    def get(self, id: str) -> dict[str, Any]:
        """GET /emails/:id"""
        return self._c._request("GET", f"/emails/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/emails/{id}")

    def update(self, id: str, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """PATCH /emails/:id"""
        return self._c._request("PATCH", f"/emails/{id}", data or {})

    async def aupdate(self, id: str, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/emails/{id}", data or {})


class _LandingPagesResource(_Resource):
    """landingPages — generated from scripts/sdk-endpoint-spec.json."""

    def create(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """POST /landing-pages"""
        return self._c._request("POST", "/landing-pages", data or {})

    async def acreate(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", "/landing-pages", data or {})


class _MonetizationResource(_Resource):
    """monetization — generated from scripts/sdk-endpoint-spec.json."""

    def tip(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """POST /monetization/tip"""
        return self._c._request("POST", "/monetization/tip", data or {})

    async def atip(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", "/monetization/tip", data or {})


class _RevenueResource(_Resource):
    """revenue — generated from scripts/sdk-endpoint-spec.json."""

    def attribution(self, campaign_id: Optional[str] = None, period: Optional[str] = None) -> dict[str, Any]:
        """GET /revenue/attribution"""
        return self._c._request("GET", "/revenue/attribution", params={"campaign_id": campaign_id, "period": period})

    async def aattribution(self, campaign_id: Optional[str] = None, period: Optional[str] = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/revenue/attribution", params={"campaign_id": campaign_id, "period": period})


class _SegmentsResource(_Resource):
    """segments — generated from scripts/sdk-endpoint-spec.json."""

    def members(self, id: str, page: Optional[int] = None, limit: Optional[int] = None) -> dict[str, Any]:
        """GET /segments/:id/members"""
        return self._c._request("GET", f"/segments/{id}/members", params={"page": page, "limit": limit})

    async def amembers(self, id: str, page: Optional[int] = None, limit: Optional[int] = None) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/segments/{id}/members", params={"page": page, "limit": limit})


class _SubscriptionResource(_Resource):
    """subscription — generated from scripts/sdk-endpoint-spec.json."""

    def get(self, product: Optional[str] = None) -> dict[str, Any]:
        """GET /subscription"""
        return self._c._request("GET", "/subscription", params={"product": product})

    async def aget(self, product: Optional[str] = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/subscription", params={"product": product})

    def upsert(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """POST /subscription"""
        return self._c._request("POST", "/subscription", data or {})

    async def aupsert(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", "/subscription", data or {})

    def cancel(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """DELETE /subscription"""
        return self._c._request("DELETE", "/subscription", data or {})

    async def acancel(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("DELETE", "/subscription", data or {})


class _TeamMembersResource(_Resource):
    """teamMembers — generated from scripts/sdk-endpoint-spec.json."""

    def get(self, owner_id: Optional[str] = None) -> dict[str, Any]:
        """GET /team-members"""
        return self._c._request("GET", "/team-members", params={"owner_id": owner_id})

    async def aget(self, owner_id: Optional[str] = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/team-members", params={"owner_id": owner_id})


class _WalletResource(_Resource):
    """wallet — generated from scripts/sdk-endpoint-spec.json."""

    def get(self) -> dict[str, Any]:
        """GET /wallet"""
        return self._c._request("GET", "/wallet")

    async def aget(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/wallet")

    def credit(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """POST /wallet/credit"""
        return self._c._request("POST", "/wallet/credit", data or {})

    async def acredit(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", "/wallet/credit", data or {})

    def debit(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """POST /wallet/debit"""
        return self._c._request("POST", "/wallet/debit", data or {})

    async def adebit(self, data: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        return await self._c._arequest("POST", "/wallet/debit", data or {})


class _WarmupResource(_Resource):
    """warmup — generated from scripts/sdk-endpoint-spec.json."""

    def get(self) -> dict[str, Any]:
        """GET /warmup"""
        return self._c._request("GET", "/warmup")

    async def aget(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/warmup")


class _StreamingResource(_Resource):
    """The two Server-Sent Events endpoints.

    Both live outside ``/v1`` and are API-key authenticated like everything
    else, so a plan refusal surfaces as :class:`MisarMailPlanLimitError` here
    too.
    """

    def generate_email(self, **options: Any):
        """``POST /api/ai/generate-email/stream`` — token-by-token generation.

        ::

            for chunk in mail.streaming.generate_email(prompt="..."):
                print(chunk.get("delta", ""), end="")
        """
        return self._c._sse_frames("POST", "/ai/generate-email/stream", options)

    def campaign_send(self, campaign_id: str):
        """``GET /api/campaigns/{id}/send-stream`` — live send progress."""
        from urllib.parse import quote

        return self._c._sse_frames(
            "GET", f"/campaigns/{quote(campaign_id, safe='')}/send-stream"
        )


class MisarMailClient(_MisarMailCore):
    """
    MisarMail API client — sync and async.

    Sync usage:
        client = MisarMailClient("msk_...")
        client.email.send({...})
        client.contacts.list(page=1, limit=50)

    Async usage:
        client = MisarMailClient("msk_...")
        await client.email.asend({...})
        await client.contacts.alist()
    """

    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        max_retries: int = 3,
        timeout: float = 30.0,
    ) -> None:
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        # billing + workspaces use /api base (without /v1)
        self._api_base = self._base_url.replace("/v1", "")
        self._max_retries = max_retries
        self._timeout = timeout

        self.email = _EmailResource(self)
        self.contacts = _ContactsResource(self)
        self.campaigns = _CampaignsResource(self)
        self.templates = _TemplatesResource(self)
        self.automations = _AutomationsResource(self)
        self.domains = _DomainsResource(self)
        self.dedicated_ips = _DedicatedIPsResource(self)
        self.ab_tests = _ABTestsResource(self)
        self.sandbox = _SandboxResource(self)
        self.inbound = _InboundResource(self)
        self.analytics = _AnalyticsResource(self)
        self.track = _TrackResource(self)
        self.keys = _KeysResource(self)
        self.validate = _ValidateResource(self)
        self.webhooks = _WebhooksResource(self)
        self.usage = _UsageResource(self)
        self.billing = _BillingResource(self)
        self.plan = _PlanResource(self)
        self.streaming = _StreamingResource(self)
        self.ai = _AiResource(self)
        self.credit_rates = _CreditRatesResource(self)
        self.deliverability = _DeliverabilityResource(self)
        self.dmarc = _DmarcResource(self)
        self.email_accounts = _EmailAccountsResource(self)
        self.emails = _EmailsResource(self)
        self.landing_pages = _LandingPagesResource(self)
        self.monetization = _MonetizationResource(self)
        self.revenue = _RevenueResource(self)
        self.segments = _SegmentsResource(self)
        self.subscription = _SubscriptionResource(self)
        self.team_members = _TeamMembersResource(self)
        self.wallet = _WalletResource(self)
        self.warmup = _WarmupResource(self)
