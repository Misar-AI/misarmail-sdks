import type { BaseClient } from "../types.js";

export interface InboundDomain {
  id: string;
  domain: string;
  subdomain: string;
  webhook_url: string;
  is_verified: boolean;
  mx_verified: boolean;
  status: "pending" | "active" | "suspended";
  created_at: string;
  updated_at: string;
}

export interface InboundDomainCreated extends InboundDomain {
  webhook_secret: string;
}

export interface CreateInboundDomainRequest {
  domain: string;
  subdomain: string;
  webhook_url: string;
}

export interface CreateInboundDomainResponse {
  success: true;
  data: InboundDomainCreated;
  instructions: {
    mx_record: string;
    note: string;
  };
}

export class InboundResource {
  constructor(private client: BaseClient) {}

  /** GET /inbound — list all inbound domains */
  list(): Promise<{ success: true; data: InboundDomain[] }> {
    return this.client.request("GET", "/inbound");
  }

  /**
   * POST /inbound — register a new inbound domain.
   * Returns webhook_secret once — store it securely.
   */
  create(request: CreateInboundDomainRequest): Promise<CreateInboundDomainResponse> {
    return this.client.request("POST", "/inbound", request);
  }

  /**
   * DELETE /inbound — remove an inbound domain by id (passed in body).
   */
  delete(id: string): Promise<{ success: true }> {
    return this.client.request("DELETE", "/inbound", { id });
  }
}
