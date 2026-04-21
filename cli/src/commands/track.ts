import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult, parseJSON } from "../output.js";

export function makeTrackCommand(): Command {
  const cmd = new Command("track").description("Track custom events and purchases");

  cmd
    .command("event")
    .description("Track a custom event")
    .requiredOption("--data <json>", "Event data as JSON")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/track/event", parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("purchase")
    .description("Track a purchase event")
    .requiredOption("--data <json>", "Purchase data as JSON")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/track/purchase", parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
