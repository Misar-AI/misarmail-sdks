import type { BaseClient } from '../types.js';

export class SalesAgentResource {
  constructor(private readonly client: BaseClient) {}

  getConfig() {
    return this.client.request('GET', '/sales-agent/config');
  }

  updateConfig(data: Record<string, unknown>) {
    return this.client.request('PATCH', '/sales-agent/config', data);
  }

  getActions(params?: Record<string, unknown>) {
    const qs = params
      ? '?' + new URLSearchParams(params as Record<string, string>).toString()
      : '';
    return this.client.request('GET', `/sales-agent/actions${qs}`);
  }
}
