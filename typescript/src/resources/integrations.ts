import type { BaseClient, PaginationParams } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type IntegrationStatus = "connected" | "disconnected" | "error";

export type Integration = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  icon_url: string | null;
  status: IntegrationStatus;
  enabled: boolean;
  config: Record<string, unknown> | null;
  connected_at: string | null;
  created_at: string;
  updated_at: string;
};

export type IntegrationsListParams = Pick<PaginationParams, "page" | "limit">;

export type IntegrationsListResponse = {
  success: boolean;
  data: Integration[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type ToggleIntegrationResponse = {
  success: boolean;
  data: Integration;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class IntegrationsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /integrations — list available integrations and their connection status */
  listIntegrations(params?: IntegrationsListParams): Promise<IntegrationsListResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.requestRoot("GET", `/integrations${qs}`);
  }

  /** GET /integrations/{integrationId} — get a single integration detail */
  getIntegration(integrationId: string): Promise<{ success: boolean; data: Integration }> {
    return this.client.requestRoot("GET", `/integrations/${integrationId}`);
  }

  /** PATCH /integrations/{integrationId}/toggle — enable or disable an integration */
  toggleIntegration(
    integrationId: string,
    enabled: boolean,
  ): Promise<ToggleIntegrationResponse> {
    return this.client.requestRoot("PATCH", `/integrations/${integrationId}/toggle`, { enabled });
  }
}
