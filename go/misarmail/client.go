package misarmail

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	defaultBaseURL    = "https://mail.misar.io/api/v1"
	defaultAPIBase    = "https://mail.misar.io/api"
	defaultMaxRetries = 3
	defaultTimeout    = 30 * time.Second
	retryBaseMS       = 200 * time.Millisecond
)

var retryable = map[int]bool{429: true, 500: true, 502: true, 503: true, 504: true}

// ── Options ───────────────────────────────────────────────────────────────────

type Option func(*Client)

func WithBaseURL(u string) Option {
	return func(c *Client) { c.baseURL = strings.TrimRight(u, "/") }
}
func WithAPIBase(u string) Option {
	return func(c *Client) { c.apiBase = strings.TrimRight(u, "/") }
}
func WithMaxRetries(n int) Option { return func(c *Client) { c.maxRetries = n } }
func WithTimeout(d time.Duration) Option {
	return func(c *Client) { c.httpClient = &http.Client{Timeout: d} }
}
func WithHTTPClient(h *http.Client) Option { return func(c *Client) { c.httpClient = h } }

// ── Client ────────────────────────────────────────────────────────────────────

type Client struct {
	apiKey     string
	baseURL    string
	apiBase    string
	maxRetries int
	httpClient *http.Client

	Email        *EmailResource
	Contacts     *ContactsResource
	Campaigns    *CampaignsResource
	Templates    *TemplatesResource
	Automations  *AutomationsResource
	Domains      *DomainsResource
	Aliases      *AliasesResource
	DedicatedIPs *DedicatedIPsResource
	Channels     *ChannelsResource
	ABTests      *ABTestsResource
	Sandbox      *SandboxResource
	Inbound      *InboundResource
	Analytics    *AnalyticsResource
	Track        *TrackResource
	Keys         *KeysResource
	Validate     *ValidateResource
	Leads        *LeadsResource
	Autopilot    *AutopilotResource
	SalesAgent   *SalesAgentResource
	CRM          *CRMResource
	Webhooks     *WebhooksResource
	Usage        *UsageResource
	Billing      *BillingResource
	Workspaces   *WorkspacesResource
}

func New(apiKey string, opts ...Option) *Client {
	c := &Client{
		apiKey:     apiKey,
		baseURL:    defaultBaseURL,
		apiBase:    defaultAPIBase,
		maxRetries: defaultMaxRetries,
		httpClient: &http.Client{Timeout: defaultTimeout},
	}
	for _, o := range opts {
		o(c)
	}
	c.Email = &EmailResource{c}
	c.Contacts = &ContactsResource{c}
	c.Campaigns = &CampaignsResource{c}
	c.Templates = &TemplatesResource{c}
	c.Automations = &AutomationsResource{c}
	c.Domains = &DomainsResource{c}
	c.Aliases = &AliasesResource{c}
	c.DedicatedIPs = &DedicatedIPsResource{c}
	c.Channels = &ChannelsResource{c}
	c.ABTests = &ABTestsResource{c}
	c.Sandbox = &SandboxResource{c}
	c.Inbound = &InboundResource{c}
	c.Analytics = &AnalyticsResource{c}
	c.Track = &TrackResource{c}
	c.Keys = &KeysResource{c}
	c.Validate = &ValidateResource{c}
	c.Leads = &LeadsResource{c}
	c.Autopilot = &AutopilotResource{c}
	c.SalesAgent = &SalesAgentResource{c}
	c.CRM = &CRMResource{c}
	c.Webhooks = &WebhooksResource{c}
	c.Usage = &UsageResource{c}
	c.Billing = &BillingResource{c}
	c.Workspaces = &WorkspacesResource{c}
	return c
}

// ── Core HTTP ─────────────────────────────────────────────────────────────────

