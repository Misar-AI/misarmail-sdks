import type { BaseClient } from "../types.js";

export type ApiKeyScope =
  | "send"
  | "send:transactional"
  | "send:marketing"
  | "read"
  | "write"
  | "contacts"
  | "analytics"
  | "sandbox"
  | "validate"
  | "ips";

export interface ApiKeyRecord {
  id: string;
  name: string;
  key_prefix: string;
  scopes: string;
  allowed_account_id?: string | null;
  is_active: boolean;
  last_used_at?: string | null;
  created_at: string;
  expires_at?: string | null;
}

export interface CreateApiKeyRequest {
  name: string;
  scopes?: ApiKeyScope[];
  allowedAccountId?: string;
  expiresAt?: string;
}

export interface CreateApiKeyResponse {
  success: true;
  key: string;
  keyId: string;
  prefix: string;
  name: string;
  scopes: string;
  createdAt: string;
  expiresAt?: string | null;
}

export interface ApiKeysListResponse {
  success: true;
  keys: ApiKeyRecord[];
}

export class KeysResource {
  constructor(private client: BaseClient) {}

  /** GET /keys — list all API keys (session auth; never returns raw key) */
  list(): Promise<ApiKeysListResponse> {
    return this.client.request("GET", "/keys");
  }

  /** POST /keys — create a new API key. Raw key returned ONCE — store immediately. */
  create(request: CreateApiKeyRequest): Promise<CreateApiKeyResponse> {
    return this.client.request("POST", "/keys", request);
  }

  /**
   * DELETE /keys?id=<uuid> — revoke an API key.
   * Note: id is passed as a query parameter, not a path segment.
   */
  delete(id: string): Promise<{ success: true }> {
    return this.client.request("DELETE", `/keys?id=${encodeURIComponent(id)}`);
  }
}
