import type { BaseClient } from "../types.js";

export interface RecordTipRequest {
  amount_cents: number;
  currency?: string;
  email?: string;
  name?: string;
  message?: string;
  stripe_payment_id?: string;
}

export interface RecordTipResponse {
  success: true;
  tip_id: string;
  gross_amount_cents: number;
  platform_fee_cents: number;
  net_amount_cents: number;
  timestamp: string;
}

export class MonetizationResource {
  constructor(private readonly client: BaseClient) {}

  /**
   * POST /monetization/tip — record a tip for the API key owner.
   * Typically called from your payment webhook after a Stripe payment completes.
   * Platform fee (~5%) is deducted automatically and reflected in net_amount_cents.
   */
  recordTip(request: RecordTipRequest): Promise<RecordTipResponse> {
    return this.client.request("POST", "/monetization/tip", request);
  }
}
