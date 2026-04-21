export interface EmailAddress {
  email: string;
  name?: string;
}

export interface PaginationParams {
  page?: number;
  limit?: number;
}

// ── Email ────────────────────────────────────────────────────────────────────

export interface SendEmailRequest {
  from: EmailAddress;
  to: EmailAddress[];
  cc?: EmailAddress[];
  bcc?: EmailAddress[];
  reply_to?: EmailAddress;
  subject: string;
  html?: string;
  text?: string;
  alias_id?: string;
  idempotency_key?: string;
  tags?: string[];
  metadata?: Record<string, string>;
}

export interface SendEmailResponse {
  success: true;
  message_id: string;
  provider?: string;
  timestamp?: string;
  idempotent?: boolean;
}

// ── Contacts ─────────────────────────────────────────────────────────────────

export interface Contact {
  id: string;
  email: string;
  first_name?: string;
  last_name?: string;
  status: "active" | "unsubscribed" | "bounced" | "complained";
  tags?: string[];
  metadata?: Record<string, string>;
  created_at: string;
  updated_at: string;
}

export interface CreateContactRequest {
  email: string;
  first_name?: string;
  last_name?: string;
  tags?: string[];
  metadata?: Record<string, string>;
}

export interface ContactsListResponse {
  data: Contact[];
  total: number;
  page: number;
  limit: number;
}

export interface ContactImportRequest {
  contacts: CreateContactRequest[];
  update_existing?: boolean;
}

export interface ContactImportResponse {
  imported: number;
  updated: number;
  skipped: number;
  errors: number;
}

// ── Campaigns ────────────────────────────────────────────────────────────────

export interface CampaignStats {
  sent: number;
  delivered: number;
  opens: number;
  clicks: number;
  bounces: number;
  unsubscribes: number;
  complaints: number;
  open_rate: number;
  click_rate: number;
}

export interface Campaign {
  id: string;
  name: string;
  subject: string;
  status: "draft" | "scheduled" | "sending" | "sent" | "paused" | "cancelled";
  from: EmailAddress;
  html?: string;
  text?: string;
  segment_id?: string;
  scheduled_at?: string;
  sent_at?: string;
  stats?: CampaignStats;
  created_at: string;
  updated_at: string;
}

export interface CreateCampaignRequest {
  name: string;
  subject: string;
  from: EmailAddress;
  html?: string;
  text?: string;
  segment_id?: string;
  scheduled_at?: string;
}

export interface CampaignsListResponse {
  data: Campaign[];
  total: number;
  page: number;
  limit: number;
}

// ── Templates ────────────────────────────────────────────────────────────────

export interface Template {
  id: string;
  name: string;
  subject: string;
  html: string;
  text?: string;
  variables?: string[];
  created_at: string;
  updated_at: string;
}

export interface CreateTemplateRequest {
  name: string;
  subject: string;
  html: string;
  text?: string;
}

export interface TemplatesListResponse {
  data: Template[];
  total: number;
}

export interface RenderTemplateRequest {
  template_id: string;
  variables?: Record<string, string>;
}

export interface RenderTemplateResponse {
  html: string;
  text?: string;
  subject: string;
}

// ── API Keys ─────────────────────────────────────────────────────────────────

export interface ApiKey {
  id: string;
  name: string;
  key?: string;
  scopes: string[];
  last_used_at?: string;
  created_at: string;
}

export interface CreateApiKeyRequest {
  name: string;
  scopes: string[];
}

export interface ApiKeysListResponse {
  data: ApiKey[];
}

// ── Validate ─────────────────────────────────────────────────────────────────

export interface ValidateEmailRequest {
  email: string;
}

export interface ValidateEmailResponse {
  valid: boolean;
  disposable?: boolean;
  format_valid?: boolean;
  mx_found?: boolean;
  suggestion?: string;
}

// ── Analytics ────────────────────────────────────────────────────────────────

export interface AnalyticsQuery {
  start_date?: string;
  end_date?: string;
  campaign_id?: string;
  group_by?: "day" | "week" | "month";
}

export interface AnalyticsResponse {
  sent: number;
  delivered: number;
  opens: number;
  clicks: number;
  bounces: number;
  unsubscribes: number;
  complaints: number;
  open_rate: number;
  click_rate: number;
  series?: Array<{ date: string; sent: number; opens: number; clicks: number }>;
}

// ── A/B Tests ────────────────────────────────────────────────────────────────

export interface AbTestVariant {
  id: string;
  name: string;
  subject: string;
  html?: string;
  text?: string;
  stats?: CampaignStats;
}

export interface AbTest {
  id: string;
  name: string;
  status: "draft" | "running" | "completed";
  variants: AbTestVariant[];
  winner_id?: string;
  created_at: string;
}

export interface CreateAbTestRequest {
  name: string;
  variants: Array<{ name: string; subject: string; html?: string; text?: string }>;
  segment_id?: string;
  test_percentage?: number;
  winning_metric?: "open_rate" | "click_rate";
  duration_hours?: number;
}

export interface AbTestsListResponse {
  data: AbTest[];
  total: number;
}

// ── Sandbox ──────────────────────────────────────────────────────────────────

export interface SandboxSend {
  id: string;
  message_id: string;
  from: EmailAddress;
  to: EmailAddress[];
  subject: string;
  html?: string;
  created_at: string;
}

export interface SandboxListResponse {
  data: SandboxSend[];
  total: number;
}

// ── Track ────────────────────────────────────────────────────────────────────

export interface TrackEventRequest {
  email: string;
  event: string;
  properties?: Record<string, unknown>;
  timestamp?: string;
}

export interface TrackPurchaseRequest {
  email: string;
  order_id: string;
  amount: number;
  currency?: string;
  items?: Array<{ id: string; name: string; quantity: number; price: number }>;
  timestamp?: string;
}

export interface TrackResponse {
  success: boolean;
}

// ── Inbound ──────────────────────────────────────────────────────────────────

export interface InboundEmail {
  id: string;
  from: EmailAddress;
  to: EmailAddress[];
  subject: string;
  html?: string;
  text?: string;
  received_at: string;
}

export interface InboundListResponse {
  data: InboundEmail[];
  total: number;
}

// ── Client ───────────────────────────────────────────────────────────────────

export interface MisarMailClientOptions {
  baseURL?: string;
  maxRetries?: number;
  timeoutMs?: number;
}

export interface BaseClient {
  request<T>(method: string, path: string, body?: unknown): Promise<T>;
}
