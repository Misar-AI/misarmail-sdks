import type { BaseClient } from '../types.js';

// ── Types ────────────────────────────────────────────────────────────────────

export type Domain = {
  id: string;
  domain: string;
  status: 'pending' | 'verified' | 'failed';
  dns_records: DnsRecord[];
  created_at: string;
  updated_at: string;
};

export type DnsRecord = {
  type: string;
  host: string;
  value: string;
  verified: boolean;
};

export type DomainsListParams = {
  page?: number;
  limit?: number;
};

export type DomainsListResponse = {
  success: boolean;
  data: Domain[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type AddDomainResponse = {
  success: boolean;
  data: Domain;
};

export type VerifyDomainResponse = {
  success: boolean;
  verified: boolean;
  data: Domain;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class DomainsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /domains — list sending domains */
  listDomains(params?: DomainsListParams): Promise<DomainsListResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : '';
    return this.client.requestRoot('GET', `/domains${qs}`);
  }

  /** POST /domains — add a new sending domain */
  addDomain(domain: string): Promise<AddDomainResponse> {
    return this.client.requestRoot('POST', '/domains', { domain });
  }

  /** POST /domains/{domainId}/verify — trigger DNS verification */
  verifyDomain(domainId: string): Promise<VerifyDomainResponse> {
    return this.client.requestRoot('POST', `/domains/${domainId}/verify`);
  }

  // ── Legacy aliases (kept for backwards compatibility) ────────────────────

  /** @deprecated Use listDomains() */
  list(params?: DomainsListParams): Promise<DomainsListResponse> {
    return this.listDomains(params);
  }

  /** @deprecated Use addDomain() */
  create(data: { domain: string } & Record<string, unknown>): Promise<AddDomainResponse> {
    return this.client.requestRoot('POST', '/domains', data);
  }

  get(id: string): Promise<{ success: boolean; data: Domain }> {
    return this.client.requestRoot('GET', `/domains/${id}`);
  }

  /** @deprecated Use verifyDomain() */
  verify(id: string): Promise<VerifyDomainResponse> {
    return this.verifyDomain(id);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.requestRoot('DELETE', `/domains/${id}`);
  }
}
