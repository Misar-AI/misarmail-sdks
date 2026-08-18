import type { BaseClient } from "../types.js";

export interface WalletBalance {
  success: true;
  /** Current balance in credits (1 credit = $1 USD). */
  balance: number;
  /** Current balance in cents (= balance * 100). Mirrors MisarReach's column. */
  balance_cents: number;
  currency: string;
}

export interface WalletMutationRequest {
  /** Positive integer number of credits. */
  amount: number;
  /** Human-readable reason, stored on the wallet transaction. */
  reason: string;
  /** Unique key for safe retries. Replays are no-ops. */
  idempotency_key: string;
}

export interface WalletMutationResponse {
  success: true;
  balance: number;
  currency: string;
  /** True when the idempotency_key was already processed (no-op replay). */
  idempotent: boolean;
}

/**
 * Single shared credit wallet, owned by MisarMail.
 *
 * - `get()`    → GET  /v1/wallet
 * - `debit()`  → POST /v1/wallet/debit   (scope: wallet)
 * - `credit()` → POST /v1/wallet/credit  (scope: wallet | wallet:refund)
 */
export class WalletResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /wallet — current balance for the API key's user. */
  get(): Promise<WalletBalance> {
    return this.client.request("GET", "/wallet");
  }

  /** POST /wallet/debit — server-authoritative, idempotent debit. */
  debit(request: WalletMutationRequest): Promise<WalletMutationResponse> {
    return this.client.request("POST", "/wallet/debit", request);
  }

  /** POST /wallet/credit — server-authoritative, idempotent refund/credit. */
  credit(request: WalletMutationRequest): Promise<WalletMutationResponse> {
    return this.client.request("POST", "/wallet/credit", request);
  }
}

export interface SubscriptionResponse {
  success: true;
  data: {
    plan_slug: string;
    plan_name: string;
    price_monthly: number;
    price_yearly: number | null;
    status: string;
    daily_limit: number | null;
    monthly_limit: number | null;
    renewal_date: string | null;
    cancel_at_period_end: boolean;
  };
}

/**
 * INTERNAL product-to-product subscription write.
 *
 * MisarMail owns ALL subscriptions across every Misar product, so other
 * products record their subscriptions here. Requires the elevated
 * `subscription:write` scope — a normal end-user key cannot call it.
 */
export interface SubscriptionUpsertRequest {
  /** The end-user the subscription belongs to. */
  user_id: string;
  /** Product the subscription belongs to (e.g. "mail", "reach"). */
  product: string;
  /** Plan slug for the product. Provide this or `plan_id`. */
  plan_slug?: string;
  /** Opaque plan id; resolved to a slug server-side. Provide this or `plan_slug`. */
  plan_id?: string;
  status?:
    | "active"
    | "trialing"
    | "past_due"
    | "canceled"
    | "incomplete"
    | "unpaid"
    | "paused";
  stripe_customer_id?: string | null;
  stripe_subscription_id?: string | null;
  current_period_start?: string | null;
  current_period_end?: string | null;
  /** Accepted for forward-compat. */
  cancel_at_period_end?: boolean;
  trial_started_at?: string;
  trial_end_at?: string;
}

export interface SubscriptionWriteResponse {
  success: true;
  data: {
    user_id: string;
    product: string;
    plan_slug: string;
    status: string;
  };
}

export interface SubscriptionCancelRequest {
  user_id: string;
  product: string;
}

/**
 * Read the API key user's MisarMail subscription plan + status, and (with the
 * elevated `subscription:write` scope) write subscriptions for any product.
 *
 * - `get()`        → GET    /v1/subscription
 * - `planLimits()` → GET    /v1/plan-limits
 * - `upsert()`     → POST   /v1/subscription   (scope: subscription:write)
 * - `cancel()`     → DELETE /v1/subscription   (scope: subscription:write)
 */
export class SubscriptionResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /subscription — the user's Mail plan and status. */
  get(): Promise<SubscriptionResponse> {
    return this.client.request("GET", "/subscription");
  }

  /** GET /plan-limits — the user's full Mail plan limits + current usage. */
  planLimits(): Promise<PlanLimitsResponse> {
    return this.client.request("GET", "/plan-limits");
  }

  /**
   * POST /subscription — server-authoritative, idempotent upsert of a
   * subscription for any product. Requires the `subscription:write` scope.
   */
  upsert(request: SubscriptionUpsertRequest): Promise<SubscriptionWriteResponse> {
    return this.client.request("POST", "/subscription", request);
  }

  /**
   * DELETE /subscription — cancel/downgrade a product subscription to its free
   * plan. Idempotent. Requires the `subscription:write` scope.
   */
  cancel(request: SubscriptionCancelRequest): Promise<SubscriptionWriteResponse> {
    return this.client.request("DELETE", "/subscription", request);
  }
}

export interface PlanLimitUsage {
  /** Current count for a count-based feature. null = unknown. */
  current: number | null;
  /** Max allowed. null = unlimited. */
  max: number | null;
}

export interface PlanLimitsResponse {
  success: true;
  data: {
    plan_slug: string;
    plan_name: string;
    status: string;
    renewal_date: string | null;
    cancel_at_period_end: boolean;
    /** Curated plan limits (mirrors the app's getPlanLimits shape). */
    limits: {
      emails_per_day: number | null;
      emails_per_month: number | null;
      max_contacts: number | null;
      max_campaigns: number | null;
      max_templates: number | null;
      max_automations: number | null;
      max_custom_domains: number | null;
      max_api_keys: number | null;
      max_email_aliases: number | null;
      max_email_accounts: number | null;
      storage_limit_bytes: number | null;
      bulk_import_enabled: boolean;
      ai_features_enabled: boolean;
      custom_smtp_enabled: boolean;
      plan_slug: string;
      plan_name: string;
    };
    /** Every max_* column from subscription_plans (null = unlimited). */
    max_limits: Record<string, number | null>;
    /** Boolean feature flags. */
    features: Record<string, boolean>;
    /** Current usage per count-based feature. */
    usage: Record<string, PlanLimitUsage>;
  };
}

/**
 * Read the API key user's team-member owner expansion.
 *
 * - `get(ownerId?)` → GET /v1/team-members
 */
export class TeamMembersResource {
  constructor(private readonly client: BaseClient) {}

  /**
   * GET /team-members — owner user_ids the user has team access to.
   * Pass `ownerId` to resolve for a specific user (default: the key's user).
   */
  get(ownerId?: string): Promise<TeamMembersResponse> {
    const path = ownerId ? `/team-members?owner_id=${encodeURIComponent(ownerId)}` : "/team-members";
    return this.client.request("GET", path);
  }
}

export interface TeamMembersResponse {
  success: true;
  data: {
    user_id: string;
    /** The user itself + every active teammate's user_id. */
    owner_ids: string[];
  };
}

export interface CreditRate {
  feature: string;
  label: string;
  credits: number;
  unit: string;
}

export interface CreditRatesResponse {
  success: true;
  data: CreditRate[];
}

/**
 * Read the wallet credit-rate pricing config (`credit_rates`).
 *
 * - `list()` → GET /v1/credit-rates
 */
export class CreditRatesResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /credit-rates — active credit-rate pricing config. */
  list(): Promise<CreditRatesResponse> {
    return this.client.request("GET", "/credit-rates");
  }
}
