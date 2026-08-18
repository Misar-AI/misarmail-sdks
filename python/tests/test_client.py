"""Tests for the MisarMail Python client.

Rewritten against the resource-based client. The previous suite targeted a flat
API (``client.send_email``, ``client.contacts_list``) that the client never
exposed, so it had never run.
"""

import httpx
import pytest

import misarmail.client as mc
from misarmail import MisarMailClient
from misarmail.errors import MisarMailError, MisarMailPlanLimitError

BASE = "https://api.misar.io/mail/v1"


class Recorder:
    """Stands in for httpx.request and records what the SDK sent."""

    def __init__(self, *responses):
        self.responses = list(responses)
        self.calls = []

    def __call__(self, method, url, **kw):
        self.calls.append({"method": method, "url": str(url), "params": kw.get("params"), "json": kw.get("json")})
        status, body, headers = self.responses[min(len(self.calls) - 1, len(self.responses) - 1)]
        return httpx.Response(status, json=body, headers=headers or {}, request=httpx.Request(method, url))

    @property
    def last(self):
        return self.calls[-1]


@pytest.fixture
def record(monkeypatch):
    def install(*responses):
        rec = Recorder(*responses)
        monkeypatch.setattr(mc.httpx, "request", rec)
        return rec

    return install


def client(**kw):
    return MisarMailClient("mmk_test", **kw)


# ── The subscription surface ─────────────────────────────────────────────────

def test_plan_get_targets_the_right_route(record):
    rec = record((200, {"plan": {"slug": "starter", "name": "Starter"}, "usage": [], "upgrade": None}, None))
    out = client().plan.get()

    assert rec.last["method"] == "GET"
    assert rec.last["url"] == f"{BASE}/plan"
    assert out["plan"]["slug"] == "starter"


def test_plan_limits_passes_the_product_filter(record):
    rec = record((200, {"success": True, "data": {}}, None))
    client().plan.limits(product="mail")

    assert rec.last["url"] == f"{BASE}/plan-limits"
    assert rec.last["params"]["product"] == "mail"


def test_wallet_debit_posts_the_body(record):
    rec = record((200, {"success": True, "balance": 9.0, "idempotent": False}, None))
    client().wallet.debit(data={"amount": 1, "reason": "test", "idempotency_key": "k1"})

    assert rec.last["method"] == "POST"
    assert rec.last["url"] == f"{BASE}/wallet/debit"
    assert rec.last["json"]["idempotency_key"] == "k1"


# ── Endpoints added in this pass ─────────────────────────────────────────────

def test_emails_list_sends_folder_and_search(record):
    rec = record((200, {"success": True, "data": [], "count": 0}, None))
    client().emails.list(folder="inbox", search="invoice", limit=10)

    assert rec.last["url"] == f"{BASE}/emails"
    assert rec.last["params"] == {"folder": "inbox", "search": "invoice", "limit": 10}


def test_emails_get_interpolates_the_id(record):
    rec = record((200, {"success": True, "data": {"id": "e1"}}, None))
    client().emails.get("e1")

    assert rec.last["url"] == f"{BASE}/emails/e1"


def test_dmarc_check_requires_a_domain(record):
    rec = record((200, {"success": True}, None))
    client().dmarc.check(domain="misarmail.com", dkim_selector="s1")

    assert rec.last["url"] == f"{BASE}/dmarc/check"
    assert rec.last["params"] == {"domain": "misarmail.com", "dkim_selector": "s1"}


def test_warmup_and_revenue_are_reachable(record):
    rec = record((200, {"success": True, "data": [], "count": 0}, None))
    client().warmup.get()
    assert rec.last["url"] == f"{BASE}/warmup"

    client().revenue.attribution(period="30d")
    assert rec.last["url"] == f"{BASE}/revenue/attribution"
    assert rec.last["params"]["period"] == "30d"


# ── Errors and retries ──────────────────────────────────────────────────────

def test_401_raises_a_typed_error(record):
    record((401, {"error": "Invalid or missing API key"}, None))
    with pytest.raises(MisarMailError) as exc:
        client().plan.get()
    assert exc.value.status == 401


def test_503_is_retried_then_succeeds(record):
    rec = record(
        (503, {"error": "upstream"}, None),
        (200, {"plan": {"slug": "starter"}}, None),
    )
    out = client(max_retries=3).plan.get()

    assert len(rec.calls) == 2
    assert out["plan"]["slug"] == "starter"


def test_plan_refusal_is_not_retried(record):
    """A spent allowance answers 429 — identical by status to a rate limit."""
    rec = record((
        429,
        {
            "error": "Monthly send allowance spent.",
            "code": "plan_limit_exceeded",
            "upgrade": {"feature": "emails", "currentPlanSlug": "starter",
                        "urls": {"pricing": "https://misarmail.com/pricing"}},
        },
        {"Retry-After": "600", "X-Misar-Plan": "starter"},
    ))

    with pytest.raises(MisarMailPlanLimitError) as exc:
        client(max_retries=3).plan.get()

    e = exc.value
    assert len(rec.calls) == 1, "a plan refusal must not burn the retry budget"
    assert e.plan == "starter"
    assert e.upgrade_url == "https://misarmail.com/pricing"
    assert e.retry_after == 600
    assert e.feature == "emails"


def test_plain_rate_limit_is_still_retried(record):
    rec = record(
        (429, {"error": "Rate limit exceeded"}, None),
        (200, {"plan": {"slug": "starter"}}, None),
    )
    client(max_retries=3).plan.get()
    assert len(rec.calls) == 2
