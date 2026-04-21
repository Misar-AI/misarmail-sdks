// Legacy top-level `misarmail send` — kept for backward compat.
// Prefer `misarmail email send` for the full option set.
import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult } from "../output.js";

export function makeSendCommand(): Command {
  return new Command("send")
    .description("Send a transactional email (shorthand for `email send`)")
    .requiredOption("--to <email>", "Recipient email address")
    .requiredOption("--subject <subject>", "Email subject")
    .requiredOption("--html <html>", "HTML body content")
    .option("--from <email>", "Sender email address")
    .action(async (opts, cmd) => {
      try {
        const { apiKey, baseURL } = getConfig(cmd);
        const payload: Record<string, unknown> = {
          to: [{ email: opts.to }],
          subject: opts.subject,
          html: opts.html,
        };
        if (opts.from) payload.from = { email: opts.from };
        const result = await makeRequest(apiKey, baseURL, "POST", "/send", payload);
        printResult(result, cmd.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });
}
