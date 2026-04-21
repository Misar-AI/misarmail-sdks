import type { BaseClient } from '../types.js';

export class BillingResource {
  constructor(private readonly client: BaseClient) {}

  private getBaseInfo() {
    const { baseURL, apiKey } = this.client as unknown as {
      baseURL: string;
      apiKey: string;
    };
    const billingBase = baseURL.replace(/\/v1\/?$/, '');
    return { billingBase, apiKey };
  }

  async subscription(): Promise<unknown> {
    const { billingBase, apiKey } = this.getBaseInfo();
    const res = await fetch(`${billingBase}/billing/subscription`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
    });
    if (!res.ok) throw new Error(`Billing subscription request failed: ${res.status}`);
    return res.json();
  }

  async checkout(data: Record<string, unknown>): Promise<unknown> {
    const { billingBase, apiKey } = this.getBaseInfo();
    const res = await fetch(`${billingBase}/billing/checkout`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error(`Billing checkout request failed: ${res.status}`);
    return res.json();
  }
}
