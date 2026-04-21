import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult, parseJSON } from "../output.js";

export function makeInboundCommand(): Command {
  const cmd = new Command("inbound").description("Manage inbound routing rules");

  cmd
    .command("list")
    .description("List inbound routes")
    .action(async (_opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", "/inbound");
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("create")
    .description("Create an inbound route")
    .requiredOption("--data <json>", "Route data as JSON")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/inbound", parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("get")
    .description("Get an inbound route by ID")
    .argument("<id>", "Route ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/inbound/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("delete")
    .description("Delete an inbound route")
    .argument("<id>", "Route ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "DELETE", `/inbound/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