func (c *Client) do(ctx context.Context, method, fullURL string, body, out interface{}) error {
	var lastErr error
	for attempt := 0; attempt < c.maxRetries; attempt++ {
		var bodyReader io.Reader
		if body != nil {
			b, err := json.Marshal(body)
			if err != nil {
				return err
			}
			bodyReader = bytes.NewReader(b)
		}
		req, err := http.NewRequestWithContext(ctx, method, fullURL, bodyReader)
		if err != nil {
			return err
		}
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
		if body != nil {
			req.Header.Set("Content-Type", "application/json")
		}

		resp, err := c.httpClient.Do(req)
		if err != nil {
			lastErr = &NetworkError{Message: err.Error(), Cause: err}
			if attempt < c.maxRetries-1 {
				time.Sleep(retryBaseMS * (1 << attempt))
				continue
			}
			return lastErr
		}
		defer resp.Body.Close() //nolint:gocritic

		if retryable[resp.StatusCode] && attempt < c.maxRetries-1 {
			io.Copy(io.Discard, resp.Body) //nolint:errcheck
			time.Sleep(retryBaseMS * (1 << attempt))
			continue
		}

		if resp.StatusCode == http.StatusNoContent {
			return nil
		}

		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			var errBody struct {
				Error   string `json:"error"`
				Message string `json:"message"`
			}
			json.NewDecoder(resp.Body).Decode(&errBody) //nolint:errcheck
			msg := errBody.Error
			if msg == "" {
				msg = errBody.Message
			}
			if msg == "" {
				msg = resp.Status
			}
			return &APIError{Status: resp.StatusCode, Message: msg}
		}

		if out != nil {
			if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
				return fmt.Errorf("misarmail: decode: %w", err)
			}
		}
		return nil
	}
	if lastErr != nil {
		return lastErr
	}
	return &NetworkError{Message: "max retries exceeded"}
}

// request uses baseURL + path
func (c *Client) request(ctx context.Context, method, path string, body, out interface{}) error {
	return c.do(ctx, method, c.baseURL+path, body, out)
}

// requestAPI uses apiBase + path (billing, workspaces)
func (c *Client) requestAPI(ctx context.Context, method, path string, body, out interface{}) error {
	return c.do(ctx, method, c.apiBase+path, body, out)
}

// ── Query helpers ─────────────────────────────────────────────────────────────

func listQuery(p *ListParams) string {
	if p == nil {
		return ""
	}
	q := url.Values{}
	if p.Page > 0 {
		q.Set("page", fmt.Sprintf("%d", p.Page))
	}
	if p.Limit > 0 {
		q.Set("limit", fmt.Sprintf("%d", p.Limit))
	}
	if p.Status != "" {
		q.Set("status", p.Status)
	}
	if p.Search != "" {
		q.Set("search", p.Search)
	}
	if s := q.Encode(); s != "" {
		return "?" + s
	}
	return ""
}

func analyticsQuery(p *AnalyticsParams) string {
	if p == nil {
		return ""
	}
	q := url.Values{}
	if p.StartDate != "" {
		q.Set("start_date", p.StartDate)
	}
	if p.EndDate != "" {
		q.Set("end_date", p.EndDate)
	}
	if p.CampaignID != "" {
		q.Set("campaign_id", p.CampaignID)
	}
	if p.Interval != "" {
		q.Set("interval", p.Interval)
	}
	if s := q.Encode(); s != "" {
		return "?" + s
	}
	return ""
}

func usageQuery(p *UsageParams) string {
	if p == nil {
		return ""
	}
	q := url.Values{}
	if p.StartDate != "" {
		q.Set("start_date", p.StartDate)
	}
	if p.EndDate != "" {
		q.Set("end_date", p.EndDate)
	}
	if s := q.Encode(); s != "" {
		return "?" + s
	}
	return ""
}

func crmListQuery(p *CRMListParams) string {
	if p == nil {
		return ""
	}
	q := url.Values{}
	if p.Page > 0 {
		q.Set("page", fmt.Sprintf("%d", p.Page))
	}
	if p.Limit > 0 {
		q.Set("limit", fmt.Sprintf("%d", p.Limit))
	}
	if p.Status != "" {
		q.Set("status", p.Status)
	}
	if p.Search != "" {
		q.Set("search", p.Search)
	}
	if s := q.Encode(); s != "" {
		return "?" + s
	}
	return ""
}

