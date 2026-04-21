import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult, parseJSON } from "../output.js";

export function makeCrmCommand(): Command {
  const cmd = new Command("crm").description("CRM — conversations, deals, and clients");

  // ── Conversations ──────────────────────────────────────────────────────────
  const conversations = new Command("conversations").description("Manage CRM conversations");

  conversations
    .command("list")
    .description("List conversations")
    .option("--status <status>", "Filter by status: active, closed, snoozed")
    .option("--channel <channel>", "Filter by channel: email, whatsapp")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const params = new URLSearchParams();
        if (opts.status) params.append("status", opts.status);
        if (opts.channel) params.append("channel", opts.channel);
        const qs = params.toString() ? `?${params.toString()}` : "";
        const result = await makeRequest(apiKey, baseURL, "GET", `/crm/conversations${qs}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  conversations
    .command("get")
    .description("Get a conversation by ID")
    .argument("<id>", "Conversation ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/crm/conversations/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  conversations
    .command("update")
    .description("Update a conversation")
    .argument("<id>", "Conversation ID")
    .requiredOption("--data <json>", "Updated fields as JSON")
    .action(async (id, opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "PATCH", `/crm/conversations/${id}`, parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  conversations
    .command("messages")
    .description("Get messages for a conversation")
    .argument("<id>", "Conversation ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/crm/conversations/${id}/messages`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd.addCommand(conversations);

  // ── Deals ──────────────────────────────────────────────────────────────────
  const deals = new Command("deals").description("Manage CRM deals");

  deals
    .command("list")
    .description("List deals")
    .option("--page <n>", "Page number")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const qs = opts.page ? `?page=${opts.page}` : "";
        const result = await makeRequest(apiKey, baseURL, "GET", `/crm/deals${qs}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  deals
    .command("create")
    .description("Create a deal")
    .requiredOption("--data <json>", "Deal data as JSON")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/crm/deals", parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  deals
    .command("get")
    .description("Get a deal by ID")
    .argument("<id>", "Deal ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/crm/deals/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  deals
    .command("update")
    .description("Update a deal")
    .argument("<id>", "Deal ID")
    .requiredOption("--data <json>", "Updated fields as JSON")
    .action(async (id, opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "PATCH", `/crm/deals/${id}`, parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  deals
    .command("delete")
    .description("Delete a deal")
    .argument("<id>", "Deal ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "DELETE", `/crm/deals/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd.addCommand(deals);

  // ── Clients ────────────────────────────────────────────────────────────────
  const clients = new Command("clients").description("Manage CRM clients");

  clients
    .command("list")
    .description("List clients")
    .option("--page <n>", "Page number")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const qs = opts.page ? `?page=${opts.page}` : "";
        const result = await makeRequest(apiKey, baseURL, "GET", `/crm/clients${qs}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  clients
    .command("create")
    .description("Create a client")
    .requiredOption("--data <json>", "Client data as JSON")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/crm/clients", parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd.addCommand(clients);

  return cmd;
}
