import type { BaseClient, AnalyticsQuery, AnalyticsResponse } from "../types.js";

export class AnalyticsResource {
  constructor(private client: BaseClient) {}

  get(query?: AnalyticsQuery): Promise<AnalyticsResponse> {
    const qs = query ? `?${new URLSearchParams(query as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/analytics${qs}`);
  }
}
