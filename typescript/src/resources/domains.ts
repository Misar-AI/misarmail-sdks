import type { BaseClient } from '../types.js';

export class DomainsResource {
  constructor(private readonly client: BaseClient) {}

  list() {
    return this.client.request('GET', '/domains');
  }

  create(data: Record<string, unknown>) {
    return this.client.request('POST', '/domains', data);
  }

  get(id: string) {
    return this.client.request('GET', `/domains/${id}`);
  }

  verify(id: string) {
    return this.client.request('POST', `/domains/${id}/verify`);
  }

  delete(id: string) {
    return this.client.request('DELETE', `/domains/${id}`);
  }
}
