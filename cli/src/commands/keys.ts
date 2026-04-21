import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult } from "../output.js";

export function makeKeysCommand(): Command {
  const cmd = new Command("keys").description("Manage API keys");

  cmd
    .command("list")
    .description("List all API keys")
    .action(async (_opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", "/keys");
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("create")
    .description("Create a new API key")
    .requiredOption("--name <name>", "Key name")
    .option("--scopes <scopes>", "Comma-separated scopes e.g. send,contacts")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const payload: Record<string, unknown> = { name: opts.name };
        if (opts.scopes) payload.scopes = opts.scopes.split(",").map((s: string) => s.trim());
        const result = await makeRequest(apiKey, baseURL, "POST", "/keys", payload);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("get")
    .description("Get an API key by ID")
    .argument("<id>", "API key ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/keys/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("revoke")
    .description("Revoke an API key")
    .argument("<id>", "API key ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "DELETE", `/keys/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
