import type { BaseClient } from '../types.js';

export class AutopilotResource {
  constructor(private readonly client: BaseClient) {}

  start(data: Record<string, unknown>) {
    return this.client.request('POST', '/autopilot', data);
  }

  get(id: string) {
    return this.client.request('GET', `/autopilot/${id}`);
  }

  list(params?: Record<string, unknown>) {
    const qs = params
      ? '?' + new URLSearchParams(params as Record<string, string>).toString()
      : '';
    return this.client.request('GET', `/autopilot${qs}`);
  }

  dailyPlan() {
    return this.client.request('GET', '/autopilot/daily-plan');
  }
}
