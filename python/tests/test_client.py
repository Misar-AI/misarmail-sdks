import pytest
import httpx
import respx

from misarmail import MisarMailClient, MisarMailError, MisarMailNetworkError

BASE = "https://mail.misar.io/api/v1"


def make_client(**kwargs) -> MisarMailClient:
    return MisarMailClient(api_key="test-key", **kwargs)


@respx.mock
async def test_send_email():
    respx.post(f"{BASE}/send").mock(return_value=httpx.Response(200, json={"id": "msg_1", "status": "queued"}))
    client = make_client()
    resp = await client.send_email({"to": "a@b.com", "subject": "Hi", "html": "<p>Hi</p>"})
    assert resp["id"] == "msg_1"
    await client.aclose()


@respx.mock
async def test_contacts_list():
    respx.get(f"{BASE}/contacts").mock(return_value=httpx.Response(200, json={"contacts": [], "total": 0}))
    client = make_client()
    resp = await client.contacts_list()
    assert resp["total"] == 0
    await client.aclose()


@respx.mock
async def test_contacts_create():
    respx.post(f"{BASE}/contacts").mock(return_value=httpx.Response(200, json={"id": "c_1", "email": "x@y.com"}))
    client = make_client()
    resp = await client.contacts_create({"email": "x@y.com"})
    assert resp["id"] == "c_1"
    await client.aclose()


@respx.mock
async def test_campaigns_list():
    respx.get(f"{BASE}/campaigns").mock(return_value=httpx.Response(200, json={"campaigns": [], "total": 0}))
    client = make_client()
    resp = await client.campaigns_list()
    assert "campaigns" in resp
    await client.aclose()


@respx.mock
async def test_campaigns_create():
    payload = {"name": "Welcome", "subject": "Hi there"}
    respx.post(f"{BASE}/campaigns").mock(return_value=httpx.Response(200, json={"id": "camp_1", **payload}))
    client = make_client()
    resp = await client.campaigns_create(payload)
    assert resp["id"] == "camp_1"
    await client.aclose()


@respx.mock
async def test_analytics_get():
    respx.get(f"{BASE}/analytics").mock(return_value=httpx.Response(200, json={"sent": 100, "opens": 40, "clicks": 10}))
    client = make_client()
    resp = await client.analytics_get()
    assert resp["sent"] == 100
    await client.aclose()


@respx.mock
async def test_validate_email():
    respx.post(f"{BASE}/validate").mock(return_value=httpx.Response(200, json={"valid": True, "email": "a@b.com"}))
    client = make_client()
    resp = await client.validate_email({"email": "a@b.com"})
    assert resp["valid"] is True
    await client.aclose()


@respx.mock
async def test_keys_list():
    respx.get(f"{BASE}/keys").mock(return_value=httpx.Response(200, json={"keys": [{"id": "k_1", "name": "prod"}]}))
    client = make_client()
    resp = await client.keys_list()
    assert resp["keys"][0]["id"] == "k_1"
    await client.aclose()


@respx.mock
async def test_error_401():
    respx.post(f"{BASE}/send").mock(return_value=httpx.Response(401, json={"error": "Unauthorized"}))
    client = make_client()
    with pytest.raises(MisarMailError) as exc_info:
        await client.send_email({"to": "a@b.com"})
    assert exc_info.value.status == 401
    await client.aclose()


@respx.mock
async def test_retry_503():
    """Should succeed on 2nd attempt after 503."""
    route = respx.post(f"{BASE}/send")
    route.side_effect = [
        httpx.Response(503, json={"error": "Service Unavailable"}),
        httpx.Response(200, json={"id": "msg_retry", "status": "queued"}),
    ]
    # Use a real async client so respx intercepts properly; patch sleep to not wait
    import asyncio
    original_sleep = asyncio.sleep

    async def fast_sleep(_: float):
        pass

    import misarmail.client as _mod
    _mod.asyncio.sleep = fast_sleep  # type: ignore[attr-defined]
    try:
        client = make_client(max_retries=2)
        resp = await client.send_email({"to": "a@b.com"})
        assert resp["id"] == "msg_retry"
        await client.aclose()
    finally:
        _mod.asyncio.sleep = original_sleep  # type: ignore[attr-defined]
