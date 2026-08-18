import type { BaseClient } from '../types.js';

export class WebhooksResource {
  constructor(private readonly client: BaseClient) {}

  list() {
    return this.client.requestRoot('GET', '/webhooks');
  }

  create(data: Record<string, unknown>) {
    return this.client.requestRoot('POST', '/webhooks', data);
  }

  get(id: string) {
    return this.client.requestRoot('GET', `/webhooks/${id}`);
  }

  update(id: string, data: Record<string, unknown>) {
    return this.client.requestRoot('PATCH', `/webhooks/${id}`, data);
  }

  delete(id: string) {
    return this.client.requestRoot('DELETE', `/webhooks/${id}`);
  }

  test(id: string) {
    return this.client.requestRoot('POST', `/webhooks/${id}/test`);
  }
}
