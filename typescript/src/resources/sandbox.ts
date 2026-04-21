import type { BaseClient, SandboxListResponse } from "../types.js";

export class SandboxResource {
  constructor(private client: BaseClient) {}

  list(params?: Record<string, unknown>): Promise<SandboxListResponse> {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/sandbox${qs}`);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.request("DELETE", `/sandbox/${id}`);
  }
}
