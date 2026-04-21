import type { BaseClient, TrackEventRequest, TrackPurchaseRequest, TrackResponse } from "../types.js";

export class TrackResource {
  constructor(private client: BaseClient) {}

  event(request: TrackEventRequest): Promise<TrackResponse> {
    return this.client.request("POST", "/track/event", request);
  }

  purchase(request: TrackPurchaseRequest): Promise<TrackResponse> {
    return this.client.request("POST", "/track/purchase", request);
  }
}
