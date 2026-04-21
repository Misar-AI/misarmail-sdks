import { Command } from "commander";
import { getConfig } from "../config.js";
import { makeRequest } from "../http.js";
import { printResult } from "../output.js";

export function makeValidateCommand(): Command {
  const cmd = new Command("validate").description("Validation utilities");

  cmd
    .command("email")
    .description("Validate an email address")
    .argument("<address>", "Email address to validate")
    .action(async (address, _opts, sub) => {
      try {
        const { apiKey, baseURL } = getConfig(sub);
        const result = await makeRequest(apiKey, baseURL, "POST", "/validate", { email: address });
        printResult(result, sub.optsWithGlobals());
      } catch (err) {
        console.error("Error:", err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    });

  return cmd;
}
