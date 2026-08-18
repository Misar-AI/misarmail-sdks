import type { BaseClient, PaginationParams } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

// Signatures

export type EmailSignature = {
  id: string;
  name: string;
  html: string;
  is_default: boolean;
  created_at: string;
};

export type CreateSignatureRequest = {
  name: string;
  html: string;
  is_default?: boolean;
};

export type UpdateSignatureRequest = {
  id: string;
  name?: string;
  html?: string;
  is_default?: boolean;
};

// SMTP Pools

export type SmtpPoolName = "transactional" | "marketing" | "cold";

export type SmtpPoolConfig = {
  id: string;
  pool_name: SmtpPoolName;
  smtp_host: string;
  smtp_port: number;
  smtp_user: string;
  from_domain: string;
  display_name: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
};

export type UpsertSmtpPoolRequest = {
  pool_name: SmtpPoolName;
  smtp_host: string;
  smtp_port?: number;
  smtp_user: string;
  smtp_pass: string;
  from_domain: string;
  display_name?: string;
  is_active?: boolean;
};

// Dedicated IPs

export type DedicatedIp = {
  id: string;
  ip_address: string;
  hostname: string | null;
  ptr_record: string | null;
  status: string;
  warmup_enabled: boolean;
  warmup_start_date: string | null;
  warmup_day: number | null;
  warmup_target_volume: number | null;
  daily_volume: number;
  reputation_score: number | null;
  last_used_at: string | null;
  monthly_price_cents: number;
  billing_active: boolean;
  created_at: string;
  updated_at: string;
  pool: { id: string; pool_name: string } | null;
};

// DMARC Domains

export type MonitoredDomain = {
  id: string;
  domain: string;
  spf_valid: boolean;
  dkim_selector: string;
  dkim_valid: boolean;
  dmarc_valid: boolean;
  dmarc_policy: string | null;
  mx_records: string[];
  overall_score: number;
  last_checked_at: string | null;
  billing_active: boolean;
  status: string;
  created_at: string;
};

export type AddDmarcDomainRequest = {
  domain: string;
  dkim_selector?: string;
};

// IP Pools

export type IpPool = {
  id: string;
  pool_name: string;
  smtp_host: string;
  smtp_port: number;
  smtp_user: string;
  is_active: boolean;
  daily_limit: number;
  sent_today: number;
  created_at: string;
};

export type CreateIpPoolRequest = {
  pool_name: string;
  smtp_host: string;
  smtp_port?: number;
  smtp_user: string;
  smtp_pass: string;
  daily_limit?: number;
};

// Unsubscribe Page

export type UnsubscribePageConfig = {
  id: string;
  brand_name: string | null;
  brand_color: string | null;
  unsubscribe_headline: string | null;
  unsubscribe_message: string | null;
  unsubscribe_redirect_url: string | null;
};

export type UpdateUnsubscribePageRequest = {
  unsubscribe_headline?: string | null;
  unsubscribe_message?: string | null;
  unsubscribe_redirect_url?: string | null;
};

// Whitelabel

export type WhitelabelConfig = {
  id: string;
  brand_name: string | null;
  brand_logo_url: string | null;
  brand_color: string | null;
  custom_domain: string | null;
  from_name_override: string | null;
  created_at: string;
};

export type UpdateWhitelabelRequest = {
  brand_name?: string | null;
  brand_color?: string | null;
  from_name_override?: string | null;
};

// Audit Logs

export type AuditLog = {
  id: string;
  user_id: string;
  team_id: string | null;
  actor_email: string | null;
  action: string;
  action_label: string;
  resource_type: string | null;
  resource_id: string | null;
  resource_name: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
};

export type AuditLogsParams = PaginationParams & {
  action?: string;
  from?: string;
  to?: string;
  format?: "json" | "csv";
};

