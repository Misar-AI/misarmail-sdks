import type { BaseClient } from "../types.js";

/** One metered feature's current standing against its allowance. */
export interface PlanUsageEntry {
  feature: string;
  used: number;
  /** null = unlimited on this plan. */
  limit: number | null;
  remaining: number | null;
  /** ISO timestamp the counter rolls over, when the feature is periodic. */
  resets_at?: string | null;
}

/**
 * The upgrade offer the API attaches once a feature is exhausted or locked.
 * Null while every allowance still has headroom.
 */
export interface PlanUpgradeOffer {
  feature: string;
  reason: "quota_exhausted" | "feature_locked" | string;
  currentPlanSlug: string;
  currentPlanName: string;
  used?: number;
  limit?: number | null;
  urls?: { pricing?: string };
}

export interface PlanResponse {
  plan: { slug: string; name: string };
  sending: {
    emails_per_day: number | null;
    emails_per_month: number | null;
  };
  /** Per-feature usage against the plan's allowances. */
  usage: PlanUsageEntry[];
  /** Non-null once something is exhausted or locked. */
  upgrade: PlanUpgradeOffer | null;
}

export interface MonetizationStats {
  success: true;
  data: Record<string, unknown>;
}

/**
 * Live subscription standing for the key's owner.
 *
 * Read this before an expensive call rather than discovering the ceiling
 * through a `MisarMailPlanLimitError`. `usage` reports every metered feature,
 * and `upgrade` is non-null as soon as one of them is spent.
 *
 * - `get()`         → GET /v1/plan
 * - `monetization()`→ GET /v1/monetization/stats
 */
export class PlanResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /plan — plan, sending allowances, per-feature usage, upgrade offer. */
  get(): Promise<PlanResponse> {
    return this.client.request("GET", "/plan");
  }

  /** GET /monetization/stats — revenue and monetization counters. */
  monetization(): Promise<MonetizationStats> {
    return this.client.request("GET", "/monetization/stats");
  }
}
