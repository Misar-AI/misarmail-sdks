import type { BaseClient } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type DraftRecipient = { email: string };

export type Draft = {
  id: string;
  account_id: string;
  to_addresses: DraftRecipient[];
  cc_addresses: DraftRecipient[];
  bcc_addresses: DraftRecipient[];
  subject: string;
  body_text: string;
  body_html: string;
  updated_at: string;
  created_at: string;
};

export type DraftsListResponse = {
  drafts: Draft[];
};

export type CreateDraftRequest = {
  /** UUID of the email account to draft from */
  accountId: string;
  /** Comma-separated recipient emails */
  to?: string;
  cc?: string;
  bcc?: string;
  subject?: string;
  bodyText?: string;
  bodyHtml?: string;
  /** UUID of the email being replied to */
  replyToEmailId?: string;
};

export type UpdateDraftRequest = CreateDraftRequest & {
  /** UUID of the draft to update */
  id: string;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class DraftsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /drafts — list all drafts (optionally filtered by accountId) */
  list(accountId?: string): Promise<DraftsListResponse> {
    const qs = accountId ? `?accountId=${encodeURIComponent(accountId)}` : "";
    return this.client.requestRoot("GET", `/drafts${qs}`);
  }

  /** POST /drafts — create a new draft */
  create(request: CreateDraftRequest): Promise<{ draft: Draft; created: boolean }> {
    return this.client.requestRoot("POST", "/drafts", request);
  }

  /** PUT /drafts — update an existing draft */
  update(request: UpdateDraftRequest): Promise<{ draft: Draft; updated: boolean }> {
    return this.client.requestRoot("PUT", "/drafts", request);
  }

  /** DELETE /drafts?id=<uuid> — delete a draft */
  delete(id: string): Promise<{ deleted: boolean }> {
    return this.client.requestRoot("DELETE", `/drafts?id=${encodeURIComponent(id)}`);
  }
}
