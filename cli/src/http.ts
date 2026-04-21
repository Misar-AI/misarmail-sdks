export async function makeRequest(
  apiKey: string,
  baseURL: string,
  method: string,
  path: string,
  body?: unknown
): Promise<unknown> {
  const url = baseURL.replace(/\/$/, "") + path;
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${apiKey}`,
  };

  const res = await fetch(url, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    let msg = `HTTP ${res.status}`;
    try {
      const e = (await res.json()) as Record<string, unknown>;
      msg += `: ${String(e.error ?? e.message ?? res.statusText)}`;
    } catch {
      msg += `: ${res.statusText}`;
    }
    throw new Error(msg);
  }

  const text = await res.text();
  if (!text) return {};
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return text;
  }
}
