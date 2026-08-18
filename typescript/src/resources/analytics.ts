import type { BaseClient } from "../types.js";

export interface AnalyticsQuery {
  startDate?: string;
  endDate?: string;
  campaignId?: string;
  groupBy?: "day" | "week" | "month";
}

export interface CampaignAnalyticsResponse {
  success: true;
  data: {
    campaign: {
      id: string;
      name: string;
      subject: string;
      status: string;
      from_email: string;
      total_recipients: number;
      total_sent: number;
      total_delivered: number;
      total_opened: number;
      total_clicked: number;
      total_bounced: number;
      total_complained: number;
      total_unsubscribed: number;
      scheduled_at?: string | null;
      created_at: string;
      updated_at: string;
    };
    rates: {
      openRate: number;
      clickRate: number;
      bounceRate: number;
      complaintRate: number;
      unsubscribeRate: number;
    };
  };
}

export interface AggregateAnalyticsResponse {
  success: true;
  data: {
    period: { start: string; end: string };
    emailUsage: Array<{ date: string; emails_sent_today: number; emails_sent_month: number }>;
    campaignTotals: {
      sent: number;
      opened: number;
      clicked: number;
      bounced: number;
      complained: number;
    };
    rates: { openRate: number; clickRate: number; bounceRate: number };
    warning?: string;
  };
}

export class AnalyticsResource {
  constructor(private client: BaseClient) {}

  /**
   * GET /analytics — get analytics.
   * - Without campaignId: returns aggregate email usage for the period (default last 30 days).
   * - With campaignId: returns per-campaign stats and rates.
   */
  get(query?: AnalyticsQuery): Promise<CampaignAnalyticsResponse | AggregateAnalyticsResponse> {
    const qs = query ? `?${new URLSearchParams(query as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/analytics${qs}`);
  }
}
