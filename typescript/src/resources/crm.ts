import type { BaseClient } from '../types.js';

export class CrmResource {
  constructor(private readonly client: BaseClient) {}

  listConversations(params?: Record<string, unknown>) {
    const qs = params
      ? '?' + new URLSearchParams(params as Record<string, string>).toString()
      : '';
    return this.client.request('GET', `/crm/conversations${qs}`);
  }

  getConversation(id: string) {
    return this.client.request('GET', `/crm/conversations/${id}`);
  }

  updateConversation(id: string, data: Record<string, unknown>) {
    return this.client.request('PATCH', `/crm/conversations/${id}`, data);
  }

  listMessages(conversationId: string) {
    return this.client.request('GET', `/crm/conversations/${conversationId}/messages`);
  }

  listDeals(params?: Record<string, unknown>) {
    const qs = params
      ? '?' + new URLSearchParams(params as Record<string, string>).toString()
      : '';
    return this.client.request('GET', `/crm/deals${qs}`);
  }

  createDeal(data: Record<string, unknown>) {
    return this.client.request('POST', '/crm/deals', data);
  }

  getDeal(id: string) {
    return this.client.request('GET', `/crm/deals/${id}`);
  }

  updateDeal(id: string, data: Record<string, unknown>) {
    return this.client.request('PATCH', `/crm/deals/${id}`, data);
  }

  deleteDeal(id: string) {
    return this.client.request('DELETE', `/crm/deals/${id}`);
  }

  listClients(params?: Record<string, unknown>) {
    const qs = params
      ? '?' + new URLSearchParams(params as Record<string, string>).toString()
      : '';
    return this.client.request('GET', `/crm/clients${qs}`);
  }

  createClient(data: Record<string, unknown>) {
    return this.client.request('POST', '/crm/clients', data);
  }
}
