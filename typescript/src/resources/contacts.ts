import type { BaseClient, PaginationParams } from "../types.js";

export type ContactStatus = "subscribed" | "unsubscribed" | "bounced" | "complained";

export interface Contact {
  id: string;
  email: string;
  phone?: string | null;
  first_name?: string | null;
  last_name?: string | null;
  status: ContactStatus;
  custom_fields?: Record<string, unknown>;
  /** Engagement score (0-100). Reach uses this as a lead-quality signal. */
  engagement_score?: number | null;
  sms_opted_in?: boolean;
  created_at: string;
  updated_at: string;
}

export interface CreateContactRequest {
  email: string;
  firstName?: string;
  lastName?: string;
  status?: ContactStatus;
  customFields?: Record<string, unknown>;
  source?: string;
  tags?: string[];
}

export interface ContactsListParams extends PaginationParams {
  status?: ContactStatus;
  search?: string;
}

export interface ContactsListResponse {
  success: true;
  data: Contact[];
  pagination: { page: number; limit: number; total: number; totalPages: number };
}

export interface ContactImportRow {
  email: string;
  firstName?: string;
  lastName?: string;
  status?: ContactStatus;
  customFields?: Record<string, string>;
  tags?: string[];
}

export interface ContactImportRequest {
  contacts: ContactImportRow[];
  updateExisting?: boolean;
}

export interface ContactImportResponse {
  success: true;
  summary: { imported: number; updated: number; skipped: number; errors: number };
  errors: string[];
}

export class ContactsResource {
  constructor(private client: BaseClient) {}

  /** GET /contacts — list contacts with optional filtering */
  list(params?: ContactsListParams): Promise<ContactsListResponse> {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/contacts${qs}`);
  }

  /** POST /contacts — create a single contact */
  create(request: CreateContactRequest): Promise<{ success: true; data: Contact }> {
    return this.client.request("POST", "/contacts", request);
  }

  /**
   * DELETE /contacts?id=<uuid> — delete a contact by id.
   * Note: id is passed as a query parameter, not a path segment.
   */
  delete(id: string): Promise<{ success: true }> {
    return this.client.request("DELETE", `/contacts?id=${encodeURIComponent(id)}`);
  }

  /** POST /contacts/import — bulk import contacts (max 5000) */
  import(request: ContactImportRequest): Promise<ContactImportResponse> {
    return this.client.request("POST", "/contacts/import", request);
  }
}
