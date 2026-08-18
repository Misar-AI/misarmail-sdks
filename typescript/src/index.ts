/**
 * `aliases` and `workspaces` are intentionally absent.
 *
 * Both are served only at /api/aliases and /api/workspaces, and both
 * authenticate with a Supabase cookie session — they import supabase/server and
 * call auth.getUser(), with no dual-auth path and no verifyApiKey. An msk_ key
 * can never call them, so an SDK method would fail unconditionally. (workspaces
 * has no /[id] route at all, only /settings and /members.)
 *
 * If those routes gain key auth, restore them from git history rather than
 * rewriting: the resource files were correct apart from being unreachable.
 */
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
export { DedicatedIpsResource } from "./resources/dedicated_ips.js";
export { WebhooksResource } from "./resources/webhooks.js";
export { UsageResource } from "./resources/usage.js";
export { BillingResource } from "./resources/billing.js";
export { ReferralsResource } from "./resources/referrals.js";
export { MarketplaceResource } from "./resources/marketplace.js";
export { SettingsResource } from "./resources/settings.js";
export { LabelsResource } from "./resources/labels.js";
export { DraftsResource } from "./resources/drafts.js";
export { PreferencesResource } from "./resources/preferences.js";
export { DeliverabilityResource } from "./resources/deliverability.js";
export { FormsResource } from "./resources/forms.js";
export { InboxResource } from "./resources/inbox.js";
export { LandingPagesResource } from "./resources/landing_pages.js";
export { NotificationsResource } from "./resources/notifications.js";
export { SegmentsResource } from "./resources/segments.js";
export { IntegrationsResource } from "./resources/integrations.js";
export { MonetizationResource } from "./resources/monetization.js";
export { DmarcResource } from "./resources/dmarc.js";
export {
  WalletResource,
  SubscriptionResource,
  TeamMembersResource,
  CreditRatesResource,
} from "./resources/wallet.js";
export { EmailAccountsResource } from "./resources/email_accounts.js";
export { AiResource } from "./resources/ai.js";

// Base types
export type { MisarMailClientOptions, BaseClient, EmailAddress, PaginationParams } from "./types.js";

// wallet + subscription
export type {
  WalletBalance,
  WalletMutationRequest,
  WalletMutationResponse,
  SubscriptionResponse,
  PlanLimitUsage,
  PlanLimitsResponse,
  TeamMembersResponse,
  CreditRate,
  CreditRatesResponse,
} from "./resources/wallet.js";

// email accounts
export type {
  EmailAccount,
  EmailAccountsListResponse,
} from "./resources/email_accounts.js";

// ai
export type {
  SubjectLineTone,
  GenerateSubjectLinesRequest,
  SubjectSuggestion,
  GenerateSubjectLinesResponse,
} from "./resources/ai.js";

// segments
export type {
  Segment,
  SegmentFilterCriteria,
  SegmentsListResponse,
  CreateSegmentRequest,
  UpdateSegmentRequest,
  SegmentPreviewRequest,
  SegmentPreviewResponse,
  SegmentRefreshResponse,
  SegmentMembersParams,
} from "./resources/segments.js";

// ab_tests
export type {
  AbTestType,
  AbTestWinnerMetric,
  AbTest,
  CreateAbTestRequest,
  AbTestsListParams,
  AbTestsListResponse,
  SelectWinnerRequest,
  SelectWinnerResponse,
} from "./resources/ab_tests.js";

// analytics
export type {
  AnalyticsQuery,
  CampaignAnalyticsResponse,
  AggregateAnalyticsResponse,
} from "./resources/analytics.js";

// campaigns
export type {
  CampaignStatus,
  Campaign,
  CreateCampaignRequest,
  UpdateCampaignRequest,
  CampaignsListParams,
  CampaignsListResponse,
  SendCampaignResponse,
} from "./resources/campaigns.js";

// contacts
export type {
  ContactStatus,
  Contact,
  CreateContactRequest,
  ContactsListParams,
  ContactsListResponse,
  ContactImportRow,
  ContactImportRequest,
  ContactImportResponse,
} from "./resources/contacts.js";

// dedicated_ips
export type {
  DedicatedIp,
  RequestDedicatedIpRequest,
  UpdateDedicatedIpRequest,
  DedicatedIpDetail,
} from "./resources/dedicated_ips.js";

// dmarc
export type {
  MonitoredDomain,
  DnsCheckResult,
  AddDmarcDomainRequest,
  AddDmarcDomainResponse,
} from "./resources/dmarc.js";

// inbound
export type {
  InboundDomain,
  InboundDomainCreated,
  CreateInboundDomainRequest,
  CreateInboundDomainResponse,
} from "./resources/inbound.js";

