import type { BaseClient } from "../types.js";

export interface EmailAccount {
  id: string;
  email: string;
  display_name: string | null;
  is_default: boolean | null;
  sync_status: string | null;
}

export interface EmailAccountsListResponse {
  success: true;
  /** Owned accounts plus those shared with the user via account_shares. */
  data: EmailAccount[];
}

/**
 * Read the API key user's sender (email) accounts — owned + shared.
 *
 * - `list()` → GET /v1/email-accounts
 */
export class EmailAccountsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /email-accounts — owned + shared sender accounts (read-only). */
  list(): Promise<EmailAccountsListResponse> {
    return this.client.request("GET", "/email-accounts");
  }
}
