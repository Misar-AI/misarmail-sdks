import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult } from "../output.js";

export function makeDomainsCommand(): Command {
  const cmd = new Command("domains").description("Manage sending domains");

  cmd
    .command("list")
    .description("List all domains")
    .action(async (_opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", "/domains");
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("create")
    .description("Add a sending domain")
    .requiredOption("--domain <domain>", "Domain name e.g. example.com")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/domains", { domain: opts.domain });
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("get")
    .description("Get a domain by ID")
    .argument("<id>", "Domain ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/domains/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("verify")
    .description("Trigger domain DNS verification")
    .argument("<id>", "Domain ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", `/domains/${id}/verify`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("delete")
    .description("Delete a domain")
    .argument("<id>", "Domain ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "DELETE", `/domains/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
