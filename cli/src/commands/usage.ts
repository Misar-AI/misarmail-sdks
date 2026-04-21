import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult } from "../output.js";

export function makeUsageCommand(): Command {
  return new Command("usage")
    .description("Get API usage stats")
    .option("--start-date <date>", "Start date YYYY-MM-DD")
    .option("--end-date <date>", "End date YYYY-MM-DD")
    .action(async (opts, cmd) => {
      try {
        const { apiKey, baseURL } = getConfig(cmd);
        const params = new URLSearchParams();
        if (opts.startDate) params.append("start_date", opts.startDate);
        if (opts.endDate) params.append("end_date", opts.endDate);
        const qs = params.toString() ? `?${params.toString()}` : "";
        const result = await makeRequest(apiKey, baseURL, "GET", `/usage${qs}`);
        printResult(result, cmd.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });
}
