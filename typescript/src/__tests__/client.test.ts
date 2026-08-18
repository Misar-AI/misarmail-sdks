import { describe, it, expect, vi, beforeEach } from "vitest";
import { MisarMailClient, MisarMailError, MisarMailNetworkError } from "../index.js";

// The mocked fetch returns whatever body a case hands it, so a wrong shape here
// still passes at runtime — only `tsc --noEmit` catches the drift. Every mock
// below therefore mirrors the declared response type exactly, envelope included.
function mockFetch(status: number, body: unknown) {
  return vi.fn().mockResolvedValue({
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
    statusText: status === 200 ? "OK" : "Error",
  } as Response);
}

const contact = (id: string, email: string) => ({
  id, email, status: "active" as const, created_at: "", updated_at: "",
});

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
    vi.stubGlobal("fetch", mockFetch(200, { data: [contact("1", "a@b.com")], total: 1, page: 1, limit: 20 }));
    const res = await new MisarMailClient("k").contacts.list();
    expect(res.data).toHaveLength(1);
    expect(res.data[0].email).toBe("a@b.com");
  });

  it("create() returns the new contact inside the envelope", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { success: true, data: contact("2", "x@y.com") }));
    const res = await new MisarMailClient("k").contacts.create({ email: "x@y.com" });
    expect(res.data.id).toBe("2");
  });

  it("import() reports counts under summary, and errors as a list", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      success: true,
      summary: { imported: 5, updated: 1, skipped: 0, errors: 0 },
      errors: [],
    }));
    const res = await new MisarMailClient("k").contacts.import({ contacts: [{ email: "a@b.com" }] });
    expect(res.summary.imported).toBe(5);
    expect(res.summary.errors).toBe(0);
    expect(res.errors).toEqual([]);
  });
});

describe("campaigns", () => {
  it("list() returns campaigns", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      data: [{ id: "c1", name: "Test", subject: "Hi", status: "draft", created_at: "", updated_at: "" }],
      total: 1, page: 1, limit: 20,
    }));
    const res = await new MisarMailClient("k").campaigns.list();
    expect(res.data[0].id).toBe("c1");
  });

  it("create() takes fromName/fromEmail and returns the campaign in an envelope", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      success: true,
      data: { id: "c2", name: "N", subject: "S", status: "draft", created_at: "", updated_at: "" },
    }));
    const res = await new MisarMailClient("k").campaigns.create({
      name: "N", subject: "S", fromName: "A", fromEmail: "a@b.com",
    });
    expect(res.data.id).toBe("c2");
  });

  it("send() reports the campaign as scheduled", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      success: true, message: "queued", campaignId: "c1", status: "scheduled",
    }));
    const res = await new MisarMailClient("k").campaigns.send("c1");
    expect(res.success).toBe(true);
    expect(res.campaignId).toBe("c1");
    expect(res.status).toBe("scheduled");
  });
});

describe("analytics.get()", () => {
  it("returns aggregate totals and rates", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      success: true,
      data: {
        period: { start: "2026-04-01", end: "2026-04-30" },
        emailUsage: [],
        campaignTotals: { sent: 100, opened: 40, clicked: 10, bounced: 2, complained: 0 },
        rates: { openRate: 0.4, clickRate: 0.1, bounceRate: 0.02 },
      },
    }));
    const res = await new MisarMailClient("k").analytics.get();
    // get() is typed as campaign-scoped OR aggregate; narrow before reading.
    if (!("campaignTotals" in res.data)) throw new Error("expected the aggregate shape");
    expect(res.data.campaignTotals.sent).toBe(100);
    expect(res.data.rates.openRate).toBe(0.4);
  });
});

describe("validate.email()", () => {
  const result = (email: string, isValid: boolean, mx: boolean) => ({
    email,
    is_valid: isValid,
    score: isValid ? 0.98 : 0.1,
    checks: { syntax: true, mx, smtp: null },
    flags: {},
  });

  it("reports a good address as valid", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      success: true,
      data: result("a@b.com", true, true),
      credits: { used: 1, balance_after: 99 },
    }));
    const res = await new MisarMailClient("k").validate.email({ email: "a@b.com" });
    expect(res.data.is_valid).toBe(true);
    expect(res.credits.balance_after).toBe(99);
  });

  it("reports a typo domain as invalid", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      success: true,
      data: result("a@gmal.com", false, false),
      credits: { used: 1, balance_after: 98 },
    }));
    const res = await new MisarMailClient("k").validate.email({ email: "a@gmal.com" });
    expect(res.data.is_valid).toBe(false);
    expect(res.data.checks.mx).toBe(false);
  });
});

describe("templates", () => {
  it("list() returns templates", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      data: [{ id: "t1", name: "Welcome", subject: "Hi", html: "<p>Hi</p>", created_at: "", updated_at: "" }],
      total: 1,
    }));
    const res = await new MisarMailClient("k").templates.list();
    expect(res.data[0].id).toBe("t1");
  });

  it("render() returns the rendered html inside the envelope", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      success: true,
      data: {
        subject: "Hi Bob", html: "<p>Hello Bob</p>", text: null,
        templateId: "t1", templateName: "Welcome",
      },
    }));
    const res = await new MisarMailClient("k").templates.render({
      template_id: "t1", variables: { name: "Bob" },
    });
    expect(res.data.html).toContain("Bob");
    expect(res.data.subject).toBe("Hi Bob");
  });
});

describe("track", () => {
  it("event() names the event via event_name", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { success: true }));
    const res = await new MisarMailClient("k").track.event({ email: "a@b.com", event_name: "page_view" });
    expect(res.success).toBe(true);
  });

  it("purchase() takes the total in cents", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { success: true }));
    const res = await new MisarMailClient("k").track.purchase({
      email: "a@b.com", order_id: "ord-1", total_cents: 9900,
    });
    expect(res.success).toBe(true);
  });
});

describe("keys", () => {
  it("list() returns api keys under `keys`, not `data`", async () => {
    vi.stubGlobal("fetch", mockFetch(200, {
      success: true,
      keys: [{ id: "k1", name: "prod", scopes: ["send"], created_at: "" }],
    }));
    const res = await new MisarMailClient("k").keys.list();
    expect(res.keys[0].scopes).toContain("send");
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
    vi.stubGlobal("fetch", mockFetch(200, {
      data: [{ id: "ab1", name: "Subject test", status: "running", variants: [], created_at: "" }],
      total: 1,
    }));
    const res = await new MisarMailClient("k").abTests.list();
    expect(res.data[0].id).toBe("ab1");
  });
});

describe("sandbox", () => {
  it("list() returns sandbox sends under `sends`, not `data`", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { success: true, sends: [], total: 0 }));
    const res = await new MisarMailClient("k").sandbox.list();
    expect(res.sends).toHaveLength(0);
    expect(res.total).toBe(0);
  });
});

describe("inbound", () => {
  it("list() returns inbound emails", async () => {
    vi.stubGlobal("fetch", mockFetch(200, { data: [], total: 0 }));
    const res = await new MisarMailClient("k").inbound.list();
    expect(Array.isArray(res.data)).toBe(true);
  });
});
