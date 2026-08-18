import type { BaseClient } from "../types.js";

/** A stored message in the account's mailbox. */
export interface StoredEmail {
  id: string;
  [key: string]: unknown;
}

export interface EmailListResponse {
  success: true;
  data: StoredEmail[];
  count: number;
}

export interface EmailResponse {
  success: true;
  data: StoredEmail;
}

export interface ListEmailsOptions {
  /** Mailbox folder to read, e.g. `inbox`, `sent`. */
  folder?: string;
  /** Free-text search across the folder. */
  search?: string;
  limit?: number;
}

/**
 * Stored messages.
 *
 * - `list()`   → GET   /v1/emails
 * - `get(id)`  → GET   /v1/emails/{id}
 * - `update()` → PATCH /v1/emails/{id}
 */
export class EmailsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /emails — messages in a folder, newest first. */
  list(options: ListEmailsOptions = {}): Promise<EmailListResponse> {
    const qs = new URLSearchParams();
    if (options.folder) qs.set("folder", options.folder);
    if (options.search) qs.set("search", options.search);
    if (options.limit !== undefined) qs.set("limit", String(options.limit));
    const q = qs.toString() ? `?${qs}` : "";
    return this.client.request("GET", `/emails${q}`);
  }

  /** GET /emails/{id} — a single stored message. */
  get(id: string): Promise<EmailResponse> {
    return this.client.request("GET", `/emails/${encodeURIComponent(id)}`);
  }

  /** PATCH /emails/{id} — update message state (read, folder, labels…). */
  update(id: string, changes: Record<string, unknown>): Promise<EmailResponse> {
    return this.client.request("PATCH", `/emails/${encodeURIComponent(id)}`, changes);
  }
}

export interface RevenueAttributionOptions {
  /** Restrict to a single campaign. */
  campaign_id?: string;
  /** Reporting window, e.g. `30d`. */
  period?: string;
}

/** GET /v1/revenue/attribution — revenue attributed to campaigns. */
export class RevenueResource {
  constructor(private readonly client: BaseClient) {}

  attribution(options: RevenueAttributionOptions = {}): Promise<Record<string, unknown>> {
    const qs = new URLSearchParams();
    if (options.campaign_id) qs.set("campaign_id", options.campaign_id);
    if (options.period) qs.set("period", options.period);
    const q = qs.toString() ? `?${qs}` : "";
    return this.client.request("GET", `/revenue/attribution${q}`);
  }
}

/** GET /v1/warmup — sending-reputation warm-up schedule and progress. */
export class WarmupResource {
  constructor(private readonly client: BaseClient) {}

  get(): Promise<{ success: true; data: Array<Record<string, unknown>>; count: number }> {
    return this.client.request("GET", "/warmup");
  }
}
