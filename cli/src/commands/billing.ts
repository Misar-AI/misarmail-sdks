import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult } from "../output.js";

export function makeBillingCommand(): Command {
  const cmd = new Command("billing").description("Billing and subscription management");

  cmd
    .command("subscription")
    .description("Get current subscription details")
    .action(async (_opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "GET", "/billing/subscription");
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("checkout")
    .description("Create a checkout session to upgrade plan")
    .requiredOption("--plan <plan>", "Plan name e.g. pro, business")
    .requiredOption("--period <period>", "Billing period: monthly or yearly")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/billing/checkout", {
          plan: opts.plan,
          period: opts.period,
        });
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
