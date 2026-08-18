import type { BaseClient, PaginationParams } from "../types.js";

export type CampaignStatus = "draft" | "scheduled" | "sending" | "sent" | "paused" | "cancelled";

export interface Campaign {
  id: string;
  name: string;
  subject: string;
  status: CampaignStatus;
  from_email: string;
  from_name: string;
  segment_id?: string | null;
  scheduled_at?: string | null;
  started_at?: string | null;
  completed_at?: string | null;
  total_recipients?: number;
  total_sent?: number;
  total_delivered?: number;
  total_opened?: number;
  total_clicked?: number;
  total_bounced?: number;
  total_complained?: number;
  created_at: string;
  updated_at: string;
}

export interface CreateCampaignRequest {
  name: string;
  subject: string;
  fromName: string;
  fromEmail: string;
  replyTo?: string;
  bodyHtml?: string;
  bodyText?: string;
  templateId?: string;
  segmentId?: string;
  scheduledAt?: string;
  description?: string;
}

export interface UpdateCampaignRequest {
  name?: string;
  subject?: string;
  fromName?: string;
  replyTo?: string;
  bodyHtml?: string;
  bodyText?: string;
  segmentId?: string;
  scheduledAt?: string | null;
  status?: "draft" | "scheduled" | "paused" | "cancelled";
  description?: string;
}

export interface CampaignsListParams extends PaginationParams {
  status?: CampaignStatus;
}

export interface CampaignsListResponse {
  success: true;
  data: Campaign[];
  pagination: { page: number; limit: number; total: number; totalPages: number };
}

export interface SendCampaignResponse {
  success: true;
  message: string;
  campaignId: string;
  status: "scheduled";
}

export class CampaignsResource {
  constructor(private client: BaseClient) {}

  /** GET /campaigns — list campaigns with optional status filter */
  list(params?: CampaignsListParams): Promise<CampaignsListResponse> {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/campaigns${qs}`);
  }

  /** POST /campaigns — create a new campaign */
  create(request: CreateCampaignRequest): Promise<{ success: true; data: Campaign }> {
    return this.client.request("POST", "/campaigns", request);
  }

  /** GET /campaigns/:id — get a single campaign */
  get(id: string): Promise<{ success: true; data: Campaign }> {
    return this.client.request("GET", `/campaigns/${id}`);
  }

  /**
   * PATCH /campaigns/:id — update a draft/scheduled/paused campaign.
   * Only draft, scheduled, or paused campaigns can be modified.
   */
  update(id: string, request: UpdateCampaignRequest): Promise<{ success: true; data: Campaign }> {
    return this.client.request("PATCH", `/campaigns/${id}`, request);
  }

  /**
   * DELETE /campaigns/:id — delete a campaign.
   * Only campaigns with status "draft" can be deleted.
   */
  delete(id: string): Promise<{ success: true }> {
    return this.client.request("DELETE", `/campaigns/${id}`);
  }

  /**
   * POST /campaigns/:id/send — trigger immediate send of a draft or scheduled campaign.
   * Kicks off the campaign worker asynchronously.
   */
  send(id: string): Promise<SendCampaignResponse> {
    return this.client.request("POST", `/campaigns/${id}/send`);
  }
}