func salesActionsQuery(p *SalesAgentActionsParams) string {
	if p == nil {
		return ""
	}
	q := url.Values{}
	if p.Status != "" {
		q.Set("status", p.Status)
	}
	if p.ContactID != "" {
		q.Set("contact_id", p.ContactID)
	}
	if p.Page > 0 {
		q.Set("page", fmt.Sprintf("%d", p.Page))
	}
	if p.Limit > 0 {
		q.Set("limit", fmt.Sprintf("%d", p.Limit))
	}
	if s := q.Encode(); s != "" {
		return "?" + s
	}
	return ""
}

// ── Email ─────────────────────────────────────────────────────────────────────

type EmailResource struct{ c *Client }

func (r *EmailResource) Send(ctx context.Context, data *SendEmailRequest) (*SendEmailResponse, error) {
	var out SendEmailResponse
	return &out, r.c.request(ctx, http.MethodPost, "/send", data, &out)
}

// ── Contacts ──────────────────────────────────────────────────────────────────

type ContactsResource struct{ c *Client }

func (r *ContactsResource) List(ctx context.Context, params *ListParams) (*ContactsListResponse, error) {
	var out ContactsListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/contacts"+listQuery(params), nil, &out)
}

func (r *ContactsResource) Create(ctx context.Context, data *ContactInput) (*Contact, error) {
	var out Contact
	return &out, r.c.request(ctx, http.MethodPost, "/contacts", data, &out)
}

func (r *ContactsResource) Get(ctx context.Context, id string) (*Contact, error) {
	var out Contact
	return &out, r.c.request(ctx, http.MethodGet, "/contacts/"+id, nil, &out)
}

func (r *ContactsResource) Update(ctx context.Context, id string, data *ContactInput) (*Contact, error) {
	var out Contact
	return &out, r.c.request(ctx, http.MethodPatch, "/contacts/"+id, data, &out)
}

func (r *ContactsResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/contacts/"+id, nil, nil)
}

func (r *ContactsResource) Import(ctx context.Context, data *ContactImportRequest) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/contacts/import", data, &out)
}

// ── Campaigns ─────────────────────────────────────────────────────────────────

type CampaignsResource struct{ c *Client }

func (r *CampaignsResource) List(ctx context.Context, params *ListParams) (*CampaignsListResponse, error) {
	var out CampaignsListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/campaigns"+listQuery(params), nil, &out)
}

func (r *CampaignsResource) Create(ctx context.Context, data *CreateCampaignRequest) (*Campaign, error) {
	var out Campaign
	return &out, r.c.request(ctx, http.MethodPost, "/campaigns", data, &out)
}

func (r *CampaignsResource) Get(ctx context.Context, id string) (*Campaign, error) {
	var out Campaign
	return &out, r.c.request(ctx, http.MethodGet, "/campaigns/"+id, nil, &out)
}

func (r *CampaignsResource) Update(ctx context.Context, id string, data *UpdateCampaignRequest) (*Campaign, error) {
	var out Campaign
	return &out, r.c.request(ctx, http.MethodPatch, "/campaigns/"+id, data, &out)
}

func (r *CampaignsResource) Send(ctx context.Context, id string) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/campaigns/"+id+"/send", nil, &out)
}

func (r *CampaignsResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/campaigns/"+id, nil, nil)
}

// ── Templates ─────────────────────────────────────────────────────────────────

type TemplatesResource struct{ c *Client }

func (r *TemplatesResource) List(ctx context.Context) (*TemplatesListResponse, error) {
	var out TemplatesListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/templates", nil, &out)
}

func (r *TemplatesResource) Create(ctx context.Context, data *CreateTemplateRequest) (*Template, error) {
	var out Template
	return &out, r.c.request(ctx, http.MethodPost, "/templates", data, &out)
}

func (r *TemplatesResource) Get(ctx context.Context, id string) (*Template, error) {
	var out Template
	return &out, r.c.request(ctx, http.MethodGet, "/templates/"+id, nil, &out)
}

func (r *TemplatesResource) Update(ctx context.Context, id string, data *UpdateTemplateRequest) (*Template, error) {
	var out Template
	return &out, r.c.request(ctx, http.MethodPatch, "/templates/"+id, data, &out)
}

