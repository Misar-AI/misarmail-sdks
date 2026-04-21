import type { BaseClient } from '../types.js';

export class AutomationsResource {
  constructor(private readonly client: BaseClient) {}

  list(params?: Record<string, unknown>) {
    const qs = params
      ? '?' + new URLSearchParams(params as Record<string, string>).toString()
      : '';
    return this.client.request('GET', `/automations${qs}`);
  }

  create(data: Record<string, unknown>) {
    return this.client.request('POST', '/automations', data);
  }

  get(id: string) {
    return this.client.request('GET', `/automations/${id}`);
  }

  update(id: string, data: Record<string, unknown>) {
    return this.client.request('PATCH', `/automations/${id}`, data);
  }

  delete(id: string) {
    return this.client.request('DELETE', `/automations/${id}`);
  }

  activate(id: string, active: boolean) {
    return this.client.request('POST', `/automations/${id}/activate`, { active });
  }
}
