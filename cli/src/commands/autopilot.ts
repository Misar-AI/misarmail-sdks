import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult, parseJSON } from "../output.js";

export function makeAutopilotCommand(): Command {
  const cmd = new Command("autopilot").description("AI autopilot campaign management");

  cmd
    .command("start")
    .description("Start an autopilot campaign")
    .requiredOption("--data <json>", "Autopilot configuration as JSON")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/autopilot", parseJSON(opts.data, "data"));
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("get")
    .description("Get autopilot campaign status")
    .argument("<id>", "Autopilot ID")
    .action(async (id, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", `/autopilot/${id}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("list")
    .description("List autopilot campaigns")
    .option("--page <n>", "Page number")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const qs = opts.page ? `?page=${opts.page}` : "";
        const result = await makeRequest(apiKey, baseURL, "GET", `/autopilot${qs}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("daily-plan")
    .description("Get today's autopilot action plan")
    .action(async (_opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", "/autopilot/daily-plan");
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