// keys
export type {
  ApiKeyScope,
  ApiKeyRecord,
  CreateApiKeyRequest,
  CreateApiKeyResponse,
  ApiKeysListResponse,
} from "./resources/keys.js";

// monetization
export type {
  RecordTipRequest,
  RecordTipResponse,
} from "./resources/monetization.js";

// sandbox
export type {
  SandboxSendRecord,
  SandboxListResponse,
} from "./resources/sandbox.js";

// templates
export type {
  TemplateType,
  Template,
  CreateTemplateRequest,
  TemplatesListParams,
  TemplatesListResponse,
  RenderTemplateRequest,
  RenderTemplateResponse,
} from "./resources/templates.js";

// track
export type {
  TrackEventRequest,
  TrackEventResponse,
  PurchaseItem,
  TrackPurchaseRequest,
  TrackPurchaseResponse,
} from "./resources/track.js";

// validate
export type {
  EmailVerificationOptions,
  SingleValidateRequest,
  BatchValidateRequest,
  EmailVerificationResult,
  SingleValidateResponse,
  BatchValidateResponse,
  WalletBalanceResponse,
} from "./resources/validate.js";

// Other resource types (unchanged resources)
export type {
  ReferralSource,
  ReferralStats,
  GenerateReferralResponse,
  LeaderboardEntry,
  LeaderboardResponse,
  ReferralMilestone,
  MilestonesResponse,
  MilestoneClaim,
  MilestoneClaimsResponse,
  ClaimMilestoneRequest,
  ClaimMilestoneResponse,
  NudgeStats,
  NudgeResponse,
} from "./resources/referrals.js";

export type {
  MarketplaceCategory,
  MarketplaceSortOrder,
  MarketplaceTemplate,
  MarketplaceTemplateDetail,
  MarketplaceListParams,
  MarketplaceListResponse,
  SubmitListingRequest,
  TemplateSubmission,
  SubmitCommunityTemplateRequest,
  SubmissionsListResponse,
  MarketplaceReview,
  SubmitReviewRequest,
  PurchaseResponse,
  DownloadResponse,
  PremiumPurchaseRequest,
  PremiumPurchase,
  PremiumListResponse,
  MyListing,
} from "./resources/marketplace.js";

export type {
  Domain,
  DnsRecord,
  DomainsListParams,
  DomainsListResponse,
  AddDomainResponse,
  VerifyDomainResponse,
} from "./resources/domains.js";

export type { FormsListParams } from "./resources/forms.js";

export type {
  IntegrationStatus,
  Integration,
  IntegrationsListParams,
  IntegrationsListResponse,
  ToggleIntegrationResponse,
} from "./resources/integrations.js";

export type {
  EmailSignature,
  CreateSignatureRequest,
  UpdateSignatureRequest,
  SmtpPoolName,
  SmtpPoolConfig,
  UpsertSmtpPoolRequest,
  DedicatedIp as SettingsDedicatedIp,
  MonitoredDomain as SettingsMonitoredDomain,
  AddDmarcDomainRequest as SettingsAddDmarcDomainRequest,
  IpPool,
  CreateIpPoolRequest,
  UnsubscribePageConfig,
  UpdateUnsubscribePageRequest,
  WhitelabelConfig,
  UpdateWhitelabelRequest,
  AuditLog,
  AuditLogsParams,
  AuditLogsResponse,
} from "./resources/settings.js";

export type {
  Label,
  LabelsListResponse,
  CreateLabelRequest,
} from "./resources/labels.js";

export type {
  DraftRecipient,
  Draft,
  DraftsListResponse,
  CreateDraftRequest,
  UpdateDraftRequest,
} from "./resources/drafts.js";

export type {
  PreferenceFrequency,
  EmailPreferences,
  GetPreferencesResponse,
  UpdatePreferencesRequest,
  UpdatePreferencesResponse,
} from "./resources/preferences.js";
export { PlanResource } from "./resources/plan.js";
export type {
  PlanResponse,
  PlanUsageEntry,
  PlanUpgradeOffer,
  MonetizationStats,
} from "./resources/plan.js";
export { MisarMailPlanLimitError } from "./errors.js";
export {
  EmailsResource,
  RevenueResource,
  WarmupResource,
} from "./resources/mailbox.js";
export type {
  StoredEmail,
  EmailListResponse,
  EmailResponse,
  ListEmailsOptions,
  RevenueAttributionOptions,
} from "./resources/mailbox.js";
export { StreamingResource } from "./resources/streaming.js";
export type {
  MisarMailStreamEvent,
  GenerateEmailDelta,
  GenerateEmailOptions,
} from "./resources/streaming.js";