func (r *TemplatesResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/templates/"+id, nil, nil)
}

func (r *TemplatesResource) Render(ctx context.Context, data *RenderTemplateRequest) (*RenderTemplateResponse, error) {
	var out RenderTemplateResponse
	return &out, r.c.request(ctx, http.MethodPost, "/templates/render", data, &out)
}

// ── Automations ───────────────────────────────────────────────────────────────

type AutomationsResource struct{ c *Client }

func (r *AutomationsResource) List(ctx context.Context, params *ListParams) (*AutomationsListResponse, error) {
	var out AutomationsListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/automations"+listQuery(params), nil, &out)
}

func (r *AutomationsResource) Create(ctx context.Context, data *CreateAutomationRequest) (*Automation, error) {
	var out Automation
	return &out, r.c.request(ctx, http.MethodPost, "/automations", data, &out)
}

func (r *AutomationsResource) Get(ctx context.Context, id string) (*Automation, error) {
	var out Automation
	return &out, r.c.request(ctx, http.MethodGet, "/automations/"+id, nil, &out)
}

func (r *AutomationsResource) Update(ctx context.Context, id string, data *UpdateAutomationRequest) (*Automation, error) {
	var out Automation
	return &out, r.c.request(ctx, http.MethodPatch, "/automations/"+id, data, &out)
}

func (r *AutomationsResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/automations/"+id, nil, nil)
}

func (r *AutomationsResource) Activate(ctx context.Context, id string, active bool) (*Automation, error) {
	var out Automation
	body := map[string]interface{}{"active": active}
	return &out, r.c.request(ctx, http.MethodPatch, "/automations/"+id+"/activate", body, &out)
}

// ── Domains ───────────────────────────────────────────────────────────────────

type DomainsResource struct{ c *Client }

func (r *DomainsResource) List(ctx context.Context) (*DomainsListResponse, error) {
	var out DomainsListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/domains", nil, &out)
}

func (r *DomainsResource) Create(ctx context.Context, data *CreateDomainRequest) (*Domain, error) {
	var out Domain
	return &out, r.c.request(ctx, http.MethodPost, "/domains", data, &out)
}

func (r *DomainsResource) Get(ctx context.Context, id string) (*Domain, error) {
	var out Domain
	return &out, r.c.request(ctx, http.MethodGet, "/domains/"+id, nil, &out)
}

func (r *DomainsResource) Verify(ctx context.Context, id string) (*DomainVerificationResponse, error) {
	var out DomainVerificationResponse
	return &out, r.c.request(ctx, http.MethodPost, "/domains/"+id+"/verify", nil, &out)
}

func (r *DomainsResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/domains/"+id, nil, nil)
}

// ── Aliases ───────────────────────────────────────────────────────────────────

type AliasesResource struct{ c *Client }

func (r *AliasesResource) List(ctx context.Context) (*AliasesListResponse, error) {
	var out AliasesListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/aliases", nil, &out)
}

func (r *AliasesResource) Create(ctx context.Context, data *CreateAliasRequest) (*Alias, error) {
	var out Alias
	return &out, r.c.request(ctx, http.MethodPost, "/aliases", data, &out)
}

func (r *AliasesResource) Get(ctx context.Context, id string) (*Alias, error) {
	var out Alias
	return &out, r.c.request(ctx, http.MethodGet, "/aliases/"+id, nil, &out)
}

func (r *AliasesResource) Update(ctx context.Context, id string, data *UpdateAliasRequest) (*Alias, error) {
	var out Alias
	return &out, r.c.request(ctx, http.MethodPatch, "/aliases/"+id, data, &out)
}

func (r *AliasesResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/aliases/"+id, nil, nil)
}

// ── Dedicated IPs ─────────────────────────────────────────────────────────────

type DedicatedIPsResource struct{ c *Client }

func (r *DedicatedIPsResource) List(ctx context.Context) (*DedicatedIPsListResponse, error) {
	var out DedicatedIPsListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/dedicated-ips", nil, &out)
}

