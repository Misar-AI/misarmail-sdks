import type { BaseClient } from "../types.js";

export interface SandboxSendRecord {
  id: string;
  from_address: string;
  to_addresses: string[];
  subject: string;
  html?: string | null;
  message_id: string;
  metadata?: Record<string, unknown> | null;
  created_at: string;
}

export interface SandboxListResponse {
  success: true;
  sends: SandboxSendRecord[];
  total: number;
}

export class SandboxResource {
  constructor(private client: BaseClient) {}

  /** GET /sandbox — list the 50 most recent sandbox sends */
  list(): Promise<SandboxListResponse> {
    return this.client.request("GET", "/sandbox");
  }

  /** DELETE /sandbox — clear ALL sandbox sends for the account */
  clear(): Promise<{ success: true }> {
    return this.client.request("DELETE", "/sandbox");
  }
}
