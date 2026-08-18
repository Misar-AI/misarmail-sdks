import type { BaseClient } from "../types.js";

export interface MonitoredDomain {
  id: string;
  domain: string;
  spf_valid: boolean;
  dkim_selector: string;
  dkim_valid: boolean;
  dmarc_valid: boolean;
  dmarc_policy?: string | null;
  mx_records?: string[] | null;
  overall_score: number;
  last_checked_at?: string | null;
  billing_active: boolean;
  status: "active" | "inactive" | "suspended";
  created_at: string;
}

export interface DnsCheckResult {
  spf: { valid: boolean; value: string | null; issues: string[] };
  dkim: { valid: boolean; value: string | null; issues: string[] };
  dmarc: { valid: boolean; value: string | null; policy: string | null; issues: string[] };
  mx: string[];
  overallScore: number;
}

export interface AddDmarcDomainRequest {
  domain: string;
  dkim_selector?: string;
}

export interface AddDmarcDomainResponse {
  success: true;
  data: MonitoredDomain & { dns_check: DnsCheckResult };
}

export class DmarcResource {
  constructor(private readonly client: BaseClient) {}

  /**
   * GET /dmarc/domains — list all monitored domains and their current DNS health.
   */
  listDomains(): Promise<{ success: true; data: MonitoredDomain[] }> {
    return this.client.request("GET", "/dmarc/domains");
  }

  /**
   * GET /dmarc/check — run a live DNS check for a domain without storing it.
   *
   * @param domain       The domain to inspect.
   * @param dkimSelector DKIM selector to probe; the API picks a default when omitted.
   */
  check(domain: string, dkimSelector?: string): Promise<Record<string, unknown>> {
    const qs = new URLSearchParams({ domain });
    if (dkimSelector) qs.set("dkim_selector", dkimSelector);
    return this.client.request("GET", `/dmarc/check?${qs}`);
  }

  /**
   * POST /dmarc/domains — add a domain to DMARC monitoring.
   * Performs an immediate DNS check (SPF, DKIM, DMARC, MX) and stores the result.
   */
  addDomain(request: AddDmarcDomainRequest): Promise<AddDmarcDomainResponse> {
    return this.client.request("POST", "/dmarc/domains", request);
  }

  /**
   * DELETE /dmarc/domains?domain_id=<uuid> — remove a domain from monitoring.
   */
  removeDomain(domainId: string): Promise<{ success: true }> {
    return this.client.request("DELETE", `/dmarc/domains?domain_id=${encodeURIComponent(domainId)}`);
  }
}