func (r *DedicatedIPsResource) Create(ctx context.Context, data *CreateDedicatedIPRequest) (*DedicatedIP, error) {
	var out DedicatedIP
	return &out, r.c.request(ctx, http.MethodPost, "/dedicated-ips", data, &out)
}

func (r *DedicatedIPsResource) Update(ctx context.Context, id string, data *UpdateDedicatedIPRequest) (*DedicatedIP, error) {
	var out DedicatedIP
	return &out, r.c.request(ctx, http.MethodPatch, "/dedicated-ips/"+id, data, &out)
}

func (r *DedicatedIPsResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/dedicated-ips/"+id, nil, nil)
}

// ── Channels ──────────────────────────────────────────────────────────────────

type ChannelsResource struct{ c *Client }

func (r *ChannelsResource) SendWhatsApp(ctx context.Context, data *WhatsAppMessage) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/channels/whatsapp/send", data, &out)
}

func (r *ChannelsResource) SendPush(ctx context.Context, data *PushNotification) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/channels/push/send", data, &out)
}

// ── A/B Tests ─────────────────────────────────────────────────────────────────

type ABTestsResource struct{ c *Client }

func (r *ABTestsResource) List(ctx context.Context) (*ABTestsListResponse, error) {
	var out ABTestsListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/ab-tests", nil, &out)
}

func (r *ABTestsResource) Create(ctx context.Context, data *CreateABTestRequest) (*ABTest, error) {
	var out ABTest
	return &out, r.c.request(ctx, http.MethodPost, "/ab-tests", data, &out)
}

func (r *ABTestsResource) Get(ctx context.Context, id string) (*ABTest, error) {
	var out ABTest
	return &out, r.c.request(ctx, http.MethodGet, "/ab-tests/"+id, nil, &out)
}

func (r *ABTestsResource) SetWinner(ctx context.Context, id, variantID string) (map[string]interface{}, error) {
	var out map[string]interface{}
	body := map[string]string{"variant_id": variantID}
	return out, r.c.request(ctx, http.MethodPost, "/ab-tests/"+id+"/winner", body, &out)
}

// ── Sandbox ───────────────────────────────────────────────────────────────────

type SandboxResource struct{ c *Client }

func (r *SandboxResource) Send(ctx context.Context, data *SandboxSendRequest) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/sandbox/send", data, &out)
}

func (r *SandboxResource) List(ctx context.Context, params *ListParams) (*SandboxListResponse, error) {
	var out SandboxListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/sandbox"+listQuery(params), nil, &out)
}

func (r *SandboxResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/sandbox/"+id, nil, nil)
}

// ── Inbound ───────────────────────────────────────────────────────────────────

type InboundResource struct{ c *Client }

func (r *InboundResource) List(ctx context.Context, params *ListParams) (*InboundListResponse, error) {
	var out InboundListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/inbound"+listQuery(params), nil, &out)
}

func (r *InboundResource) Create(ctx context.Context, data *CreateInboundRequest) (*InboundRoute, error) {
	var out InboundRoute
	return &out, r.c.request(ctx, http.MethodPost, "/inbound", data, &out)
}

func (r *InboundResource) Get(ctx context.Context, id string) (*InboundRoute, error) {
	var out InboundRoute
	return &out, r.c.request(ctx, http.MethodGet, "/inbound/"+id, nil, &out)
}

func (r *InboundResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/inbound/"+id, nil, nil)
}

// ── Analytics ─────────────────────────────────────────────────────────────────

type AnalyticsResource struct{ c *Client }

func (r *AnalyticsResource) Overview(ctx context.Context, params *AnalyticsParams) (*AnalyticsOverviewResponse, error) {
	var out AnalyticsOverviewResponse
	return &out, r.c.request(ctx, http.MethodGet, "/analytics/overview"+analyticsQuery(params), nil, &out)
}

// ── Track ─────────────────────────────────────────────────────────────────────

type TrackResource struct{ c *Client }

func (r *TrackResource) Event(ctx context.Context, data *TrackEventRequest) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/track/event", data, &out)
}

func (r *TrackResource) Purchase(ctx context.Context, data *TrackPurchaseRequest) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/track/purchase", data, &out)
}

// ── Keys ──────────────────────────────────────────────────────────────────────

