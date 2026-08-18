import type { BaseClient } from "../types.js";

export interface TrackEventRequest {
  email: string;
  event_name: string;
  event_data?: Record<string, unknown>;
  source?: string;
  campaign_id?: string;
  page_url?: string;
  referrer?: string;
}

export interface TrackEventResponse {
  success: true;
  event_id: string | null;
}

export interface PurchaseItem {
  name: string;
  quantity: number;
  price_cents: number;
}

export interface TrackPurchaseRequest {
  email: string;
  order_id: string;
  total_cents: number;
  currency?: string;
  items?: PurchaseItem[];
  attribution_window_hours?: number;
}

export interface TrackPurchaseResponse {
  success: true;
  purchase_id: string | null;
  attribution: {
    source: string;
    campaign_id: string | null;
    automation_id: string | null;
    click_timestamp: string | null;
  };
}

export class TrackResource {
  constructor(private client: BaseClient) {}

  /** POST /track/event — record a custom tracking event for a contact */
  event(request: TrackEventRequest): Promise<TrackEventResponse> {
    return this.client.request("POST", "/track/event", request);
  }

  /** POST /track/purchase — record a purchase and attribute it to email campaigns */
  purchase(request: TrackPurchaseRequest): Promise<TrackPurchaseResponse> {
    return this.client.request("POST", "/track/purchase", request);
  }
}
