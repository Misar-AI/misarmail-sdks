import type { BaseClient } from '../types.js';

export class DedicatedIpsResource {
  constructor(private readonly client: BaseClient) {}

  list() {
    return this.client.request('GET', '/dedicated-ips');
  }

  create(data: Record<string, unknown>) {
    return this.client.request('POST', '/dedicated-ips', data);
  }

  update(id: string, data: Record<string, unknown>) {
    return this.client.request('PATCH', `/dedicated-ips/${id}`, data);
  }

  delete(id: string) {
    return this.client.request('DELETE', `/dedicated-ips/${id}`);
  }
}
