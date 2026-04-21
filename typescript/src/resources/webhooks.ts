import type { BaseClient } from '../types.js';

export class WebhooksResource {
  constructor(private readonly client: BaseClient) {}

  list() {
    return this.client.request('GET', '/webhooks');
  }

  create(data: Record<string, unknown>) {
    return this.client.request('POST', '/webhooks', data);
  }

  get(id: string) {
    return this.client.request('GET', `/webhooks/${id}`);
  }

  update(id: string, data: Record<string, unknown>) {
    return this.client.request('PATCH', `/webhooks/${id}`, data);
  }

  delete(id: string) {
    return this.client.request('DELETE', `/webhooks/${id}`);
  }

  test(id: string) {
    return this.client.request('POST', `/webhooks/${id}/test`);
  }
}
