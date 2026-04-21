import { Command } from "commander";
import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

interface ConfigFile {
  api_key?: string;
  base_url?: string;
}

export function getConfig(cmd: Command): { apiKey: string; baseURL: string } {
  const globals = cmd.optsWithGlobals() as Record<string, string | undefined>;

  let apiKey = globals["apiKey"] ?? process.env.MISARMAIL_API_KEY;
  let baseURL = globals["baseUrl"] ?? process.env.MISARMAIL_BASE_URL;

  if (!apiKey || !baseURL) {
    const cfgPath = join(homedir(), ".misarmail.json");
    if (existsSync(cfgPath)) {
      try {
        const cfg = JSON.parse(readFileSync(cfgPath, "utf8")) as ConfigFile;
        if (!apiKey && cfg.api_key) apiKey = cfg.api_key;
        if (!baseURL && cfg.base_url) baseURL = cfg.base_url;
      } catch {
        // ignore malformed config
      }
    }
  }

  if (!apiKey) {
    console.error(
      "Error: API key required. Set MISARMAIL_API_KEY, use --api-key, or add api_key to ~/.misarmail.json"
    );
    process.exit(1);
  }

  return {
    apiKey,
    baseURL: baseURL ?? "https://mail.misar.io/api/v1",
  };
}
