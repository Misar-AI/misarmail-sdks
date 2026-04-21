import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult, parseJSON } from "../output.js";

export function makeEmailCommand(): Command {
  const cmd = new Command("email").description("Send transactional email");

  cmd
    .command("send")
    .description("Send an email")
    .requiredOption("--from <json>", 'Sender JSON e.g. \'{"email":"you@example.com"}\'')
    .requiredOption("--to <json>", 'Recipients JSON array e.g. \'[{"email":"them@example.com"}]\'')
    .requiredOption("--subject <subject>", "Email subject")
    .requiredOption("--html <html>", "HTML body content")
    .option("--text <text>", "Plain text body")
    .action(async (opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const from = parseJSON(opts.from, "from");
        const to = parseJSON(opts.to, "to");
        const payload: Record<string, unknown> = { from, to, subject: opts.subject, html: opts.html };
        if (opts.text) payload.text = opts.text;
        const result = await makeRequest(apiKey, baseURL, "POST", "/send", payload);
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
