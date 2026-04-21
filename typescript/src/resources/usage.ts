import type { BaseClient } from '../types.js';

export class UsageResource {
  constructor(private readonly client: BaseClient) {}

  get(params?: Record<string, unknown>) {
    const qs = params
      ? '?' + new URLSearchParams(params as Record<string, string>).toString()
      : '';
    return this.client.request('GET', `/usage${qs}`);
  }
}
