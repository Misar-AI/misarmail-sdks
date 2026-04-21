import type { BaseClient } from '../types.js';

export class AliasesResource {
  constructor(private readonly client: BaseClient) {}

  list() {
    return this.client.request('GET', '/aliases');
  }

  create(data: Record<string, unknown>) {
    return this.client.request('POST', '/aliases', data);
  }

  get(id: string) {
    return this.client.request('GET', `/aliases/${id}`);
  }

  update(id: string, data: Record<string, unknown>) {
    return this.client.request('PATCH', `/aliases/${id}`, data);
  }

  delete(id: string) {
    return this.client.request('DELETE', `/aliases/${id}`);
  }
}
