import type { BaseClient, ApiKey, CreateApiKeyRequest, ApiKeysListResponse } from "../types.js";

export class KeysResource {
  constructor(private client: BaseClient) {}

  list(): Promise<ApiKeysListResponse> {
    return this.client.request("GET", "/keys");
  }

  create(request: CreateApiKeyRequest): Promise<ApiKey> {
    return this.client.request("POST", "/keys", request);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.request("DELETE", `/keys/${id}`);
  }
}
