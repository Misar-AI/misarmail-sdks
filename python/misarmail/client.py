from __future__ import annotations

import asyncio
import time
from typing import Any, Optional

import httpx

from .errors import MisarMailError, MisarMailNetworkError

__all__ = ["MisarMailClient"]

DEFAULT_BASE_URL = "https://mail.misar.io/api/v1"
RETRY_BASE_S = 0.2
RETRYABLE = {429, 500, 502, 503, 504}


def _clean(d: dict | None) -> dict | None:
    if d is None:
        return None
    return {k: v for k, v in d.items() if v is not None}


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
                if status in RETRYABLE and attempt < self._max_retries - 1:
                    time.sleep(RETRY_BASE_S * (2**attempt))
                    continue
                if not resp.is_success:
                    data = resp.json() if resp.content else {}
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
                    if status in RETRYABLE and attempt < self._max_retries - 1:
                        await asyncio.sleep(RETRY_BASE_S * (2**attempt))
                        continue
                    if not resp.is_success:
                        data = resp.json() if resp.content else {}
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
        return self._c._request("GET", f"/contacts/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/contacts/{id}")

    def update(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/contacts/{id}", data)

    async def aupdate(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/contacts/{id}", data)

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/contacts/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/contacts/{id}")

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
        return self._c._request("GET", "/domains")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/domains")

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/domains", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/domains", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/domains/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/domains/{id}")

    def verify(self, id: str) -> dict[str, Any]:
        return self._c._request("POST", f"/domains/{id}/verify", {})

    async def averify(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("POST", f"/domains/{id}/verify", {})

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/domains/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/domains/{id}")


# ── Aliases ────────────────────────────────────────────────────────────────────

class _AliasesResource(_Resource):
    def list(self) -> dict[str, Any]:
        return self._c._request("GET", "/aliases")

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/aliases")

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/aliases", data)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/aliases", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/aliases/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/aliases/{id}")

    def update(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/aliases/{id}", data)

    async def aupdate(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/aliases/{id}", data)

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/aliases/{id}")

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/aliases/{id}")


# ── Dedicated IPs ──────────────────────────────────────────────────────────────

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


# ── Channels ───────────────────────────────────────────────────────────────────

class _ChannelsResource(_Resource):
    def send_whatsapp(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/channels/whatsapp/send", data)

    async def asend_whatsapp(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/channels/whatsapp/send", data)

    def send_push(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/channels/push/send", data)

    async def asend_push(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/channels/push/send", data)


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
            "/analytics/overview",
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
            "/analytics/overview",
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
        return self._c._request("GET", "/validate/email", params={"address": address})

    async def aemail(self, address: str) -> dict[str, Any]:
        return await self._c._arequest("GET", "/validate/email", params={"address": address})


# ── Leads ──────────────────────────────────────────────────────────────────────

class _LeadsResource(_Resource):
    def search(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/leads/search", data)

    async def asearch(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/leads/search", data)

    def get_job(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/leads/jobs/{id}")

    async def aget_job(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/leads/jobs/{id}")

    def list_jobs(self, page: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/leads/jobs", params={"page": page})

    async def alist_jobs(self, page: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/leads/jobs", params={"page": page})

    def results(self, job_id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/leads/jobs/{job_id}/results")

    async def aresults(self, job_id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/leads/jobs/{job_id}/results")

    def import_leads(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/leads/import", data)

    async def aimport_leads(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/leads/import", data)

    def credits(self) -> dict[str, Any]:
        return self._c._request("GET", "/leads/credits")

    async def acredits(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/leads/credits")


# ── Autopilot ──────────────────────────────────────────────────────────────────

class _AutopilotResource(_Resource):
    def start(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/autopilot", data)

    async def astart(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/autopilot", data)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/autopilot/{id}")

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/autopilot/{id}")

    def list(self, page: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/autopilot", params={"page": page})

    async def alist(self, page: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/autopilot", params={"page": page})

    def daily_plan(self) -> dict[str, Any]:
        return self._c._request("GET", "/autopilot/daily-plan")

    async def adaily_plan(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/autopilot/daily-plan")


# ── Sales Agent ────────────────────────────────────────────────────────────────

class _SalesAgentResource(_Resource):
    def get_config(self) -> dict[str, Any]:
        return self._c._request("GET", "/sales-agent/config")

    async def aget_config(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/sales-agent/config")

    def update_config(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", "/sales-agent/config", data)

    async def aupdate_config(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", "/sales-agent/config", data)

    def get_actions(self, page: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/sales-agent/actions", params={"page": page})

    async def aget_actions(self, page: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/sales-agent/actions", params={"page": page})


# ── CRM ────────────────────────────────────────────────────────────────────────

class _CRMResource(_Resource):
    def list_conversations(
        self,
        status: str | None = None,
        channel: str | None = None,
        campaign_id: str | None = None,
        page: int | None = None,
    ) -> dict[str, Any]:
        return self._c._request(
            "GET",
            "/crm/conversations",
            params={"status": status, "channel": channel, "campaign_id": campaign_id, "page": page},
        )

    async def alist_conversations(
        self,
        status: str | None = None,
        channel: str | None = None,
        campaign_id: str | None = None,
        page: int | None = None,
    ) -> dict[str, Any]:
        return await self._c._arequest(
            "GET",
            "/crm/conversations",
            params={"status": status, "channel": channel, "campaign_id": campaign_id, "page": page},
        )

    def get_conversation(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/crm/conversations/{id}")

    async def aget_conversation(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/crm/conversations/{id}")

    def update_conversation(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/crm/conversations/{id}", data)

    async def aupdate_conversation(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/crm/conversations/{id}", data)

    def list_messages(self, conversation_id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/crm/conversations/{conversation_id}/messages")

    async def alist_messages(self, conversation_id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/crm/conversations/{conversation_id}/messages")

    def list_deals(self, page: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/crm/deals", params={"page": page})

    async def alist_deals(self, page: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/crm/deals", params={"page": page})

    def create_deal(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/crm/deals", data)

    async def acreate_deal(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/crm/deals", data)

    def get_deal(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/crm/deals/{id}")

    async def aget_deal(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/crm/deals/{id}")

    def update_deal(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/crm/deals/{id}", data)

    async def aupdate_deal(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/crm/deals/{id}", data)

    def delete_deal(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/crm/deals/{id}")

    async def adelete_deal(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/crm/deals/{id}")

    def list_clients(self, page: int | None = None) -> dict[str, Any]:
        return self._c._request("GET", "/crm/clients", params={"page": page})

    async def alist_clients(self, page: int | None = None) -> dict[str, Any]:
        return await self._c._arequest("GET", "/crm/clients", params={"page": page})

    def create_client(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/crm/clients", data)

    async def acreate_client(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/crm/clients", data)


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

class _WorkspacesResource(_Resource):
    def list(self) -> dict[str, Any]:
        return self._c._request("GET", "/workspaces", use_api_base=True)

    async def alist(self) -> dict[str, Any]:
        return await self._c._arequest("GET", "/workspaces", use_api_base=True)

    def create(self, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", "/workspaces", data, use_api_base=True)

    async def acreate(self, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", "/workspaces", data, use_api_base=True)

    def get(self, id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/workspaces/{id}", use_api_base=True)

    async def aget(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/workspaces/{id}", use_api_base=True)

    def update(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/workspaces/{id}", data, use_api_base=True)

    async def aupdate(self, id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/workspaces/{id}", data, use_api_base=True)

    def delete(self, id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/workspaces/{id}", use_api_base=True)

    async def adelete(self, id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/workspaces/{id}", use_api_base=True)

    def list_members(self, ws_id: str) -> dict[str, Any]:
        return self._c._request("GET", f"/workspaces/{ws_id}/members", use_api_base=True)

    async def alist_members(self, ws_id: str) -> dict[str, Any]:
        return await self._c._arequest("GET", f"/workspaces/{ws_id}/members", use_api_base=True)

    def invite_member(self, ws_id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("POST", f"/workspaces/{ws_id}/members", data, use_api_base=True)

    async def ainvite_member(self, ws_id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("POST", f"/workspaces/{ws_id}/members", data, use_api_base=True)

    def update_member(self, ws_id: str, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        return self._c._request("PATCH", f"/workspaces/{ws_id}/members/{user_id}", data, use_api_base=True)

    async def aupdate_member(self, ws_id: str, user_id: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._c._arequest("PATCH", f"/workspaces/{ws_id}/members/{user_id}", data, use_api_base=True)

    def remove_member(self, ws_id: str, user_id: str) -> dict[str, Any]:
        return self._c._request("DELETE", f"/workspaces/{ws_id}/members/{user_id}", use_api_base=True)

    async def aremove_member(self, ws_id: str, user_id: str) -> dict[str, Any]:
        return await self._c._arequest("DELETE", f"/workspaces/{ws_id}/members/{user_id}", use_api_base=True)


# ── Main Client ────────────────────────────────────────────────────────────────

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
        self.aliases = _AliasesResource(self)
        self.dedicated_ips = _DedicatedIPsResource(self)
        self.channels = _ChannelsResource(self)
        self.ab_tests = _ABTestsResource(self)
        self.sandbox = _SandboxResource(self)
        self.inbound = _InboundResource(self)
        self.analytics = _AnalyticsResource(self)
        self.track = _TrackResource(self)
        self.keys = _KeysResource(self)
        self.validate = _ValidateResource(self)
        self.leads = _LeadsResource(self)
        self.autopilot = _AutopilotResource(self)
        self.sales_agent = _SalesAgentResource(self)
        self.crm = _CRMResource(self)
        self.webhooks = _WebhooksResource(self)
        self.usage = _UsageResource(self)
        self.billing = _BillingResource(self)
        self.workspaces = _WorkspacesResource(self)
