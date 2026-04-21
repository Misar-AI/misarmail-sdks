export interface OutputOpts {
  pretty?: boolean;
  quiet?: boolean;
  json?: boolean;
}

export function printResult(data: unknown, opts: OutputOpts = {}): void {
  if (opts.quiet) return;
  console.log(JSON.stringify(data, null, 2));
}

export function parseJSON(raw: string, flag: string): unknown {
  try {
    return JSON.parse(raw);
  } catch {
    console.error(`Error: --${flag} must be valid JSON`);
    process.exit(1);
  }
}
