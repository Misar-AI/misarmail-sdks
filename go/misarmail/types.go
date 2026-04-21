package misarmail

import "fmt"

// ── Pagination ────────────────────────────────────────────────────────────────

type ListParams struct {
	Page   int    `json:"page,omitempty"`
	Limit  int    `json:"limit,omitempty"`
	Status string `json:"status,omitempty"`
	Search string `json:"search,omitempty"`
}

// ── Email ─────────────────────────────────────────────────────────────────────

type EmailAddress struct {
	Email string `json:"email"`
	Name  string `json:"name,omitempty"`
}

type SendEmailRequest struct {
	From     string            `json:"from"`
	To       []string          `json:"to"`
	CC       []string          `json:"cc,omitempty"`
	BCC      []string          `json:"bcc,omitempty"`
	ReplyTo  string            `json:"reply_to,omitempty"`
	Subject  string            `json:"subject"`
	HTML     string            `json:"html,omitempty"`
	Text     string            `json:"text,omitempty"`
	Tags     []string          `json:"tags,omitempty"`
	Metadata map[string]string `json:"metadata,omitempty"`
}

type SendEmailResponse struct {
	Success   bool   `json:"success"`
	MessageID string `json:"message_id"`
}

// ── Contacts ──────────────────────────────────────────────────────────────────

type Contact struct {
	ID        string `json:"id"`
	Email     string `json:"email"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Status    string `json:"status"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}

type ContactInput struct {
	Email        string                 `json:"email"`
	FirstName    string                 `json:"first_name,omitempty"`
	LastName     string                 `json:"last_name,omitempty"`
	CustomFields map[string]interface{} `json:"custom_fields,omitempty"`
	Tags         []string               `json:"tags,omitempty"`
}

type ContactImportRequest struct {
	Contacts []ContactInput `json:"contacts"`
	Tags     []string       `json:"tags,omitempty"`
	ListID   string         `json:"list_id,omitempty"`
}

type ContactsListResponse struct {
	Data  []Contact `json:"data"`
	Total int       `json:"total"`
	Page  int       `json:"page"`
	Limit int       `json:"limit"`
}

// ── Campaigns ─────────────────────────────────────────────────────────────────

type Campaign struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	Status          string `json:"status"`
	Subject         string `json:"subject"`
	FromEmail       string `json:"from_email"`
	FromName        string `json:"from_name"`
	BodyHTML        string `json:"body_html"`
	BodyText        string `json:"body_text"`
	TotalRecipients int    `json:"total_recipients"`
	TotalSent       int    `json:"total_sent"`
	TotalDelivered  int    `json:"total_delivered"`
	TotalOpened     int    `json:"total_opened"`
	TotalClicked    int    `json:"total_clicked"`
	TotalBounced    int    `json:"total_bounced"`
	CreatedAt       string `json:"created_at"`
	UpdatedAt       string `json:"updated_at"`
}

type CreateCampaignRequest struct {
	Name        string `json:"name"`
	Subject     string `json:"subject"`
	FromEmail   string `json:"from_email"`
	FromName    string `json:"from_name,omitempty"`
	BodyHTML    string `json:"body_html,omitempty"`
	BodyText    string `json:"body_text,omitempty"`
	SegmentID   string `json:"segment_id,omitempty"`
	TemplateID  string `json:"template_id,omitempty"`
	ScheduledAt string `json:"scheduled_at,omitempty"`
}

type UpdateCampaignRequest struct {
	Name        *string `json:"name,omitempty"`
	Subject     *string `json:"subject,omitempty"`
	FromEmail   *string `json:"from_email,omitempty"`
	FromName    *string `json:"from_name,omitempty"`
	BodyHTML    *string `json:"body_html,omitempty"`
	BodyText    *string `json:"body_text,omitempty"`
	SegmentID   *string `json:"segment_id,omitempty"`
	TemplateID  *string `json:"template_id,omitempty"`
	ScheduledAt *string `json:"scheduled_at,omitempty"`
}

type CampaignsListResponse struct {
	Data  []Campaign `json:"data"`
	Total int        `json:"total"`
}

// ── Templates ─────────────────────────────────────────────────────────────────