type KeysResource struct{ c *Client }

func (r *KeysResource) List(ctx context.Context) (*KeysListResponse, error) {
	var out KeysListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/keys", nil, &out)
}

func (r *KeysResource) Create(ctx context.Context, data *CreateKeyRequest) (*CreateKeyResponse, error) {
	var out CreateKeyResponse
	return &out, r.c.request(ctx, http.MethodPost, "/keys", data, &out)
}

func (r *KeysResource) Get(ctx context.Context, id string) (*APIKey, error) {
	var out APIKey
	return &out, r.c.request(ctx, http.MethodGet, "/keys/"+id, nil, &out)
}

func (r *KeysResource) Revoke(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/keys/"+id, nil, nil)
}

// ── Validate ──────────────────────────────────────────────────────────────────

type ValidateResource struct{ c *Client }

func (r *ValidateResource) Email(ctx context.Context, address string) (*ValidateEmailResponse, error) {
	var out ValidateEmailResponse
	q := "?email=" + url.QueryEscape(address)
	return &out, r.c.request(ctx, http.MethodGet, "/validate/email"+q, nil, &out)
}

// ── Leads ─────────────────────────────────────────────────────────────────────

type LeadsResource struct{ c *Client }

func (r *LeadsResource) Search(ctx context.Context, data *LeadSearchRequest) (*LeadJob, error) {
	var out LeadJob
	return &out, r.c.request(ctx, http.MethodPost, "/leads/search", data, &out)
}

func (r *LeadsResource) GetJob(ctx context.Context, id string) (*LeadJob, error) {
	var out LeadJob
	return &out, r.c.request(ctx, http.MethodGet, "/leads/jobs/"+id, nil, &out)
}

func (r *LeadsResource) ListJobs(ctx context.Context, params *ListParams) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodGet, "/leads/jobs"+listQuery(params), nil, &out)
}

func (r *LeadsResource) Results(ctx context.Context, jobID string) ([]*LeadResult, error) {
	var wrapper struct {
		Data []*LeadResult `json:"data"`
	}
	if err := r.c.request(ctx, http.MethodGet, "/leads/jobs/"+jobID+"/results", nil, &wrapper); err != nil {
		return nil, err
	}
	return wrapper.Data, nil
}

func (r *LeadsResource) Import(ctx context.Context, data *LeadImportRequest) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/leads/import", data, &out)
}

func (r *LeadsResource) Credits(ctx context.Context) (*CreditsResponse, error) {
	var out CreditsResponse
	return &out, r.c.request(ctx, http.MethodGet, "/leads/credits", nil, &out)
}

// ── Autopilot ─────────────────────────────────────────────────────────────────

type AutopilotResource struct{ c *Client }

func (r *AutopilotResource) Start(ctx context.Context, data *AutopilotRequest) (*AutopilotSession, error) {
	var out AutopilotSession
	return &out, r.c.request(ctx, http.MethodPost, "/autopilot/start", data, &out)
}

func (r *AutopilotResource) Get(ctx context.Context, id string) (*AutopilotSession, error) {
	var out AutopilotSession
	return &out, r.c.request(ctx, http.MethodGet, "/autopilot/"+id, nil, &out)
}

func (r *AutopilotResource) List(ctx context.Context, params *ListParams) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodGet, "/autopilot"+listQuery(params), nil, &out)
}

func (r *AutopilotResource) DailyPlan(ctx context.Context) (*AutopilotDailyPlan, error) {
	var out AutopilotDailyPlan
	return &out, r.c.request(ctx, http.MethodGet, "/autopilot/daily-plan", nil, &out)
}

// ── Sales Agent ───────────────────────────────────────────────────────────────

type SalesAgentResource struct{ c *Client }

func (r *SalesAgentResource) GetConfig(ctx context.Context) (*SalesAgentConfig, error) {
	var out SalesAgentConfig
	return &out, r.c.request(ctx, http.MethodGet, "/sales-agent/config", nil, &out)
}

func (r *SalesAgentResource) UpdateConfig(ctx context.Context, data *UpdateSalesAgentConfigRequest) (*SalesAgentConfig, error) {
	var out SalesAgentConfig
	return &out, r.c.request(ctx, http.MethodPatch, "/sales-agent/config", data, &out)
}

