import { describe, it, expect, vi, beforeEach } from "vitest";
import { MisarMailClient, MisarMailError, MisarMailNetworkError } from "../index.js";

function mockFetch(status: number, body: unknown) {
  return vi.fn().mockResolvedValue({
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
    statusText: status === 200 ? "OK" : "Error",
  } as Response);
}

beforeEach(() => { vi.restoreAllMocks(); });

describe("email.send()", () => {
  it("returns message_id on success", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { success: true, message_id: "msg-001" }));
    const client = new MisarMailClient("msk_test");
    const res = await client.email.send({
      from: { email: "a@b.com" },
      to: [{ email: "c@d.com" }],
      subject: "Hi",
      html: "<p>Hi</p>",
    });
    expect(res.message_id).toBe("msg-001");
    expect(res.success).toBe(true);
  });
});

describe("contacts", () => {
  it("list() returns paginated contacts", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { data: [{ id: "1", email: "a@b.com", status: "active", created_at: "", updated_at: "" }], total: 1, page: 1, limit: 20 }));
    const res = await new MisarMailClient("k").contacts.list();
    expect(res.data).toHaveLength(1);
    expect(res.data[0].email).toBe("a@b.com");
  });

  it("create() returns new contact", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { id: "2", email: "x@y.com", status: "active", created_at: "", updated_at: "" }));
    const res = await new MisarMailClient("k").contacts.create({ email: "x@y.com" });
    expect(res.id).toBe("2");
  });

  it("import() returns counts", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { imported: 5, updated: 1, skipped: 0, errors: 0 }));
    const res = await new MisarMailClient("k").contacts.import({ contacts: [{ email: "a@b.com" }] });
    expect(res.imported).toBe(5);
    expect(res.errors).toBe(0);
  });
});

describe("campaigns", () => {
  it("list() returns campaigns", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { data: [{ id: "c1", name: "Test", subject: "Hi", status: "draft", from: { email: "a@b.com" }, created_at: "", updated_at: "" }], total: 1, page: 1, limit: 20 }));
    const res = await new MisarMailClient("k").campaigns.list();
    expect(res.data[0].id).toBe("c1");
  });

  it("create() returns campaign", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { id: "c2", name: "N", subject: "S", status: "draft", from: { email: "a@b.com" }, created_at: "", updated_at: "" }));
    const res = await new MisarMailClient("k").campaigns.create({ name: "N", subject: "S", from: { email: "a@b.com" } });
    expect(res.id).toBe("c2");
  });

  it("send() returns sent_at", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { success: true, sent_at: "2026-04-20T00:00:00Z" }));
    const res = await new MisarMailClient("k").campaigns.send("c1");
    expect(res.success).toBe(true);
    expect(res.sent_at).toBeDefined();
  });
});

describe("analytics.get()", () => {
  it("returns aggregated stats", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { sent: 100, delivered: 98, opens: 40, clicks: 10, bounces: 2, unsubscribes: 1, complaints: 0, open_rate: 0.4, click_rate: 0.1 }));
    const res = await new MisarMailClient("k").analytics.get();
    expect(res.sent).toBe(100);
    expect(res.open_rate).toBe(0.4);
  });
});

describe("validate.email()", () => {
  it("returns valid true for good email", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { valid: true, format_valid: true, mx_found: true }));
    const res = await new MisarMailClient("k").validate.email({ email: "a@b.com" });
    expect(res.valid).toBe(true);
  });

  it("returns valid false with suggestion for typo", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { valid: false, format_valid: true, mx_found: false, suggestion: "a@gmail.com" }));
    const res = await new MisarMailClient("k").validate.email({ email: "a@gmal.com" });
    expect(res.valid).toBe(false);
    expect(res.suggestion).toBe("a@gmail.com");
  });
});

describe("templates", () => {
  it("list() returns templates", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { data: [{ id: "t1", name: "Welcome", subject: "Hi", html: "<p>Hi</p>", created_at: "", updated_at: "" }], total: 1 }));
    const res = await new MisarMailClient("k").templates.list();
    expect(res.data[0].id).toBe("t1");
  });

  it("render() returns rendered html", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { html: "<p>Hello Bob</p>", subject: "Hi Bob" }));
    const res = await new MisarMailClient("k").templates.render({ template_id: "t1", variables: { name: "Bob" } });
    expect(res.html).toContain("Bob");
  });
});

