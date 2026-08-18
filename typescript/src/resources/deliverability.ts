import type { BaseClient } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type DeliverabilityAuditResult = {
  success: boolean;
  data: {
    domain: string;
    spf: {
      valid: boolean;
      record: string | null;
    };
    dkim: {
      valid: boolean;
    };
    dmarc: {
      valid: boolean;
      policy: string | null;
      record: string | null;
    };
    score: number;
    recommendations: string[];
  };
};

export type DailyHistoryPoint = {
  date: string;
  score: number;
  bounceRate: number;
  openRate: number;
};

export type DeliverabilityHistoryResponse = {
  success: boolean;
  data: DailyHistoryPoint[];
};

export type DeliverabilityPlaybook = {
  id: string;
  title: string;
  description: string;
  priority: "high" | "medium" | "low";
  steps: string[];
};

export type DeliverabilityPlaybooksResponse = {
  success: boolean;
  data: DeliverabilityPlaybook[];
};

export type DeliverabilityScoreResponse = {
  success: boolean;
  data: {
    score: number;
    grade: string;
    breakdown: Record<string, number>;
    recommendations: string[];
    computed_at: string;
  };
};

export type SendTimeWindow = {
  hour: number;
  timezone: string;
  estimated_contacts: number;
  score: number;
};

export type SendTimeResponse = {
  success: boolean;
  data: {
    campaign_id: string;
    windows: SendTimeWindow[];
  };
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class DeliverabilityResource {
  constructor(private readonly client: BaseClient) {}

  /** Run a live DNS deliverability audit for a domain. */
  audit(domain: string): Promise<DeliverabilityAuditResult> {
    return this.client.requestRoot("POST", "/deliverability/audit", { domain });
  }

  /** Fetch the last 30 days of daily deliverability score history. */
  history(): Promise<DeliverabilityHistoryResponse> {
    return this.client.requestRoot("GET", "/deliverability/history");
  }

  /** Fetch actionable deliverability playbooks. */
  playbooks(): Promise<DeliverabilityPlaybooksResponse> {
    return this.client.requestRoot("GET", "/deliverability/playbooks");
  }

  /** Get the current deliverability score and recommendations. */
  score(): Promise<DeliverabilityScoreResponse> {
    return this.client.requestRoot("GET", "/deliverability/score");
  }

  /**
   * Preview send-time optimization windows for a campaign.
   * Only meaningful when the campaign has optimize_send_time enabled.
   */
  sendTime(campaignId: string): Promise<SendTimeResponse> {
    return this.client.requestRoot(
      "GET",
      `/deliverability/send-time?campaignId=${encodeURIComponent(campaignId)}`,
    );
  }
}