func (r *SalesAgentResource) GetActions(ctx context.Context, params *SalesAgentActionsParams) ([]*SalesAgentAction, error) {
	var wrapper struct {
		Data []*SalesAgentAction `json:"data"`
	}
	if err := r.c.request(ctx, http.MethodGet, "/sales-agent/actions"+salesActionsQuery(params), nil, &wrapper); err != nil {
		return nil, err
	}
	return wrapper.Data, nil
}

// ── CRM ───────────────────────────────────────────────────────────────────────

type CRMResource struct{ c *Client }

func (r *CRMResource) ListConversations(ctx context.Context, params *CRMListParams) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodGet, "/crm/conversations"+crmListQuery(params), nil, &out)
}

func (r *CRMResource) GetConversation(ctx context.Context, id string) (*CRMConversation, error) {
	var out CRMConversation
	return &out, r.c.request(ctx, http.MethodGet, "/crm/conversations/"+id, nil, &out)
}

func (r *CRMResource) UpdateConversation(ctx context.Context, id string, data map[string]interface{}) (*CRMConversation, error) {
	var out CRMConversation
	return &out, r.c.request(ctx, http.MethodPatch, "/crm/conversations/"+id, data, &out)
}

func (r *CRMResource) ListMessages(ctx context.Context, conversationID string) ([]*CRMMessage, error) {
	var wrapper struct {
		Data []*CRMMessage `json:"data"`
	}
	if err := r.c.request(ctx, http.MethodGet, "/crm/conversations/"+conversationID+"/messages", nil, &wrapper); err != nil {
		return nil, err
	}
	return wrapper.Data, nil
}

func (r *CRMResource) ListDeals(ctx context.Context, params *CRMListParams) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodGet, "/crm/deals"+crmListQuery(params), nil, &out)
}

func (r *CRMResource) CreateDeal(ctx context.Context, data *CreateDealRequest) (*CRMDeal, error) {
	var out CRMDeal
	return &out, r.c.request(ctx, http.MethodPost, "/crm/deals", data, &out)
}

func (r *CRMResource) GetDeal(ctx context.Context, id string) (*CRMDeal, error) {
	var out CRMDeal
	return &out, r.c.request(ctx, http.MethodGet, "/crm/deals/"+id, nil, &out)
}

func (r *CRMResource) UpdateDeal(ctx context.Context, id string, data *UpdateDealRequest) (*CRMDeal, error) {
	var out CRMDeal
	return &out, r.c.request(ctx, http.MethodPatch, "/crm/deals/"+id, data, &out)
}

func (r *CRMResource) DeleteDeal(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/crm/deals/"+id, nil, nil)
}

func (r *CRMResource) ListClients(ctx context.Context, params *CRMListParams) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodGet, "/crm/clients"+crmListQuery(params), nil, &out)
}

func (r *CRMResource) CreateClient(ctx context.Context, data *CreateClientRequest) (*CRMClient, error) {
	var out CRMClient
	return &out, r.c.request(ctx, http.MethodPost, "/crm/clients", data, &out)
}

// ── Webhooks ──────────────────────────────────────────────────────────────────

type WebhooksResource struct{ c *Client }

func (r *WebhooksResource) List(ctx context.Context) (*WebhooksListResponse, error) {
	var out WebhooksListResponse
	return &out, r.c.request(ctx, http.MethodGet, "/webhooks", nil, &out)
}

func (r *WebhooksResource) Create(ctx context.Context, data *CreateWebhookRequest) (*Webhook, error) {
	var out Webhook
	return &out, r.c.request(ctx, http.MethodPost, "/webhooks", data, &out)
}

func (r *WebhooksResource) Get(ctx context.Context, id string) (*Webhook, error) {
	var out Webhook
	return &out, r.c.request(ctx, http.MethodGet, "/webhooks/"+id, nil, &out)
}

func (r *WebhooksResource) Update(ctx context.Context, id string, data *UpdateWebhookRequest) (*Webhook, error) {
	var out Webhook
	return &out, r.c.request(ctx, http.MethodPatch, "/webhooks/"+id, data, &out)
}

