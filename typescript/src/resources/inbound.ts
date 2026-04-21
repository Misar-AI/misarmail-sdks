import type { BaseClient, InboundEmail, InboundListResponse } from "../types.js";

export class InboundResource {
  constructor(private client: BaseClient) {}

  list(): Promise<InboundListResponse> {
    return this.client.request("GET", "/inbound");
  }

  get(id: string): Promise<InboundEmail> {
    return this.client.request("GET", `/inbound/${id}`);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.request("DELETE", `/inbound/${id}`);
  }
}
