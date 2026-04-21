import type {
  BaseClient,
  PaginationParams,
  Contact,
  CreateContactRequest,
  ContactsListResponse,
  ContactImportRequest,
  ContactImportResponse,
} from "../types.js";

export class ContactsResource {
  constructor(private client: BaseClient) {}

  list(params?: PaginationParams): Promise<ContactsListResponse> {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/contacts${qs}`);
  }

  create(request: CreateContactRequest): Promise<Contact> {
    return this.client.request("POST", "/contacts", request);
  }

  get(id: string): Promise<Contact> {
    return this.client.request("GET", `/contacts/${id}`);
  }

  update(id: string, request: Partial<CreateContactRequest>): Promise<Contact> {
    return this.client.request("PATCH", `/contacts/${id}`, request);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.request("DELETE", `/contacts/${id}`);
  }

  import(request: ContactImportRequest): Promise<ContactImportResponse> {
    return this.client.request("POST", "/contacts/import", request);
  }
}
