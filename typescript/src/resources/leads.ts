import type { BaseClient } from '../types.js';

export class LeadsResource {
  constructor(private readonly client: BaseClient) {}

  search(data: Record<string, unknown>) {
    return this.client.request('POST', '/leads/search', data);
  }

  getJob(id: string) {
    return this.client.request('GET', `/leads/jobs/${id}`);
  }

  listJobs(params?: Record<string, unknown>) {
    const qs = params
      ? '?' + new URLSearchParams(params as Record<string, string>).toString()
      : '';
    return this.client.request('GET', `/leads/jobs${qs}`);
  }

  results(jobId: string) {
    return this.client.request('GET', `/leads/results/${jobId}`);
  }

  importLeads(data: Record<string, unknown>) {
    return this.client.request('POST', '/leads/import', data);
  }

  credits() {
    return this.client.request('GET', '/leads/credits');
  }
}
