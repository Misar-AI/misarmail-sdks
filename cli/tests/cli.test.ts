import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("@misar/mail", () => {
  class MisarMailClient {
    email = {
      send: vi.fn().mockResolvedValue({ id: "msg_1", status: "queued" }),
    };
    contacts = {
      list: vi.fn().mockResolvedValue({ contacts: [{ id: "c_1", email: "a@b.com" }], total: 1 }),
      create: vi.fn().mockResolvedValue({ id: "c_2", email: "new@b.com" }),
    };
    analytics = {
      get: vi.fn().mockResolvedValue({ sent: 200, opens: 80, clicks: 30, unsubscribes: 2 }),
    };
  }
  return { MisarMailClient };
});

import { program } from "../src/cli.js";

function runCmd(...args: string[]) {
  return program.parseAsync(args, { from: "user" });
}

beforeEach(() => {
  process.env.MISARMAIL_API_KEY = "test-key";
  vi.spyOn(console, "log").mockImplementation(() => {});
  vi.spyOn(process, "exit").mockImplementation(() => {
    throw new Error("exit");
  });
});

describe("misarmail send", () => {
  it("prints sent message id", async () => {
    await runCmd("send", "--to", "a@b.com", "--subject", "Hi", "--html", "<p>Hi</p>");
    expect(console.log).toHaveBeenCalledWith(expect.stringContaining("msg_1"));
  });

  it("outputs JSON with --json", async () => {
    await runCmd("send", "--to", "a@b.com", "--subject", "Hi", "--html", "<p>Hi</p>", "--json");
    const call = (console.log as ReturnType<typeof vi.fn>).mock.calls[0][0];
    const parsed = JSON.parse(call);
    expect(parsed.id).toBe("msg_1");
  });
});

describe("misarmail contacts list", () => {
  it("prints total", async () => {
    await runCmd("contacts", "list");
    expect(console.log).toHaveBeenCalledWith(expect.stringContaining("Total"));
  });
});

describe("misarmail contacts create", () => {
  it("prints created contact id", async () => {
    await runCmd("contacts", "create", "--email", "new@b.com");
    expect(console.log).toHaveBeenCalledWith(expect.stringContaining("c_2"));
  });
});

describe("misarmail analytics", () => {
  it("prints sent count", async () => {
    await runCmd("analytics");
    expect(console.log).toHaveBeenCalledWith(expect.stringContaining("200"));
  });
});
