import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult } from "../output.js";

export function makeAnalyticsCommand(): Command {
  const cmd = new Command("analytics").description("Email analytics");

  cmd
    .command("overview")
    .description("Get analytics overview")
    .option("--start-date <date>", "Start date YYYY-MM-DD")
    .option("--end-date <date>", "End date YYYY-MM-DD")
    .option("--campaign-id <id>", "Filter by campaign ID")
    .option("--group-by <period>", "Group by: day, week, or month")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const params = new URLSearchParams();
        if (opts.startDate) params.append("start_date", opts.startDate);
        if (opts.endDate) params.append("end_date", opts.endDate);
        if (opts.campaignId) params.append("campaign_id", opts.campaignId);
        if (opts.groupBy) params.append("group_by", opts.groupBy);
        const qs = params.toString() ? `?${params.toString()}` : "";
        const result = await makeRequest(apiKey, baseURL, "GET", `/analytics${qs}`);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
