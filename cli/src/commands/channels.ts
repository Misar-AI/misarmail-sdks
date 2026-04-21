import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult, parseJSON } from "../output.js";

export function makeChannelsCommand(): Command {
  const cmd = new Command("channels").description("Send via alternative channels (WhatsApp, Push)");

  cmd
    .command("whatsapp")
    .description("Send a WhatsApp message via template")
    .requiredOption("--to <phone>", "Recipient phone number e.g. +919876543210")
    .requiredOption("--template <name>", "WhatsApp template name")
    .option("--params <json>", "Template params as JSON array")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const body: Record<string, unknown> = { to: opts.to, template: opts.template };
        if (opts.params) body.params = parseJSON(opts.params, "params");
        const result = await makeRequest(apiKey, baseURL, "POST", "/channels/whatsapp", body);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  cmd
    .command("push")
    .description("Send a push notification")
    .requiredOption("--to <token>", "Device token")
    .requiredOption("--title <title>", "Notification title")
    .requiredOption("--body <body>", "Notification body")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/channels/push", {
          to: opts.to,
          title: opts.title,
          body: opts.body,
        });
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