func (r *WebhooksResource) Delete(ctx context.Context, id string) error {
	return r.c.request(ctx, http.MethodDelete, "/webhooks/"+id, nil, nil)
}

func (r *WebhooksResource) Test(ctx context.Context, id string) (map[string]interface{}, error) {
	var out map[string]interface{}
	return out, r.c.request(ctx, http.MethodPost, "/webhooks/"+id+"/test", nil, &out)
}

// ── Usage ─────────────────────────────────────────────────────────────────────

type UsageResource struct{ c *Client }

func (r *UsageResource) Get(ctx context.Context, params *UsageParams) (*UsageResponse, error) {
	var out UsageResponse
	return &out, r.c.request(ctx, http.MethodGet, "/usage"+usageQuery(params), nil, &out)
}

// ── Billing ───────────────────────────────────────────────────────────────────

type BillingResource struct{ c *Client }

func (r *BillingResource) Subscription(ctx context.Context) (*BillingSubscription, error) {
	var out BillingSubscription
	return &out, r.c.requestAPI(ctx, http.MethodGet, "/billing/subscription", nil, &out)
}

func (r *BillingResource) Checkout(ctx context.Context, data *BillingCheckoutRequest) (*BillingCheckoutResponse, error) {
	var out BillingCheckoutResponse
	return &out, r.c.requestAPI(ctx, http.MethodPost, "/billing/checkout", data, &out)
}

// ── Workspaces ────────────────────────────────────────────────────────────────

type WorkspacesResource struct{ c *Client }

func (r *WorkspacesResource) List(ctx context.Context) (*WorkspacesListResponse, error) {
	var out WorkspacesListResponse
	return &out, r.c.requestAPI(ctx, http.MethodGet, "/workspaces", nil, &out)
}

func (r *WorkspacesResource) Create(ctx context.Context, data *CreateWorkspaceRequest) (*Workspace, error) {
	var out Workspace
	return &out, r.c.requestAPI(ctx, http.MethodPost, "/workspaces", data, &out)
}

func (r *WorkspacesResource) Get(ctx context.Context, id string) (*Workspace, error) {
	var out Workspace
	return &out, r.c.requestAPI(ctx, http.MethodGet, "/workspaces/"+id, nil, &out)
}

func (r *WorkspacesResource) Update(ctx context.Context, id string, data *UpdateWorkspaceRequest) (*Workspace, error) {
	var out Workspace
	return &out, r.c.requestAPI(ctx, http.MethodPatch, "/workspaces/"+id, data, &out)
}

func (r *WorkspacesResource) Delete(ctx context.Context, id string) error {
	return r.c.requestAPI(ctx, http.MethodDelete, "/workspaces/"+id, nil, nil)
}

func (r *WorkspacesResource) ListMembers(ctx context.Context, wsID string) ([]*WorkspaceMember, error) {
	var wrapper struct {
		Data []*WorkspaceMember `json:"data"`
	}
	if err := r.c.requestAPI(ctx, http.MethodGet, "/workspaces/"+wsID+"/members", nil, &wrapper); err != nil {
		return nil, err
	}
	return wrapper.Data, nil
}

func (r *WorkspacesResource) InviteMember(ctx context.Context, wsID string, data *InviteMemberRequest) (*WorkspaceMember, error) {
	var out WorkspaceMember
	return &out, r.c.requestAPI(ctx, http.MethodPost, "/workspaces/"+wsID+"/members", data, &out)
}

func (r *WorkspacesResource) UpdateMember(ctx context.Context, wsID, userID string, data *UpdateMemberRequest) (*WorkspaceMember, error) {
	var out WorkspaceMember
	return &out, r.c.requestAPI(ctx, http.MethodPatch, "/workspaces/"+wsID+"/members/"+userID, data, &out)
}

func (r *WorkspacesResource) RemoveMember(ctx context.Context, wsID, userID string) error {
	return r.c.requestAPI(ctx, http.MethodDelete, "/workspaces/"+wsID+"/members/"+userID, nil, nil)
}
