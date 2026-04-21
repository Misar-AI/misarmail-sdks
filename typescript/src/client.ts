import { MisarMailError, MisarMailNetworkError } from "./errors.js";
import type { BaseClient, MisarMailClientOptions } from "./types.js";
import { EmailResource } from "./resources/email.js";
import { ContactsResource } from "./resources/contacts.js";
import { CampaignsResource } from "./resources/campaigns.js";
import { TemplatesResource } from "./resources/templates.js";
import { KeysResource } from "./resources/keys.js";
import { AnalyticsResource } from "./resources/analytics.js";
import { ValidateResource } from "./resources/validate.js";
import { AbTestsResource } from "./resources/ab_tests.js";
import { SandboxResource } from "./resources/sandbox.js";
import { TrackResource } from "./resources/track.js";
import { InboundResource } from "./resources/inbound.js";
import { AutomationsResource } from "./resources/automations.js";
import { DomainsResource } from "./resources/domains.js";
import { AliasesResource } from "./resources/aliases.js";
import { DedicatedIpsResource } from "./resources/dedicated_ips.js";
import { ChannelsResource } from "./resources/channels.js";
import { LeadsResource } from "./resources/leads.js";
import { AutopilotResource } from "./resources/autopilot.js";
import { SalesAgentResource } from "./resources/sales_agent.js";
import { CrmResource } from "./resources/crm.js";
import { WebhooksResource } from "./resources/webhooks.js";
import { UsageResource } from "./resources/usage.js";
import { BillingResource } from "./resources/billing.js";
import { WorkspacesResource } from "./resources/workspaces.js";

const RETRYABLE = new Set([429, 500, 502, 503, 504]);

export class MisarMailClient implements BaseClient {
  private readonly apiKey: string;
  readonly baseURL: string;
  private readonly maxRetries: number;
  private readonly timeoutMs: number;

  readonly email: EmailResource;
  readonly contacts: ContactsResource;
  readonly campaigns: CampaignsResource;
  readonly templates: TemplatesResource;
  readonly keys: KeysResource;
  readonly analytics: AnalyticsResource;
  readonly validate: ValidateResource;
  readonly abTests: AbTestsResource;
  readonly sandbox: SandboxResource;
  readonly track: TrackResource;
  readonly inbound: InboundResource;
  readonly automations: AutomationsResource;
  readonly domains: DomainsResource;
  readonly aliases: AliasesResource;
  readonly dedicatedIps: DedicatedIpsResource;
  readonly channels: ChannelsResource;
  readonly leads: LeadsResource;
  readonly autopilot: AutopilotResource;
  readonly salesAgent: SalesAgentResource;
  readonly crm: CrmResource;
  readonly webhooks: WebhooksResource;
  readonly usage: UsageResource;
  readonly billing: BillingResource;
  readonly workspaces: WorkspacesResource;

  constructor(apiKey: string, options: MisarMailClientOptions = {}) {
    this.apiKey = apiKey;
    this.baseURL = options.baseURL ?? "https://mail.misar.io/api/v1";
    this.maxRetries = options.maxRetries ?? 3;
    this.timeoutMs = options.timeoutMs ?? 30_000;

    this.email = new EmailResource(this);
    this.contacts = new ContactsResource(this);
    this.campaigns = new CampaignsResource(this);
    this.templates = new TemplatesResource(this);
    this.keys = new KeysResource(this);
    this.analytics = new AnalyticsResource(this);
    this.validate = new ValidateResource(this);
    this.abTests = new AbTestsResource(this);
    this.sandbox = new SandboxResource(this);
    this.track = new TrackResource(this);
    this.inbound = new InboundResource(this);
    this.automations = new AutomationsResource(this);
    this.domains = new DomainsResource(this);
    this.aliases = new AliasesResource(this);
    this.dedicatedIps = new DedicatedIpsResource(this);
    this.channels = new ChannelsResource(this);
    this.leads = new LeadsResource(this);
    this.autopilot = new AutopilotResource(this);
    this.salesAgent = new SalesAgentResource(this);
    this.crm = new CrmResource(this);
    this.webhooks = new WebhooksResource(this);
    this.usage = new UsageResource(this);
    this.billing = new BillingResource(this);
    this.workspaces = new WorkspacesResource(this);
  }

  async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    const url = `${this.baseURL}${path}`;
    const headers: Record<string, string> = {
      Authorization: `Bearer ${this.apiKey}`,
      "Content-Type": "application/json",
    };

    let attempt = 0;
    while (true) {
      try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), this.timeoutMs);

        let res: Response;
        try {
          res = await fetch(url, {
            method,
            headers,
            body: body !== undefined ? JSON.stringify(body) : undefined,
            signal: controller.signal,
          });
        } finally {
          clearTimeout(timer);
        }

        if (!res.ok) {
          if (RETRYABLE.has(res.status) && attempt < this.maxRetries - 1) {
            await sleep(200 * 2 ** attempt);
            attempt++;
            continue;
          }
          const data = await res.json().catch(() => ({})) as Record<string, unknown>;
          throw new MisarMailError(
            res.status,
            String(data.error ?? data.message ?? res.statusText),
            String(data.error_type ?? "api_error"),
            data,
          );
        }

        return res.json() as Promise<T>;
      } catch (err) {
        if (err instanceof MisarMailError) throw err;
        if (attempt < this.maxRetries - 1) {
          await sleep(200 * 2 ** attempt);
          attempt++;
          continue;
        }
        throw new MisarMailNetworkError(
          err instanceof Error ? err.message : "Network error",
          err,
        );
      }
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