describe("track", () => {
  it("event() returns success", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { success: true }));
    const res = await new MisarMailClient("k").track.event({ email: "a@b.com", event: "page_view" });
    expect(res.success).toBe(true);
  });

  it("purchase() returns success", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { success: true }));
    const res = await new MisarMailClient("k").track.purchase({ email: "a@b.com", order_id: "ord-1", amount: 9900 });
    expect(res.success).toBe(true);
  });
});

describe("keys", () => {
  it("list() returns api keys", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { data: [{ id: "k1", name: "prod", scopes: ["send"], created_at: "" }] }));
    const res = await new MisarMailClient("k").keys.list();
    expect(res.data[0].scopes).toContain("send");
  });

  it("create() returns key with secret", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { id: "k2", name: "new", key: "msk_secret", scopes: ["send"], created_at: "" }));
    const res = await new MisarMailClient("k").keys.create({ name: "new", scopes: ["send"] });
    expect(res.key).toBe("msk_secret");
  });
});

describe("error handling", () => {
  it("throws MisarMailError on 401", async () => {
    vi.stubGlobal("fetch", mockFetch(401, { error: "Unauthorized" }));
    await expect(new MisarMailClient("bad").email.send({ from: { email: "a@b.com" }, to: [{ email: "c@d.com" }], subject: "Hi" }))
      .rejects.toMatchObject({ status: 401 });
  });

  it("throws MisarMailError on 403 scope missing", async () => {
    vi.stubGlobal("fetch", mockFetch(403, { error: "API key does not have 'send' scope" }));
    const err = await new MisarMailClient("k").email.send({ from: { email: "a@b.com" }, to: [], subject: "S" }).catch(e => e);
    expect(err).toBeInstanceOf(MisarMailError);
    expect(err.status).toBe(403);
    expect(err.message).toContain("scope");
  });

  it("retries on 503 and succeeds", async () => {
    let calls = 0;
    vi.stubGlobal("fetch", vi.fn().mockImplementation(async () => {
      calls++;
      if (calls === 1) return { ok: false, status: 503, json: async () => ({ error: "down" }), statusText: "Service Unavailable" };
      return { ok: true, status: 200, json: async () => ({ success: true, message_id: "msg-retry" }) };
    }));
    const res = await new MisarMailClient("k", { maxRetries: 2 }).email.send({ from: { email: "a@b.com" }, to: [{ email: "c@d.com" }], subject: "Hi" });
    expect(res.message_id).toBe("msg-retry");
    expect(calls).toBe(2);
  });

  it("throws MisarMailNetworkError on fetch failure", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new TypeError("Failed to fetch")));
    await expect(new MisarMailClient("k", { maxRetries: 1 }).email.send({ from: { email: "a@b.com" }, to: [], subject: "S" }))
      .rejects.toBeInstanceOf(MisarMailNetworkError);
  });

  it("sets Authorization header with bearer token", async () => {
    const spy = vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ data: [], total: 0, page: 1, limit: 20 }) });
    vi.stubGlobal("fetch", spy);
    await new MisarMailClient("msk_mykey").contacts.list();
    expect(spy.mock.calls[0][1].headers["Authorization"]).toBe("Bearer msk_mykey");
  });
});

describe("ab tests", () => {
  it("list() returns ab tests", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { data: [{ id: "ab1", name: "Subject test", status: "running", variants: [], created_at: "" }], total: 1 }));
    const res = await new MisarMailClient("k").abTests.list();
    expect(res.data[0].id).toBe("ab1");
  });
});

describe("sandbox", () => {
  it("list() returns sandbox sends", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { data: [], total: 0 }));
    const res = await new MisarMailClient("k").sandbox.list();
    expect(res.data).toHaveLength(0);
  });
});

describe("inbound", () => {
  it("list() returns inbound emails", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { data: [], total: 0 }));
    const res = await new MisarMailClient("k").inbound.list();
    expect(Array.isArray(res.data)).toBe(true);
  });
});