type Template struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	HTML      string `json:"html"`
	Text      string `json:"text"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}

type CreateTemplateRequest struct {
	Name string `json:"name"`
	HTML string `json:"html"`
	Text string `json:"text,omitempty"`
}

type UpdateTemplateRequest struct {
	Name *string `json:"name,omitempty"`
	HTML *string `json:"html,omitempty"`
	Text *string `json:"text,omitempty"`
}

type RenderTemplateRequest struct {
	TemplateID string                 `json:"template_id"`
	Variables  map[string]interface{} `json:"variables,omitempty"`
	ContactID  string                 `json:"contact_id,omitempty"`
}

type RenderTemplateResponse struct {
	HTML string `json:"html"`
	Text string `json:"text"`
}

type TemplatesListResponse struct {
	Data  []Template `json:"data"`
	Total int        `json:"total"`
}

// ── Automations ───────────────────────────────────────────────────────────────

type Automation struct {
	ID        string                   `json:"id"`
	Name      string                   `json:"name"`
	Status    string                   `json:"status"`
	Trigger   string                   `json:"trigger"`
	Steps     []map[string]interface{} `json:"steps"`
	CreatedAt string                   `json:"created_at"`
	UpdatedAt string                   `json:"updated_at"`
}

type AutomationTrigger struct {
	Type   string                 `json:"type"`
	Config map[string]interface{} `json:"config,omitempty"`
}

type CreateAutomationRequest struct {
	Name    string                   `json:"name"`
	Trigger AutomationTrigger        `json:"trigger"`
	Steps   []map[string]interface{} `json:"steps,omitempty"`
}

type UpdateAutomationRequest struct {
	Name  *string                  `json:"name,omitempty"`
	Steps []map[string]interface{} `json:"steps,omitempty"`
}

type AutomationsListResponse struct {
	Data  []Automation `json:"data"`
	Total int          `json:"total"`
}

// ── Domains ───────────────────────────────────────────────────────────────────

type Domain struct {
	ID         string                   `json:"id"`
	Domain     string                   `json:"domain"`
	Status     string                   `json:"status"`
	CreatedAt  string                   `json:"created_at"`
	DNSRecords []map[string]interface{} `json:"dns_records"`
}

type CreateDomainRequest struct {
	Domain string `json:"domain"`
}

type DomainVerificationResponse struct {
	Domain   string                   `json:"domain"`
	Verified bool                     `json:"verified"`
	Records  []map[string]interface{} `json:"records"`
}

type DomainsListResponse struct {
	Data  []Domain `json:"data"`
	Total int      `json:"total"`
}

// ── Aliases ───────────────────────────────────────────────────────────────────

type Alias struct {
	ID          string `json:"id"`
	Address     string `json:"address"`
	Name        string `json:"name"`
	Destination string `json:"destination"`
	CreatedAt   string `json:"created_at"`
}

type CreateAliasRequest struct {
	Address     string `json:"address"`
	Name        string `json:"name,omitempty"`
	Destination string `json:"destination"`
}

type UpdateAliasRequest struct {
	Name        *string `json:"name,omitempty"`
	Destination *string `json:"destination,omitempty"`
}

type AliasesListResponse struct {
	Data  []Alias `json:"data"`
	Total int     `json:"total"`
}

// ── Dedicated IPs ─────────────────────────────────────────────────────────────

type DedicatedIP struct {
	ID        string `json:"id"`
	IP        string `json:"ip"`
	Pool      string `json:"pool"`
	Status    string `json:"status"`
	CreatedAt string `json:"created_at"`
}

type CreateDedicatedIPRequest struct {
	Pool string `json:"pool"`
}

type UpdateDedicatedIPRequest struct {
	Pool *string `json:"pool,omitempty"`
}

type DedicatedIPsListResponse struct {
	Data  []DedicatedIP `json:"data"`
	Total int           `json:"total"`
}

// ── Channels ──────────────────────────────────────────────────────────────────

type WhatsAppMessage struct {
	To         string            `json:"to"`
	TemplateID string            `json:"template_id"`
	Language   string            `json:"language,omitempty"`
	Variables  map[string]string `json:"variables,omitempty"`
}

type PushNotification struct {
	To    []string          `json:"to"`
	Title string            `json:"title"`
	Body  string            `json:"body"`
	Data  map[string]string `json:"data,omitempty"`
}

// ── A/B Tests ─────────────────────────────────────────────────────────────────

type ABTest struct {
	ID              string                   `json:"id"`
	Name            string                   `json:"name"`
	Status          string                   `json:"status"`
	WinnerVariantID string                   `json:"winner_variant_id"`
	CampaignID      string                   `json:"campaign_id"`
	CreatedAt       string                   `json:"created_at"`
	Variants        []map[string]interface{} `json:"variants"`
}

type CreateABTestRequest struct {
	Name         string                   `json:"name"`
	CampaignID   string                   `json:"campaign_id,omitempty"`
	Variants     []map[string]interface{} `json:"variants"`
	WinCriteria  string                   `json:"win_criteria,omitempty"`
	SplitPercent int                      `json:"split_percent,omitempty"`
}

type ABTestsListResponse struct {
	Data  []ABTest `json:"data"`
	Total int      `json:"total"`
}

// ── Sandbox ───────────────────────────────────────────────────────────────────

type SandboxMessage struct {
	ID         string `json:"id"`
	To         string `json:"to"`
	From       string `json:"from"`
	Subject    string `json:"subject"`
	HTML       string `json:"html"`
	ReceivedAt string `json:"received_at"`
}

type SandboxSendRequest struct {
	From    string `json:"from"`
	To      string `json:"to"`
	Subject string `json:"subject"`
	HTML    string `json:"html,omitempty"`
	Text    string `json:"text,omitempty"`
}

type SandboxListResponse struct {
	Data  []SandboxMessage `json:"data"`
	Total int              `json:"total"`
}

// ── Inbound ───────────────────────────────────────────────────────────────────

type InboundRoute struct {
	ID        string `json:"id"`
	Email     string `json:"email"`
	URL       string `json:"url"`
	Status    string `json:"status"`
	CreatedAt string `json:"created_at"`
}

type CreateInboundRequest struct {
	Email string `json:"email"`
	URL   string `json:"url"`
}

type InboundListResponse struct {
	Data  []InboundRoute `json:"data"`
	Total int            `json:"total"`
}

// ── Analytics ─────────────────────────────────────────────────────────────────

type AnalyticsParams struct {
	StartDate  string `json:"start_date,omitempty"`
	EndDate    string `json:"end_date,omitempty"`
	CampaignID string `json:"campaign_id,omitempty"`
	Interval   string `json:"interval,omitempty"`
}

type AnalyticsOverviewResponse struct {
	Sent         int                      `json:"sent"`
	Delivered    int                      `json:"delivered"`
	Opened       int                      `json:"opened"`
	Clicked      int                      `json:"clicked"`
	Bounced      int                      `json:"bounced"`
	Unsubscribed int                      `json:"unsubscribed"`
	OpenRate     float64                  `json:"open_rate"`
	ClickRate    float64                  `json:"click_rate"`
	Timeline     []map[string]interface{} `json:"timeline"`
}

// ── Tracking ──────────────────────────────────────────────────────────────────

type TrackEventRequest struct {
	Email      string                 `json:"email"`
	Event      string                 `json:"event"`
	Properties map[string]interface{} `json:"properties,omitempty"`
}

type PurchaseItem struct {
	Name     string  `json:"name"`
	Quantity int     `json:"quantity"`
	Price    float64 `json:"price"`
}

type TrackPurchaseRequest struct {
	Email    string         `json:"email"`
	OrderID  string         `json:"order_id"`
	Currency string         `json:"currency"`
	Amount   float64        `json:"amount"`
	Items    []PurchaseItem `json:"items,omitempty"`
}

// ── API Keys ──────────────────────────────────────────────────────────────────

type APIKey struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Prefix    string `json:"prefix"`
	CreatedAt string `json:"created_at"`
	LastUsed  string `json:"last_used,omitempty"`
}

type CreateKeyRequest struct {
	Name string `json:"name"`
}

type CreateKeyResponse struct {
	ID        string `json:"id"`
	Key       string `json:"key"`
	Name      string `json:"name"`
	CreatedAt string `json:"created_at"`
}

type KeysListResponse struct {
	Data  []APIKey `json:"data"`
	Total int      `json:"total"`
}

// ── Validation ────────────────────────────────────────────────────────────────

type ValidateEmailResponse struct {
	Valid       bool    `json:"valid"`
	Disposable  bool    `json:"disposable"`
	MXFound     bool    `json:"mx_found"`
	Score       float64 `json:"score"`
	Suggestion  string  `json:"suggestion"`
}

// ── Leads ─────────────────────────────────────────────────────────────────────

type LeadSearchRequest struct {
	Query    string                 `json:"query"`
	Industry string                 `json:"industry,omitempty"`
	Location string                 `json:"location,omitempty"`
	Limit    int                    `json:"limit,omitempty"`
	Filters  map[string]interface{} `json:"filters,omitempty"`
}

type LeadJob struct {
	ID        string       `json:"id"`
	Status    string       `json:"status"`
	Progress  int          `json:"progress"`
	CreatedAt string       `json:"created_at"`
	Results   []LeadResult `json:"results,omitempty"`
}

type LeadResult struct {
	Email     string                 `json:"email"`
	FirstName string                 `json:"first_name"`
	LastName  string                 `json:"last_name"`
	Company   string                 `json:"company"`
	Title     string                 `json:"title"`
	LinkedIn  string                 `json:"linkedin"`
	Phone     string                 `json:"phone"`
	Score     float64                `json:"score"`
	Data      map[string]interface{} `json:"data,omitempty"`
}

type LeadImportRequest struct {
	JobID  string   `json:"job_id"`
	ListID string   `json:"list_id,omitempty"`
	Tags   []string `json:"tags,omitempty"`
}

type CreditsResponse struct {
	Total     int `json:"total"`
	Used      int `json:"used"`
	Remaining int `json:"remaining"`
}

// ── Autopilot ─────────────────────────────────────────────────────────────────

type AutopilotRequest struct {
	Goal           string                 `json:"goal"`
	Industry       string                 `json:"industry,omitempty"`
	TargetAudience string                 `json:"target_audience,omitempty"`
	DailyLimit     int                    `json:"daily_limit,omitempty"`
	Config         map[string]interface{} `json:"config,omitempty"`
}

type AutopilotSession struct {
	ID        string                 `json:"id"`
	Status    string                 `json:"status"`
	Goal      string                 `json:"goal"`
	CreatedAt string                 `json:"created_at"`
	Stats     map[string]interface{} `json:"stats,omitempty"`
}

type AutopilotDailyPlan struct {
	Date           string                   `json:"date"`
	Actions        []map[string]interface{} `json:"actions"`
	EstimatedReach int                      `json:"estimated_reach"`
}

// ── Sales Agent ───────────────────────────────────────────────────────────────

type SalesAgentConfig struct {
	ID     string                 `json:"id"`
	Name   string                 `json:"name"`
	Active bool                   `json:"active"`
	Config map[string]interface{} `json:"config,omitempty"`
}

type UpdateSalesAgentConfigRequest struct {
	Name   *string                 `json:"name,omitempty"`
	Active *bool                   `json:"active,omitempty"`
	Config map[string]interface{}  `json:"config,omitempty"`
}

type SalesAgentAction struct {
	ID        string                 `json:"id"`
	Type      string                 `json:"type"`
	Status    string                 `json:"status"`
	ContactID string                 `json:"contact_id"`
	CreatedAt string                 `json:"created_at"`
	Data      map[string]interface{} `json:"data,omitempty"`
}

type SalesAgentActionsParams struct {
	Status    string `json:"status,omitempty"`
	ContactID string `json:"contact_id,omitempty"`
	Page      int    `json:"page,omitempty"`
	Limit     int    `json:"limit,omitempty"`
}

// ── CRM ───────────────────────────────────────────────────────────────────────

type CRMConversation struct {
	ID         string `json:"id"`
	Subject    string `json:"subject"`
	Status     string `json:"status"`
	ContactID  string `json:"contact_id"`
	AssignedTo string `json:"assigned_to"`
	CreatedAt  string `json:"created_at"`
	UpdatedAt  string `json:"updated_at"`
}

type CRMMessage struct {
	ID             string `json:"id"`
	ConversationID string `json:"conversation_id"`
	Content        string `json:"content"`
	Direction      string `json:"direction"`
	CreatedAt      string `json:"created_at"`
}

type CRMDeal struct {
	ID        string  `json:"id"`
	Title     string  `json:"title"`
	Stage     string  `json:"stage"`
	Value     float64 `json:"value"`
	Currency  string  `json:"currency"`
	ContactID string  `json:"contact_id"`
	CreatedAt string  `json:"created_at"`
	UpdatedAt string  `json:"updated_at"`
}

type CreateDealRequest struct {
	Title     string  `json:"title"`
	Stage     string  `json:"stage"`
	Currency  string  `json:"currency,omitempty"`
	ContactID string  `json:"contact_id,omitempty"`
	Value     float64 `json:"value"`
}

type UpdateDealRequest struct {
	Title    *string  `json:"title,omitempty"`
	Stage    *string  `json:"stage,omitempty"`
	Currency *string  `json:"currency,omitempty"`
	Value    *float64 `json:"value,omitempty"`
}

type CRMClient struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Email     string `json:"email"`
	Company   string `json:"company"`
	CreatedAt string `json:"created_at"`
}

type CreateClientRequest struct {
	Name    string `json:"name"`
	Email   string `json:"email"`
	Company string `json:"company,omitempty"`
}

type CRMListParams struct {
	Page   int    `json:"page,omitempty"`
	Limit  int    `json:"limit,omitempty"`
	Status string `json:"status,omitempty"`
	Search string `json:"search,omitempty"`
}

// ── Webhooks ──────────────────────────────────────────────────────────────────

type Webhook struct {
	ID        string   `json:"id"`
	URL       string   `json:"url"`
	Events    []string `json:"events"`
	Active    bool     `json:"active"`
	CreatedAt string   `json:"created_at"`
}

type CreateWebhookRequest struct {
	URL    string   `json:"url"`
	Events []string `json:"events"`
}

type UpdateWebhookRequest struct {
	URL    *string   `json:"url,omitempty"`
	Events *[]string `json:"events,omitempty"`
	Active *bool     `json:"active,omitempty"`
}

type WebhooksListResponse struct {
	Data  []Webhook `json:"data"`
	Total int       `json:"total"`
}

// ── Usage ─────────────────────────────────────────────────────────────────────

type UsageParams struct {
	StartDate string `json:"start_date,omitempty"`
	EndDate   string `json:"end_date,omitempty"`
}

type UsageResponse struct {
	Emails      int    `json:"emails"`
	Contacts    int    `json:"contacts"`
	Campaigns   int    `json:"campaigns"`
	APIRequests int    `json:"api_requests"`
	Storage     int64  `json:"storage"`
	Period      string `json:"period"`
}

// ── Billing ───────────────────────────────────────────────────────────────────

type BillingSubscription struct {
	Plan             string  `json:"plan"`
	Status           string  `json:"status"`
	CurrentPeriodEnd string  `json:"current_period_end"`
	Amount           float64 `json:"amount"`
	Currency         string  `json:"currency"`
}

type BillingCheckoutRequest struct {
	Plan       string `json:"plan"`
	SuccessURL string `json:"success_url"`
	CancelURL  string `json:"cancel_url"`
}

type BillingCheckoutResponse struct {
	URL string `json:"url"`
}

// ── Workspaces ────────────────────────────────────────────────────────────────

type Workspace struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Plan      string `json:"plan"`
	OwnerID   string `json:"owner_id"`
	CreatedAt string `json:"created_at"`
}

type CreateWorkspaceRequest struct {
	Name string `json:"name"`
	Plan string `json:"plan,omitempty"`
}

type UpdateWorkspaceRequest struct {
	Name *string `json:"name,omitempty"`
}

type WorkspacesListResponse struct {
	Data  []Workspace `json:"data"`
	Total int         `json:"total"`
}

type WorkspaceMember struct {
	UserID   string `json:"user_id"`
	Email    string `json:"email"`
	Role     string `json:"role"`
	JoinedAt string `json:"joined_at"`
}

type InviteMemberRequest struct {
	Email string `json:"email"`
	Role  string `json:"role"`
}

type UpdateMemberRequest struct {
	Role *string `json:"role,omitempty"`
}

// ── Errors ────────────────────────────────────────────────────────────────────

type APIError struct {
	Status  int    `json:"status"`
	Message string `json:"message"`
}

func (e *APIError) Error() string {
	return fmt.Sprintf("misarmail: API error %d: %s", e.Status, e.Message)
}

type NetworkError struct {
	Message string `json:"message"`
	Cause   error  `json:"-"`
}

func (e *NetworkError) Error() string { return fmt.Sprintf("misarmail: network error: %s", e.Message) }
func (e *NetworkError) Unwrap() error { return e.Cause }
