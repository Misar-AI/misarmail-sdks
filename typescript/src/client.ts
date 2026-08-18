import {
  MisarMailError,
  MisarMailNetworkError,
  MisarMailPlanLimitError,
} from "./errors.js";
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
import { DedicatedIpsResource } from "./resources/dedicated_ips.js";
import { WebhooksResource } from "./resources/webhooks.js";
import { UsageResource } from "./resources/usage.js";
import { BillingResource } from "./resources/billing.js";
import { ReferralsResource } from "./resources/referrals.js";
import { MarketplaceResource } from "./resources/marketplace.js";
import { SettingsResource } from "./resources/settings.js";
import { LabelsResource } from "./resources/labels.js";
import { DraftsResource } from "./resources/drafts.js";
import { PreferencesResource } from "./resources/preferences.js";
import { DeliverabilityResource } from "./resources/deliverability.js";
import { FormsResource } from "./resources/forms.js";
import { InboxResource } from "./resources/inbox.js";
import { LandingPagesResource } from "./resources/landing_pages.js";
import { NotificationsResource } from "./resources/notifications.js";
import { SegmentsResource } from "./resources/segments.js";
import { IntegrationsResource } from "./resources/integrations.js";
import { MonetizationResource } from "./resources/monetization.js";
import { DmarcResource } from "./resources/dmarc.js";
import {
  WalletResource,
  SubscriptionResource,
  TeamMembersResource,
  CreditRatesResource,
} from "./resources/wallet.js";
import { EmailAccountsResource } from "./resources/email_accounts.js";
import { AiResource } from "./resources/ai.js";
import { PlanResource } from "./resources/plan.js";
import { StreamingResource } from "./resources/streaming.js";
import {
  EmailsResource,
  RevenueResource,
  WarmupResource,
} from "./resources/mailbox.js";

const RETRYABLE = new Set([429, 500, 502, 503, 504]);

/** True when an error body carries the API's plan-refusal marker. */
function isPlanLimit(data: Record<string, unknown>): boolean {
  return (
    data.code === "plan_limit_exceeded" ||
    data.error_type === "plan_limit_exceeded" ||
    (typeof data.upgrade === "object" && data.upgrade !== null)
  );
}

/** Read a nested string without following the prototype chain. */
function pick(obj: unknown, ...path: string[]): string | undefined {
  let cur: unknown = obj;
  for (const key of path) {
    if (typeof cur !== "object" || cur === null) return undefined;
    if (!Object.prototype.hasOwnProperty.call(cur, key)) return undefined;
    cur = (cur as Record<string, unknown>)[key];
  }
  return typeof cur === "string" ? cur : undefined;
}

