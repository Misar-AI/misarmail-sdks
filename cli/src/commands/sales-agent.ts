import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult, parseJSON } from "../output.js";

export function makeSalesAgentCommand(): Command {
  const cmd = new Command("sales-agent").description("AI sales agent configuration");

  cmd
    .command("get-config")
    .description("Get sales agent configuration")
    .action(async (_opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", "/sales-agent/config");
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("update-config")
    .description("Update sales agent configuration")
    .requiredOption("--data <json>", "Config data as JSON")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "PATCH", "/sales-agent/config", parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("get-actions")
    .description("List sales agent actions")
    .option("--page <n>", "Page number")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const qs = opts.page ? `?page=${opts.page}` : "";
        const result = await makeRequest(apiKey, baseURL, "GET", `/sales-agent/actions${qs}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
