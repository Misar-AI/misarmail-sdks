import type { BaseClient } from "../types.js";

export type AbTestType = "content" | "subject" | "send_time" | "from_name" | "preheader";
export type AbTestWinnerMetric = "opens" | "clicks" | "revenue" | "conversions";

export interface CreateAbTestRequest {
  campaign_id: string;
  variant: string;
  test_type?: AbTestType;
  subject?: string;
  preheader?: string;
  body_html?: string;
  from_name?: string;
  send_percent?: number;
  send_time_a?: string;
  send_time_b?: string;
  auto_select_winner?: boolean;
  winner_wait_hours?: number;
}

export interface AbTest {
  id: string;
  campaign_id: string;
  variant: string;
  test_type: AbTestType;
  subject?: string | null;
  preheader?: string | null;
  from_name?: string | null;
  send_percent: number;
  emails_sent: number;
  opens: number;
  clicks: number;
  unsubscribes: number;
  bounces: number;
  complaints: number;
  revenue: number;
  auto_select_winner: boolean;
  winner_wait_hours: number;
  winner_selected_at?: string | null;
  send_time_a?: string | null;
  send_time_b?: string | null;
  created_at: string;
  source: "campaign";
}

export interface AbTestsListParams {
  page?: number;
  limit?: number;
  type?: "campaign" | "subject";
}

export interface AbTestsListResponse {
  success: true;
  data: AbTest[];
  pagination: { page: number; limit: number; total: number; totalPages: number };
}

export interface SelectWinnerRequest {
  winner_variant: string;
  metric?: AbTestWinnerMetric;
}

export interface SelectWinnerResponse {
  success: true;
  data: {
    ab_test_id: string;
    campaign_id: string;
    winner_variant: string;
    metric: AbTestWinnerMetric;
    winner_selected_at: string;
    applied_to_campaign: {
      subject?: string | null;
      body_html?: string | null;
      from_name?: string | null;
    };
  };
}

export class AbTestsResource {
  constructor(private client: BaseClient) {}

  list(params?: AbTestsListParams): Promise<AbTestsListResponse> {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/ab-tests${qs}`);
  }

  create(request: CreateAbTestRequest): Promise<{ success: true; data: AbTest }> {
    return this.client.request("POST", "/ab-tests", request);
  }

  /**
   * Select the winning variant for a campaign A/B test.
   * @param id - The campaign_ab_tests.id (not the campaign id)
   */
  selectWinner(id: string, request: SelectWinnerRequest): Promise<SelectWinnerResponse> {
    return this.client.request("POST", `/ab-tests/${id}/winner`, request);
  }

  /** @deprecated Use selectWinner() */
  setWinner(id: string, winner_variant: string, metric?: AbTestWinnerMetric): Promise<SelectWinnerResponse> {
    return this.selectWinner(id, { winner_variant, metric });
  }
}
