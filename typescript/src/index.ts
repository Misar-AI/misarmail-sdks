export { MisarMailClient } from "./client.js";
export { MisarMailError, MisarMailNetworkError } from "./errors.js";

// Resource classes
export { EmailResource } from "./resources/email.js";
export { ContactsResource } from "./resources/contacts.js";
export { CampaignsResource } from "./resources/campaigns.js";
export { TemplatesResource } from "./resources/templates.js";
export { KeysResource } from "./resources/keys.js";
export { AnalyticsResource } from "./resources/analytics.js";
export { ValidateResource } from "./resources/validate.js";
export { AbTestsResource } from "./resources/ab_tests.js";
export { SandboxResource } from "./resources/sandbox.js";
export { TrackResource } from "./resources/track.js";
export { InboundResource } from "./resources/inbound.js";
export { AutomationsResource } from "./resources/automations.js";
export { DomainsResource } from "./resources/domains.js";
export { AliasesResource } from "./resources/aliases.js";
export { DedicatedIpsResource } from "./resources/dedicated_ips.js";
export { ChannelsResource } from "./resources/channels.js";
export { LeadsResource } from "./resources/leads.js";
export { AutopilotResource } from "./resources/autopilot.js";
export { SalesAgentResource } from "./resources/sales_agent.js";
export { CrmResource } from "./resources/crm.js";
export { WebhooksResource } from "./resources/webhooks.js";
export { UsageResource } from "./resources/usage.js";
export { BillingResource } from "./resources/billing.js";
export { WorkspacesResource } from "./resources/workspaces.js";

export type {
  MisarMailClientOptions,
  BaseClient,
  EmailAddress,
  PaginationParams,
  SendEmailRequest,
  SendEmailResponse,
  Contact,
  CreateContactRequest,
  ContactsListResponse,
  ContactImportRequest,
  ContactImportResponse,
  Campaign,
  CampaignStats,
  CreateCampaignRequest,
  CampaignsListResponse,
  Template,
  CreateTemplateRequest,
  TemplatesListResponse,
  RenderTemplateRequest,
  RenderTemplateResponse,
  ApiKey,
  CreateApiKeyRequest,
  ApiKeysListResponse,
  ValidateEmailRequest,
  ValidateEmailResponse,
  AnalyticsQuery,
  AnalyticsResponse,
  AbTest,
  AbTestVariant,
  CreateAbTestRequest,
  AbTestsListResponse,
  SandboxSend,
  SandboxListResponse,
  TrackEventRequest,
  TrackPurchaseRequest,
  TrackResponse,
  InboundEmail,
  InboundListResponse,
} from "./types.js";
