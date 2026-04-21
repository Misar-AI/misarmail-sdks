import type { BaseClient } from '../types.js';

export class WorkspacesResource {
  constructor(private readonly client: BaseClient) {}

  private getBaseInfo() {
    const { baseURL, apiKey } = this.client as unknown as {
      baseURL: string;
      apiKey: string;
    };
    const wsBase = baseURL.replace(/\/v1\/?$/, '');
    return { wsBase, apiKey };
  }

  private async req(method: string, path: string, data?: unknown): Promise<unknown> {
    const { wsBase, apiKey } = this.getBaseInfo();
    const res = await fetch(`${wsBase}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: data !== undefined ? JSON.stringify(data) : undefined,
    });
    if (!res.ok) throw new Error(`Workspaces ${method} ${path} failed: ${res.status}`);
    return res.json();
  }

  list() {
    return this.req('GET', '/workspaces');
  }

  create(data: Record<string, unknown>) {
    return this.req('POST', '/workspaces', data);
  }

  get(id: string) {
    return this.req('GET', `/workspaces/${id}`);
  }

  update(id: string, data: Record<string, unknown>) {
    return this.req('PATCH', `/workspaces/${id}`, data);
  }

  delete(id: string) {
    return this.req('DELETE', `/workspaces/${id}`);
  }

  listMembers(wsId: string) {
    return this.req('GET', `/workspaces/${wsId}/members`);
  }

  inviteMember(wsId: string, data: Record<string, unknown>) {
    return this.req('POST', `/workspaces/${wsId}/members`, data);
  }

  updateMember(wsId: string, userId: string, data: Record<string, unknown>) {
    return this.req('PATCH', `/workspaces/${wsId}/members/${userId}`, data);
  }

  removeMember(wsId: string, userId: string) {
    return this.req('DELETE', `/workspaces/${wsId}/members/${userId}`);
  }
}
