import type {
  BaseClient,
  PaginationParams,
  Campaign,
  CampaignStats,
  CreateCampaignRequest,
  CampaignsListResponse,
} from "../types.js";

export class CampaignsResource {
  constructor(private client: BaseClient) {}

  list(params?: PaginationParams): Promise<CampaignsListResponse> {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/campaigns${qs}`);
  }

  create(request: CreateCampaignRequest): Promise<Campaign> {
    return this.client.request("POST", "/campaigns", request);
  }

  get(id: string): Promise<Campaign> {
    return this.client.request("GET", `/campaigns/${id}`);
  }

  update(id: string, request: Partial<CreateCampaignRequest>): Promise<Campaign> {
    return this.client.request("PATCH", `/campaigns/${id}`, request);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.request("DELETE", `/campaigns/${id}`);
  }

  send(id: string): Promise<{ success: boolean; sent_at: string }> {
    return this.client.request("POST", `/campaigns/${id}/send`);
  }

  schedule(id: string, scheduled_at: string): Promise<Campaign> {
    return this.client.request("POST", `/campaigns/${id}/schedule`, { scheduled_at });
  }

  pause(id: string): Promise<Campaign> {
    return this.client.request("POST", `/campaigns/${id}/pause`);
  }

  resume(id: string): Promise<Campaign> {
    return this.client.request("POST", `/campaigns/${id}/resume`);
  }

  stats(id: string): Promise<CampaignStats> {
    return this.client.request("GET", `/campaigns/${id}/stats`);
  }
}