function planLimitError(
  res: Response,
  data: Record<string, unknown>,
): MisarMailPlanLimitError {
  // Headers are authoritative; the offer body is the fallback when a proxy has
  // stripped them.
  const plan =
    res.headers.get("x-misar-plan") ??
    pick(data.upgrade, "current_plan", "slug") ??
    pick(data.upgrade, "currentPlanSlug");
  const upgradeUrl =
    res.headers.get("x-misar-upgrade-url") ?? pick(data.upgrade, "urls", "pricing");
  const retryHeader = res.headers.get("retry-after");

  return new MisarMailPlanLimitError(
    res.status,
    String(data.error ?? data.message ?? "plan limit exceeded"),
    plan ?? undefined,
    upgradeUrl ?? undefined,
    retryHeader && /^\d+$/.test(retryHeader) ? Number(retryHeader) : undefined,
    pick(data.upgrade, "feature"),
    data,
  );
}

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
  readonly dedicatedIps: DedicatedIpsResource;
  readonly webhooks: WebhooksResource;
  readonly usage: UsageResource;
  readonly billing: BillingResource;
  readonly plan: PlanResource;
  readonly streaming: StreamingResource;
  readonly emails: EmailsResource;
  readonly revenue: RevenueResource;
  readonly warmup: WarmupResource;
  readonly referrals: ReferralsResource;
  readonly marketplace: MarketplaceResource;
  readonly settings: SettingsResource;
  readonly labels: LabelsResource;
  readonly drafts: DraftsResource;
  readonly preferences: PreferencesResource;
  readonly deliverability: DeliverabilityResource;
  readonly forms: FormsResource;
  readonly inbox: InboxResource;
  readonly landingPages: LandingPagesResource;
  readonly notifications: NotificationsResource;
  readonly segments: SegmentsResource;
  readonly integrations: IntegrationsResource;
  readonly monetization: MonetizationResource;
  readonly dmarc: DmarcResource;
  readonly wallet: WalletResource;
  readonly subscription: SubscriptionResource;
  readonly teamMembers: TeamMembersResource;
  readonly creditRates: CreditRatesResource;
  readonly emailAccounts: EmailAccountsResource;
  readonly ai: AiResource;

  constructor(apiKey: string, options: MisarMailClientOptions = {}) {
    this.apiKey = apiKey;
    this.baseURL = options.baseURL ?? "https://api.misar.io/mail/v1";
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
    this.dedicatedIps = new DedicatedIpsResource(this);
    this.webhooks = new WebhooksResource(this);
    this.usage = new UsageResource(this);
    this.billing = new BillingResource(this);
    this.plan = new PlanResource(this);
    this.streaming = new StreamingResource(this);
    this.emails = new EmailsResource(this);
    this.revenue = new RevenueResource(this);
    this.warmup = new WarmupResource(this);
    this.referrals = new ReferralsResource(this);
    this.marketplace = new MarketplaceResource(this);
    this.settings = new SettingsResource(this);
    this.labels = new LabelsResource(this);
    this.drafts = new DraftsResource(this);
    this.preferences = new PreferencesResource(this);
    this.deliverability = new DeliverabilityResource(this);
    this.forms = new FormsResource(this);
    this.inbox = new InboxResource(this);
    this.landingPages = new LandingPagesResource(this);
    this.notifications = new NotificationsResource(this);
    this.segments = new SegmentsResource(this);
    this.integrations = new IntegrationsResource(this);
    this.monetization = new MonetizationResource(this);
    this.dmarc = new DmarcResource(this);
    this.wallet = new WalletResource(this);
    this.subscription = new SubscriptionResource(this);
    this.teamMembers = new TeamMembersResource(this);
    this.creditRates = new CreditRatesResource(this);
    this.emailAccounts = new EmailAccountsResource(this);
    this.ai = new AiResource(this);
  }

  async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    return this.fetch<T>(`${this.baseURL}${path}`, method, body);
  }

  /**
   * Request a route that lives OUTSIDE the versioned `/v1` namespace.
   *
   * Several MisarMail API groups (automations, domains, forms, inbox,
   * marketplace, integrations, segments, settings, deliverability, etc.) are
   * served at `api.misar.io/mail/<group>` — NOT under `/mail/v1/<group>`.
   * Calling them through `request()` would prepend `/v1` and 404. This helper
   * strips the trailing `/v1` from baseURL so those routes resolve, mirroring
   * the pattern already used by the billing resources.
   */
  async requestRoot<T>(method: string, path: string, body?: unknown): Promise<T> {
    const rootBase = this.baseURL.replace(/\/v1\/?$/, "");
    return this.fetch<T>(`${rootBase}${path}`, method, body);
  }

  /**
   * Open an SSE connection to a route outside `/v1`.
   *
   * Deliberately not retried: a stream that fails mid-flight cannot be replayed
   * without duplicating whatever the caller already consumed. Connection
   * failures surface to the caller, which can decide whether to restart.
   */
  async openStream(method: string, path: string, body?: unknown): Promise<Response> {
    const rootBase = this.baseURL.replace(/\/v1\/?$/, "");
    return fetch(`${rootBase}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        Accept: "text/event-stream",
        "Content-Type": "application/json",
      },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    });
  }

  private async fetch<T>(url: string, method: string, body?: unknown): Promise<T> {
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
          // The body has to be read before deciding whether to retry: a 429
          // from the rate limiter and a 429 from a spent plan allowance look
          // identical by status, and only the second is pointless to retry.
          const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;

          if (isPlanLimit(data)) {
            throw planLimitError(res, data);
          }

          if (RETRYABLE.has(res.status) && attempt < this.maxRetries - 1) {
            await sleep(200 * 2 ** attempt);
            attempt++;
            continue;
          }

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
