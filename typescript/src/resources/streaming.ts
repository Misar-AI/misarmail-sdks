import { MisarMailError } from "../errors.js";
import type { BaseClient } from "../types.js";

/**
 * One decoded Server-Sent Event frame.
 *
 * MisarMail's streams emit unnamed frames — `data: {...}` with no `event:`
 * line — and terminate with the sentinel `data: [DONE]`. The sentinel is
 * consumed by the iterator and never yielded, so callers can simply read to
 * completion.
 */
export interface MisarMailStreamEvent {
  /** The decoded JSON payload, or the raw string when it is not JSON. */
  data: unknown;
  /** The `event:` name when the server sends one. MisarMail currently does not. */
  event?: string;
}

/** A token of generated text, as emitted by the AI stream. */
export interface GenerateEmailDelta {
  delta?: string;
  type?: string;
  done?: boolean;
  error?: string;
}

export interface GenerateEmailOptions {
  prompt?: string;
  [key: string]: unknown;
}

/**
 * The streaming endpoints.
 *
 * Both live **off** the `/v1` prefix — they are `/api/ai/generate-email/stream`
 * and `/api/campaigns/{id}/send-stream` — so they go through the client's
 * root-base transport rather than the versioned one.
 *
 * Both are API-key authenticated (`verifyApiKey`) and metered like any other
 * call, so a plan refusal surfaces the same way it does elsewhere.
 */
export class StreamingResource {
  constructor(private readonly client: BaseClient) {}

  /**
   * `POST /api/ai/generate-email/stream` — token-by-token email generation.
   *
   * @example
   * for await (const chunk of blog.streaming.generateEmail({ prompt: "…" })) {
   *   if (chunk.delta) process.stdout.write(chunk.delta);
   * }
   */
  async *generateEmail(
    options: GenerateEmailOptions
  ): AsyncGenerator<GenerateEmailDelta, void, unknown> {
    for await (const frame of this.stream("POST", "/ai/generate-email/stream", options)) {
      yield frame.data as GenerateEmailDelta;
    }
  }

  /**
   * `GET /api/campaigns/{id}/send-stream` — live progress while a campaign sends.
   */
  async *campaignSend(
    campaignId: string
  ): AsyncGenerator<Record<string, unknown>, void, unknown> {
    const path = `/campaigns/${encodeURIComponent(campaignId)}/send-stream`;
    for await (const frame of this.stream("GET", path)) {
      yield frame.data as Record<string, unknown>;
    }
  }

  /**
   * Opens an SSE connection and yields each frame as it arrives.
   *
   * Frames are separated by a blank line and may span several `data:` lines,
   * which are joined with newlines per the SSE spec. A `[DONE]` payload ends
   * the stream.
   */
  async *stream(
    method: string,
    path: string,
    body?: unknown
  ): AsyncGenerator<MisarMailStreamEvent, void, unknown> {
    const res = await this.client.openStream(method, path, body);

    if (!res.ok || !res.body) {
      const raw = await res.text().catch(() => "");
      throw new MisarMailError(res.status, raw || res.statusText, "stream_error");
    }

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });

        // Frames end at a blank line. \r\n\r\n is tolerated for proxies that
        // rewrite line endings.
        let split: number;
        while ((split = findFrameEnd(buffer)) !== -1) {
          const frame = buffer.slice(0, split);
          buffer = buffer.slice(split).replace(/^(\r?\n){2}/, "");

          const parsed = parseFrame(frame);
          if (parsed === "done") return;
          if (parsed) yield parsed;
        }
      }

      // Whatever is left after the socket closes, if it is a complete frame.
      const tail = parseFrame(buffer);
      if (tail && tail !== "done") yield tail;
    } finally {
      reader.releaseLock();
    }
  }
}

function findFrameEnd(buffer: string): number {
  const lf = buffer.indexOf("\n\n");
  const crlf = buffer.indexOf("\r\n\r\n");
  if (lf === -1) return crlf;
  if (crlf === -1) return lf;
  return Math.min(lf, crlf);
}

/**
 * Parses one frame. Returns `"done"` for the terminating sentinel, `null` for
 * a comment-only or empty frame (SSE keepalives start with `:`).
 */
function parseFrame(frame: string): MisarMailStreamEvent | "done" | null {
  let event: string | undefined;
  const dataLines: string[] = [];

  for (const line of frame.split(/\r?\n/)) {
    if (!line || line.startsWith(":")) continue;
    if (line.startsWith("event:")) event = line.slice(6).trim();
    else if (line.startsWith("data:")) dataLines.push(line.slice(5).trimStart());
  }

  if (dataLines.length === 0) return null;

  const raw = dataLines.join("\n");
  if (raw === "[DONE]") return "done";

  try {
    return { data: JSON.parse(raw), ...(event ? { event } : {}) };
  } catch {
    return { data: raw, ...(event ? { event } : {}) };
  }
}