export type AuditLogsResponse = {
  success: boolean;
  data: AuditLog[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
  actionLabels: Record<string, string>;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class SettingsResource {
  constructor(private readonly client: BaseClient) {}

  // ── Signatures ─────────────────────────────────────────────────────────────

  /** GET /settings/signatures — list user's email signatures */
  listSignatures(): Promise<{ success: boolean; data: EmailSignature[] }> {
    return this.client.requestRoot("GET", "/settings/signatures");
  }

  /** POST /settings/signatures — create a new signature */
  createSignature(
    request: CreateSignatureRequest,
  ): Promise<{ success: boolean; data: EmailSignature }> {
    return this.client.requestRoot("POST", "/settings/signatures", request);
  }

  /** PUT /settings/signatures — update a signature (id in body) */
  updateSignature(
    request: UpdateSignatureRequest,
  ): Promise<{ success: boolean; data: EmailSignature }> {
    return this.client.requestRoot("PUT", "/settings/signatures", request);
  }

  /** DELETE /settings/signatures?id=<uuid> — delete a signature */
  deleteSignature(id: string): Promise<{ success: boolean }> {
    return this.client.requestRoot("DELETE", `/settings/signatures?id=${id}`);
  }

  // ── SMTP Pools ─────────────────────────────────────────────────────────────

  /** GET /settings/smtp-pools — list user's SMTP pool configs (password redacted) */
  listSmtpPools(): Promise<{ success: boolean; data: SmtpPoolConfig[] }> {
    return this.client.requestRoot("GET", "/settings/smtp-pools");
  }

  /** POST /settings/smtp-pools — upsert a SMTP pool config */
  upsertSmtpPool(request: UpsertSmtpPoolRequest): Promise<{ success: boolean; data: SmtpPoolConfig }> {
    return this.client.requestRoot("POST", "/settings/smtp-pools", request);
  }

  /** DELETE /settings/smtp-pools?id=<uuid> — remove a SMTP pool config */
  deleteSmtpPool(id: string): Promise<{ success: boolean }> {
    return this.client.requestRoot("DELETE", `/settings/smtp-pools?id=${id}`);
  }

  // ── Dedicated IPs ──────────────────────────────────────────────────────────

  /** GET /settings/dedicated-ips — list user's dedicated IPs */
  listDedicatedIps(): Promise<{ success: boolean; data: DedicatedIp[] }> {
    return this.client.requestRoot("GET", "/settings/dedicated-ips");
  }

  /** POST /settings/dedicated-ips — request a new dedicated IP (returns Stripe checkout URL) */
  requestDedicatedIp(): Promise<{ success: boolean; url?: string; data?: DedicatedIp }> {
    return this.client.requestRoot("POST", "/settings/dedicated-ips");
  }

  // ── DMARC Domains ──────────────────────────────────────────────────────────

  /** GET /settings/dmarc/domains — list monitored domains */
  listDmarcDomains(): Promise<{ success: boolean; data: MonitoredDomain[] }> {
    return this.client.requestRoot("GET", "/settings/dmarc/domains");
  }

  /** POST /settings/dmarc/domains — add and immediately check a new domain */
  addDmarcDomain(
    request: AddDmarcDomainRequest,
  ): Promise<{ success: boolean; data: MonitoredDomain }> {
    return this.client.requestRoot("POST", "/settings/dmarc/domains", request);
  }

  /** DELETE /settings/dmarc/domains?domain_id=<uuid> — remove a monitored domain */
  deleteDmarcDomain(domainId: string): Promise<{ success: boolean }> {
    return this.client.requestRoot("DELETE", `/settings/dmarc/domains?domain_id=${domainId}`);
  }

  // ── IP Pools ───────────────────────────────────────────────────────────────

  /** GET /settings/ip-pools — list user's dedicated IP pools */
  listIpPools(): Promise<{ success: boolean; data: IpPool[] }> {
    return this.client.requestRoot("GET", "/settings/ip-pools");
  }

  /** POST /settings/ip-pools — create a new dedicated IP pool */
  createIpPool(request: CreateIpPoolRequest): Promise<{ success: boolean; data: IpPool }> {
    return this.client.requestRoot("POST", "/settings/ip-pools", request);
  }

  /** DELETE /settings/ip-pools?id=<uuid> — remove an IP pool */
  deleteIpPool(id: string): Promise<{ success: boolean }> {
    return this.client.requestRoot("DELETE", `/settings/ip-pools?id=${id}`);
  }

  // ── Unsubscribe Page ───────────────────────────────────────────────────────

  /** GET /settings/unsubscribe-page — get unsubscribe page customization */
  getUnsubscribePage(): Promise<{ success: boolean; data: UnsubscribePageConfig | null }> {
    return this.client.requestRoot("GET", "/settings/unsubscribe-page");
  }

  /** POST /settings/unsubscribe-page — upsert unsubscribe page settings */
  updateUnsubscribePage(
    request: UpdateUnsubscribePageRequest,
  ): Promise<{ success: boolean; data: UnsubscribePageConfig }> {
    return this.client.requestRoot("POST", "/settings/unsubscribe-page", request);
  }

  // ── Whitelabel ─────────────────────────────────────────────────────────────

  /** GET /settings/whitelabel — get white-label config */
  getWhitelabel(): Promise<{ success: boolean; data: WhitelabelConfig | null }> {
    return this.client.requestRoot("GET", "/settings/whitelabel");
  }

  /** POST /settings/whitelabel — upsert white-label config */
  updateWhitelabel(
    request: UpdateWhitelabelRequest,
  ): Promise<{ success: boolean; data: WhitelabelConfig }> {
    return this.client.requestRoot("POST", "/settings/whitelabel", request);
  }

  // ── Audit Logs ─────────────────────────────────────────────────────────────

  /** GET /settings/audit — get paginated audit logs */
  auditLogs(params?: AuditLogsParams): Promise<AuditLogsResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.requestRoot("GET", `/settings/audit${qs}`);
  }
}
