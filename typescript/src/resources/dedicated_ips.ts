import type { BaseClient } from '../types.js';

export interface DedicatedIp {
  id: string;
  ip_address: string;
  hostname?: string | null;
  ptr_record?: string | null;
  status: "provisioning" | "active" | "suspended" | "deprovisioning";
  warmup_enabled: boolean;
  warmup_start_date?: string | null;
  warmup_day: number;
  warmup_target_volume?: number | null;
  daily_volume: number;
  reputation_score?: number | null;
  last_used_at?: string | null;
  monthly_price_cents: number;
  billing_active: boolean;
  created_at: string;
  updated_at: string;
  dedicated_ip_pools?: { id: string; pool_name: string } | null;
}

export interface RequestDedicatedIpRequest {
  pool_id: string;
  hostname?: string;
}

export interface UpdateDedicatedIpRequest {
  warmup_enabled?: boolean;
  pool_id?: string;
}

export interface DedicatedIpDetail extends DedicatedIp {
  warmup_schedule_entry?: { day_number: number; max_volume: number; description: string } | null;
  reputation_history: Array<{
    date: string;
    emails_sent: number;
    bounces: number;
    complaints: number;
    reputation_score: number;
    blacklisted: boolean;
    blacklist_names: string[];
  }>;
}

export class DedicatedIpsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /dedicated-ips — list all dedicated IPs for the account */
  list(): Promise<{ success: true; data: DedicatedIp[] }> {
    return this.client.request('GET', '/dedicated-ips');
  }

  /** GET /dedicated-ips/:id — get a single dedicated IP with warmup + reputation detail */
  get(id: string): Promise<{ success: true; data: DedicatedIpDetail }> {
    return this.client.request('GET', `/dedicated-ips/${id}`);
  }

  /** POST /dedicated-ips — request a new dedicated IP (provisioning takes 1-2 business days) */
  create(data: RequestDedicatedIpRequest): Promise<{ success: true; data: DedicatedIp; message: string }> {
    return this.client.request('POST', '/dedicated-ips', data);
  }

  /** PATCH /dedicated-ips/:id — update warmup_enabled or pool_id */
  update(id: string, data: UpdateDedicatedIpRequest): Promise<{ success: true; data: DedicatedIp }> {
    return this.client.request('PATCH', `/dedicated-ips/${id}`, data);
  }

  // NOTE: DELETE /dedicated-ips/:id does not exist. Contact support to deprovision IPs.
}
