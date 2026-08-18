pub mod errors;

pub mod streaming;
pub use streaming::{EventStream, StreamEvent};

use std::sync::Arc;
use std::time::Duration;

use reqwest::{Client as HttpClient, Method};
use serde_json::{json, Value};
use tokio::time::sleep;

pub use errors::MisarMailError;

// ── Constants ─────────────────────────────────────────────────────────────────

const DEFAULT_BASE_URL: &str = "https://api.misar.io/mail/v1";
const DEFAULT_API_BASE: &str = "https://api.misar.io/mail";
const DEFAULT_MAX_RETRIES: u32 = 3;
const RETRY_BASE_MS: u64 = 200;
static RETRYABLE: &[u16] = &[429, 500, 502, 503, 504];

// ── Inner ─────────────────────────────────────────────────────────────────────

struct Inner {
    api_key: String,
    base_url: String,
    api_base: String,
    http: HttpClient,
    max_retries: u32,
}


/// The plan-refusal signal the API sets alongside a 402/429 body.
#[derive(Default)]
struct PlanHeaders {
    plan: Option<String>,
    upgrade_url: Option<String>,
    retry_after: Option<u64>,
}

impl PlanHeaders {
    fn from(h: &reqwest::header::HeaderMap) -> Self {
        let get = |k: &str| h.get(k).and_then(|v| v.to_str().ok()).map(str::to_owned);
        Self {
            plan: get("x-misar-plan"),
            upgrade_url: get("x-misar-upgrade-url"),
            retry_after: get("retry-after").and_then(|v| v.parse().ok()),
        }
    }
}

/// True when the error envelope carries the API's plan-refusal marker.
fn is_plan_limit(text: &str) -> bool {
    let Ok(v) = serde_json::from_str::<Value>(text) else { return false };
    v.get("code").and_then(Value::as_str) == Some("plan_limit_exceeded")
        || v.get("error_type").and_then(Value::as_str) == Some("plan_limit_exceeded")
        || v.get("upgrade").is_some_and(|u| u.is_object())
}

fn parse_plan_limit(status: u16, text: &str, hdrs: &PlanHeaders) -> MisarMailError {
    let body: Value = serde_json::from_str(text).unwrap_or(Value::Null);
    let s = |p: &str| body.pointer(p).and_then(Value::as_str).map(str::to_owned);

    // Headers are authoritative; the offer body is the fallback when a proxy
    // has stripped them.
    MisarMailError::PlanLimit {
        status,
        message: body.get("error").and_then(Value::as_str)
            .unwrap_or("plan limit exceeded").to_owned(),
        plan: hdrs.plan.clone()
            .or_else(|| s("/upgrade/currentPlanSlug"))
            .or_else(|| s("/upgrade/current_plan/slug")),
        upgrade_url: hdrs.upgrade_url.clone().or_else(|| s("/upgrade/urls/pricing")),
        retry_after: hdrs.retry_after,
        feature: s("/upgrade/feature"),
    }
}

impl Inner {
    fn new(api_key: &str, base_url: &str, api_base: &str, max_retries: u32) -> Self {
        Self {
            api_key: api_key.to_owned(),
            base_url: base_url.trim_end_matches('/').to_owned(),
            api_base: api_base.trim_end_matches('/').to_owned(),
            http: HttpClient::builder()
                .timeout(Duration::from_secs(30))
                .build()
                .expect("failed to build HTTP client"),
            max_retries,
        }
    }

    async fn request(
        &self,
        method: Method,
        path: &str,
        body: Option<Value>,
        use_api_base: bool,
    ) -> Result<Value, MisarMailError> {
        let root = if use_api_base { &self.api_base } else { &self.base_url };
        let url = format!("{}{}", root, path);
        let mut last_err: Option<MisarMailError> = None;

        for attempt in 0..self.max_retries {
            if let Some(prev) = last_err.take() {
                // only propagate on last attempt
                if attempt == self.max_retries - 1 {
                    return Err(prev);
                }
            }

            let mut req = self
                .http
                .request(method.clone(), &url)
                .header("Authorization", format!("Bearer {}", self.api_key))
                .header("Content-Type", "application/json");

            if let Some(ref b) = body {
                req = req.json(b);
            }

            match req.send().await {
                Err(e) => {
                    last_err = Some(MisarMailError::Network(e));
                    if attempt < self.max_retries - 1 {
                        sleep(Duration::from_millis(RETRY_BASE_MS * (1 << attempt))).await;
                    }
                }
                Ok(resp) => {
                    let status = resp.status();
                    let status_u16 = status.as_u16();

                    if status_u16 == 204 {
                        return Ok(Value::Null);
                    }

                    // Headers must be lifted out before `.text()` consumes the
                    // response — the plan-refusal offer arrives in both.
                    let hdrs = PlanHeaders::from(resp.headers());
                    let text = resp.text().await.unwrap_or_default();

                    // A rate-limit 429 and a spent-allowance 429 are identical
                    // by status, so the body decides. Only the first is worth
                    // retrying.
                    if is_plan_limit(&text) {
                        return Err(parse_plan_limit(status_u16, &text, &hdrs));
                    }

                    if RETRYABLE.contains(&status_u16) && attempt < self.max_retries - 1 {
                        last_err = Some(MisarMailError::Api {
                            status: status_u16,
                            message: status.to_string(),
                        });
                        sleep(Duration::from_millis(RETRY_BASE_MS * (1 << attempt))).await;
                        continue;
                    }

                    if !status.is_success() {
                        let message = serde_json::from_str::<Value>(&text)
                            .ok()
                            .and_then(|v| {
                                v.get("message")
                                    .or_else(|| v.get("error"))
                                    .and_then(|m| m.as_str())
                                    .map(str::to_owned)
                            })
                            .unwrap_or_else(|| text.clone());
                        return Err(MisarMailError::Api { status: status_u16, message });
                    }

                    return serde_json::from_str(&text).map_err(MisarMailError::Json);
                }
            }
        }

        Err(last_err.unwrap_or(MisarMailError::Api {
            status: 0,
            message: "max retries exceeded".to_owned(),
        }))
    }

    async fn get_with_params(
        &self,
        path: &str,
        params: Value,
        use_api_base: bool,
    ) -> Result<Value, MisarMailError> {
        let root = if use_api_base { &self.api_base } else { &self.base_url };
        let url = format!("{}{}", root, path);

        // Convert Value object to Vec<(String, String)> for query params
        let query_pairs: Vec<(String, String)> = if let Some(obj) = params.as_object() {
            obj.iter()
                .filter_map(|(k, v)| {
                    let val = match v {
                        Value::String(s) => Some(s.clone()),
                        Value::Number(n) => Some(n.to_string()),
                        Value::Bool(b) => Some(b.to_string()),
                        _ => None,
                    };
                    val.map(|v| (k.clone(), v))
                })
                .collect()
        } else {
            vec![]
        };

        let mut last_err: Option<MisarMailError> = None;

        for attempt in 0..self.max_retries {
            if let Some(prev) = last_err.take() {
                if attempt == self.max_retries - 1 {
                    return Err(prev);
                }
            }

            let req = self
                .http
                .get(&url)
                .header("Authorization", format!("Bearer {}", self.api_key))
                .query(&query_pairs);

            match req.send().await {
                Err(e) => {
                    last_err = Some(MisarMailError::Network(e));
                    if attempt < self.max_retries - 1 {
                        sleep(Duration::from_millis(RETRY_BASE_MS * (1 << attempt))).await;
                    }
                }
                Ok(resp) => {
                    let status = resp.status();
                    let status_u16 = status.as_u16();

                    if status_u16 == 204 {
                        return Ok(Value::Null);
                    }

                    // Headers must be lifted out before `.text()` consumes the
                    // response — the plan-refusal offer arrives in both.
                    let hdrs = PlanHeaders::from(resp.headers());
                    let text = resp.text().await.unwrap_or_default();

                    // A rate-limit 429 and a spent-allowance 429 are identical
                    // by status, so the body decides. Only the first is worth
                    // retrying.
                    if is_plan_limit(&text) {
                        return Err(parse_plan_limit(status_u16, &text, &hdrs));
                    }

                    if RETRYABLE.contains(&status_u16) && attempt < self.max_retries - 1 {
                        last_err = Some(MisarMailError::Api {
                            status: status_u16,
                            message: status.to_string(),
                        });
                        sleep(Duration::from_millis(RETRY_BASE_MS * (1 << attempt))).await;
                        continue;
                    }

                    if !status.is_success() {
                        let message = serde_json::from_str::<Value>(&text)
                            .ok()
                            .and_then(|v| {
                                v.get("message")
                                    .or_else(|| v.get("error"))
                                    .and_then(|m| m.as_str())
                                    .map(str::to_owned)
                            })
                            .unwrap_or_else(|| text.clone());
                        return Err(MisarMailError::Api { status: status_u16, message });
                    }

                    return serde_json::from_str(&text).map_err(MisarMailError::Json);
                }
            }
        }

        Err(last_err.unwrap_or(MisarMailError::Api {
            status: 0,
            message: "max retries exceeded".to_owned(),
        }))
    }
}

// ── Client ────────────────────────────────────────────────────────────────────

// Aliases and Workspaces are intentionally absent: both are served only off
// /api, and every one of their routes imports supabase/server and authenticates
// with a cookie session — no dual-auth, no verify_api_key — so an msk_ key can
// never call them. Restore from git history if that changes.
pub struct MisarMailClient {
    pub plan: PlanResource,
    pub streaming: StreamingResource,
    pub ai: AiResource,
    pub credit_rates: CreditRatesResource,
    pub deliverability: DeliverabilityResource,
    pub dmarc: DmarcResource,
    pub email_accounts: EmailAccountsResource,
    pub emails: EmailsResource,
    pub landing_pages: LandingPagesResource,
    pub monetization: MonetizationResource,
    pub revenue: RevenueResource,
    pub segments: SegmentsResource,
    pub subscription: SubscriptionResource,
    pub team_members: TeamMembersResource,
    pub wallet: WalletResource,
    pub warmup: WarmupResource,
    pub email: EmailResource,
    pub contacts: ContactsResource,
    pub campaigns: CampaignsResource,
    pub templates: TemplatesResource,
    pub automations: AutomationsResource,
    pub domains: DomainsResource,
    pub dedicated_ips: DedicatedIpsResource,
    pub ab_tests: AbTestsResource,
    pub sandbox: SandboxResource,
    pub inbound: InboundResource,
    pub analytics: AnalyticsResource,
    pub track: TrackResource,
    pub keys: KeysResource,
    pub validate: ValidateResource,
    pub webhooks: WebhooksResource,
    pub usage: UsageResource,
    pub billing: BillingResource,
}

impl MisarMailClient {
    pub fn new(api_key: &str) -> Self {
        Self::build(api_key, DEFAULT_BASE_URL, DEFAULT_API_BASE, DEFAULT_MAX_RETRIES)
    }

    pub fn with_base_url(self, url: &str) -> Self {
        let inner = &self.email.0;
        Self::build(&inner.api_key, url, &inner.api_base.clone(), inner.max_retries)
    }

    /// Override the API base — the host serving routes outside `/v1`, which is
    /// where both streaming endpoints live.
    pub fn with_api_base(self, url: &str) -> Self {
        let inner = &self.email.0;
        Self::build(&inner.api_key, &inner.base_url.clone(), url, inner.max_retries)
    }

    pub fn with_max_retries(self, n: u32) -> Self {
        let inner = &self.email.0;
        Self::build(&inner.api_key, &inner.base_url.clone(), &inner.api_base.clone(), n)
    }

    fn build(api_key: &str, base_url: &str, api_base: &str, max_retries: u32) -> Self {
        let inner = Arc::new(Inner::new(api_key, base_url, api_base, max_retries));
        Self {
            plan: PlanResource(Arc::clone(&inner)),
            streaming: StreamingResource(Arc::clone(&inner)),
            ai: AiResource(Arc::clone(&inner)),
            credit_rates: CreditRatesResource(Arc::clone(&inner)),
            deliverability: DeliverabilityResource(Arc::clone(&inner)),
            dmarc: DmarcResource(Arc::clone(&inner)),
            email_accounts: EmailAccountsResource(Arc::clone(&inner)),
            emails: EmailsResource(Arc::clone(&inner)),
            landing_pages: LandingPagesResource(Arc::clone(&inner)),
            monetization: MonetizationResource(Arc::clone(&inner)),
            revenue: RevenueResource(Arc::clone(&inner)),
            segments: SegmentsResource(Arc::clone(&inner)),
            subscription: SubscriptionResource(Arc::clone(&inner)),
            team_members: TeamMembersResource(Arc::clone(&inner)),
            wallet: WalletResource(Arc::clone(&inner)),
            warmup: WarmupResource(Arc::clone(&inner)),
            email: EmailResource(Arc::clone(&inner)),
            contacts: ContactsResource(Arc::clone(&inner)),
            campaigns: CampaignsResource(Arc::clone(&inner)),
            templates: TemplatesResource(Arc::clone(&inner)),
            automations: AutomationsResource(Arc::clone(&inner)),
            domains: DomainsResource(Arc::clone(&inner)),
            dedicated_ips: DedicatedIpsResource(Arc::clone(&inner)),
            ab_tests: AbTestsResource(Arc::clone(&inner)),
            sandbox: SandboxResource(Arc::clone(&inner)),
            inbound: InboundResource(Arc::clone(&inner)),
            analytics: AnalyticsResource(Arc::clone(&inner)),
            track: TrackResource(Arc::clone(&inner)),
            keys: KeysResource(Arc::clone(&inner)),
            validate: ValidateResource(Arc::clone(&inner)),
            webhooks: WebhooksResource(Arc::clone(&inner)),
            usage: UsageResource(Arc::clone(&inner)),
            billing: BillingResource(Arc::clone(&inner)),
        }
    }
}

// ── Resource: Email ───────────────────────────────────────────────────────────

pub struct EmailResource(Arc<Inner>);

impl EmailResource {
    pub async fn send(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/send", Some(data), false).await
    }
}

// ── Resource: Contacts ────────────────────────────────────────────────────────

pub struct ContactsResource(Arc<Inner>);

impl ContactsResource {
    pub async fn list(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/contacts", params, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/contacts", Some(data), false).await
    }

    /// `GET /contacts?id=<uuid>` — the id is a query parameter, not a path
    /// segment: /v1/contacts has no dynamic route.
    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/contacts?id={}", urlencoding::encode(id)), Value::Null, false).await
    }

    /// `PATCH /contacts` — the contact is identified by `email` in the body, not
    /// by an id and not by a path segment. The route's schema requires a valid
    /// email address, so an id would fail validation even if the path resolved.
    pub async fn update(&self, email: &str, data: Value) -> Result<Value, MisarMailError> {
        let mut body = data;
        if let Some(map) = body.as_object_mut() {
            map.insert("email".to_owned(), Value::String(email.to_owned()));
        } else {
            body = serde_json::json!({ "email": email });
        }
        self.0.request(Method::PATCH, "/contacts", Some(body), false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/contacts?id={}", urlencoding::encode(id)), None, false).await
    }

    pub async fn import_contacts(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/contacts/import", Some(data), false).await
    }
}

// ── Resource: Campaigns ───────────────────────────────────────────────────────

pub struct CampaignsResource(Arc<Inner>);

impl CampaignsResource {
    pub async fn list(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/campaigns", params, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/campaigns", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/campaigns/{}", id), Value::Null, false).await
    }

    pub async fn update(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/campaigns/{}", id), Some(data), false).await
    }

    pub async fn send_campaign(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, &format!("/campaigns/{}/send", id), None, false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/campaigns/{}", id), None, false).await
    }
}

// ── Resource: Templates ───────────────────────────────────────────────────────

pub struct TemplatesResource(Arc<Inner>);

impl TemplatesResource {
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/templates", Value::Null, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/templates", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/templates/{}", id), Value::Null, false).await
    }

    pub async fn update(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/templates/{}", id), Some(data), false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/templates/{}", id), None, false).await
    }

    pub async fn render(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/templates/render", Some(data), false).await
    }
}

// ── Resource: Automations ─────────────────────────────────────────────────────

pub struct AutomationsResource(Arc<Inner>);

impl AutomationsResource {
    pub async fn list(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/automations", params, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/automations", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/automations/{}", id), Value::Null, false).await
    }

    pub async fn update(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/automations/{}", id), Some(data), false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/automations/{}", id), None, false).await
    }

    pub async fn activate(&self, id: &str, active: bool) -> Result<Value, MisarMailError> {
        self.0
            .request(
                Method::PATCH,
                &format!("/automations/{}/activate", id),
                Some(json!({ "active": active })),
                false,
            )
            .await
    }
}

// ── Resource: Domains ─────────────────────────────────────────────────────────

pub struct DomainsResource(Arc<Inner>);

impl DomainsResource {
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/domains", Value::Null, true).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/domains", Some(data), true).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/domains/{}", id), Value::Null, true).await
    }

    pub async fn verify(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, &format!("/domains/{}/verify", id), None, true).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/domains/{}", id), None, true).await
    }
}

// ── Resource: Aliases ─────────────────────────────────────────────────────────



// ── Resource: Dedicated IPs ───────────────────────────────────────────────────

pub struct DedicatedIpsResource(Arc<Inner>);

impl DedicatedIpsResource {
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/dedicated-ips", Value::Null, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/dedicated-ips", Some(data), false).await
    }

    pub async fn update(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/dedicated-ips/{}", id), Some(data), false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/dedicated-ips/{}", id), None, false).await
    }
}


// ── Resource: A/B Tests ───────────────────────────────────────────────────────

pub struct AbTestsResource(Arc<Inner>);

impl AbTestsResource {
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/ab-tests", Value::Null, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/ab-tests", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/ab-tests/{}", id), Value::Null, false).await
    }

    pub async fn set_winner(&self, id: &str, variant_id: &str) -> Result<Value, MisarMailError> {
        self.0
            .request(
                Method::POST,
                &format!("/ab-tests/{}/winner", id),
                Some(json!({ "variant_id": variant_id })),
                false,
            )
            .await
    }
}

// ── Resource: Sandbox ─────────────────────────────────────────────────────────

pub struct SandboxResource(Arc<Inner>);

impl SandboxResource {
    pub async fn send(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/sandbox/send", Some(data), false).await
    }

    pub async fn list(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/sandbox", params, false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/sandbox/{}", id), None, false).await
    }
}

// ── Resource: Inbound ─────────────────────────────────────────────────────────

pub struct InboundResource(Arc<Inner>);

impl InboundResource {
    pub async fn list(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/inbound", params, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/inbound", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/inbound/{}", id), Value::Null, false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/inbound/{}", id), None, false).await
    }
}

// ── Resource: Analytics ───────────────────────────────────────────────────────

pub struct AnalyticsResource(Arc<Inner>);

impl AnalyticsResource {
    pub async fn overview(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/analytics", params, false).await
    }
}

// ── Resource: Track ───────────────────────────────────────────────────────────

pub struct TrackResource(Arc<Inner>);

impl TrackResource {
    pub async fn event(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/track/event", Some(data), false).await
    }

    pub async fn purchase(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/track/purchase", Some(data), false).await
    }
}

// ── Resource: Keys ────────────────────────────────────────────────────────────

pub struct KeysResource(Arc<Inner>);

impl KeysResource {
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/keys", Value::Null, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/keys", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/keys/{}", id), Value::Null, false).await
    }

    pub async fn revoke(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/keys/{}", id), None, false).await
    }
}

// ── Resource: Validate ────────────────────────────────────────────────────────

pub struct ValidateResource(Arc<Inner>);

impl ValidateResource {
    /// `POST /validate` — verify one address, spending a validation credit.
    ///
    /// The address goes in the **body** as `email`. This used to issue
    /// `GET /validate?address=…`, which is a different endpoint entirely — GET
    /// returns the wallet credit balance and ignores the query string, so the
    /// call never verified anything.
    pub async fn email(&self, address: &str) -> Result<Value, MisarMailError> {
        self.0
            .request(Method::POST, "/validate", Some(json!({ "email": address })), false)
            .await
    }

    /// `GET /validate` — remaining validation credits.
    pub async fn balance(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/validate", None, false).await
    }
}

// ── Resource: Webhooks ────────────────────────────────────────────────────────

pub struct WebhooksResource(Arc<Inner>);

impl WebhooksResource {
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/webhooks", Value::Null, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/webhooks", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/webhooks/{}", id), Value::Null, false).await
    }

    pub async fn update(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/webhooks/{}", id), Some(data), false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/webhooks/{}", id), None, false).await
    }

    pub async fn test(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, &format!("/webhooks/{}/test", id), None, false).await
    }
}

// ── Resource: Usage ───────────────────────────────────────────────────────────

pub struct UsageResource(Arc<Inner>);

impl UsageResource {
    pub async fn get(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/usage", params, false).await
    }
}

// ── Resource: Billing ─────────────────────────────────────────────────────────

pub struct BillingResource(Arc<Inner>);

impl BillingResource {
    pub async fn subscription(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/billing/subscription", Value::Null, true).await
    }

    pub async fn checkout(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/billing/checkout", Some(data), true).await
    }
}

// ── Resource: Workspaces ──────────────────────────────────────────────────────



// ── Plan ────────────────────────────────────────────────────────────────────

/// Live subscription standing for the key's owner.
///
/// Read this before an expensive call rather than discovering the ceiling
/// through [`MisarMailError::PlanLimit`]: `usage` reports every metered feature
/// and `upgrade` is non-null as soon as one of them is spent.
pub struct PlanResource(Arc<Inner>);

impl PlanResource {
    /// `GET /plan` — plan, sending allowances, per-feature usage, upgrade offer.
    pub async fn get(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/plan", None, false).await
    }

    /// `GET /monetization/stats` — revenue and monetization counters.
    pub async fn monetization(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/monetization/stats", None, false).await
    }
}

// ── Generated from scripts/sdk-endpoint-spec.json ────────────────────────────
//
// These twenty endpoints were missing from every SDK except TypeScript. The
// spec is derived from the route handlers, so this stays in step with the API.

/// Appends `?a=b&c=d` for the pairs that are set, or nothing when none are.
fn qs(pairs: &[(&str, Option<&str>)]) -> String {
    let set: Vec<String> = pairs
        .iter()
        .filter_map(|(k, v)| v.map(|v| format!("{k}={}", urlencoding::encode(v))))
        .collect();
    if set.is_empty() {
        String::new()
    } else {
        format!("?{}", set.join("&"))
    }
}

/// `ai` — generated.
pub struct AiResource(Arc<Inner>);

impl AiResource {
    /// `POST /ai/subject-lines`
    pub async fn subject_lines(&self, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/ai/subject-lines", Some(body), false).await
    }

}

/// `creditRates` — generated.
pub struct CreditRatesResource(Arc<Inner>);

impl CreditRatesResource {
    /// `GET /credit-rates`
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/credit-rates", None, false).await
    }

}

/// `deliverability` — generated.
pub struct DeliverabilityResource(Arc<Inner>);

impl DeliverabilityResource {
    /// `GET /deliverability/audit`
    pub async fn audit(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/deliverability/audit", None, false).await
    }

    /// `GET /deliverability/score`
    pub async fn score(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/deliverability/score", None, false).await
    }

}

/// `dmarc` — generated.
pub struct DmarcResource(Arc<Inner>);

impl DmarcResource {
    /// `GET /dmarc/check`
    pub async fn check(&self, domain: Option<&str>, dkim_selector: Option<&str>) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, &("/dmarc/check".to_string() + &qs(&[("domain", domain), ("dkim_selector", dkim_selector)])), None, false).await
    }

    /// `GET /dmarc/domains`
    pub async fn list_domains(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/dmarc/domains", None, false).await
    }

    /// `POST /dmarc/domains`
    pub async fn add_domain(&self, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/dmarc/domains", Some(body), false).await
    }

    /// `DELETE /dmarc/domains`
    pub async fn remove_domain(&self, domain_id: Option<&str>) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &("/dmarc/domains".to_string() + &qs(&[("domain_id", domain_id)])), None, false).await
    }

}

/// `emailAccounts` — generated.
pub struct EmailAccountsResource(Arc<Inner>);

impl EmailAccountsResource {
    /// `GET /email-accounts`
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/email-accounts", None, false).await
    }

}

/// `emails` — generated.
pub struct EmailsResource(Arc<Inner>);

impl EmailsResource {
    /// `GET /emails`
    pub async fn list(&self, folder: Option<&str>, search: Option<&str>, limit: Option<&str>) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, &("/emails".to_string() + &qs(&[("folder", folder), ("search", search), ("limit", limit)])), None, false).await
    }

    /// `GET /emails/:id`
    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, &(format!("/emails/{id}")), None, false).await
    }

    /// `PATCH /emails/:id`
    pub async fn update(&self, id: &str, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &(format!("/emails/{id}")), Some(body), false).await
    }

}

/// `landingPages` — generated.
pub struct LandingPagesResource(Arc<Inner>);

impl LandingPagesResource {
    /// `POST /landing-pages`
    pub async fn create(&self, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/landing-pages", Some(body), false).await
    }

}

/// `monetization` — generated.
pub struct MonetizationResource(Arc<Inner>);

impl MonetizationResource {
    /// `POST /monetization/tip`
    pub async fn tip(&self, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/monetization/tip", Some(body), false).await
    }

}

impl PlanResource {
    /// `GET /plan-limits`
    pub async fn limits(&self, product: Option<&str>) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, &("/plan-limits".to_string() + &qs(&[("product", product)])), None, false).await
    }

}

/// `revenue` — generated.
pub struct RevenueResource(Arc<Inner>);

impl RevenueResource {
    /// `GET /revenue/attribution`
    pub async fn attribution(&self, campaign_id: Option<&str>, period: Option<&str>) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, &("/revenue/attribution".to_string() + &qs(&[("campaign_id", campaign_id), ("period", period)])), None, false).await
    }

}

/// `segments` — generated.
pub struct SegmentsResource(Arc<Inner>);

impl SegmentsResource {
    /// `GET /segments/:id/members`
    pub async fn members(&self, id: &str, page: Option<&str>, limit: Option<&str>) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, &(format!("/segments/{id}/members") + &qs(&[("page", page), ("limit", limit)])), None, false).await
    }

}

/// `subscription` — generated.
pub struct SubscriptionResource(Arc<Inner>);

impl SubscriptionResource {
    /// `GET /subscription`
    pub async fn get(&self, product: Option<&str>) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, &("/subscription".to_string() + &qs(&[("product", product)])), None, false).await
    }

    /// `POST /subscription`
    pub async fn upsert(&self, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/subscription", Some(body), false).await
    }

    /// `DELETE /subscription`
    pub async fn cancel(&self, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, "/subscription", Some(body), false).await
    }

}

/// `teamMembers` — generated.
pub struct TeamMembersResource(Arc<Inner>);

impl TeamMembersResource {
    /// `GET /team-members`
    pub async fn get(&self, owner_id: Option<&str>) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, &("/team-members".to_string() + &qs(&[("owner_id", owner_id)])), None, false).await
    }

}

/// `wallet` — generated.
pub struct WalletResource(Arc<Inner>);

impl WalletResource {
    /// `GET /wallet`
    pub async fn get(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/wallet", None, false).await
    }

    /// `POST /wallet/credit`
    pub async fn credit(&self, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/wallet/credit", Some(body), false).await
    }

    /// `POST /wallet/debit`
    pub async fn debit(&self, body: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/wallet/debit", Some(body), false).await
    }

}

/// `warmup` — generated.
pub struct WarmupResource(Arc<Inner>);

impl WarmupResource {
    /// `GET /warmup`
    pub async fn get(&self) -> Result<Value, MisarMailError> {
        self.0.request(Method::GET, "/warmup", None, false).await
    }

}

// ── Streaming ───────────────────────────────────────────────────────────────

impl Inner {
    /// Opens an SSE connection against the API base and returns decoded frames.
    ///
    /// Both streaming routes sit outside `/v1`, so this uses `api_base`. A plan
    /// refusal on open surfaces as `MisarMailError::PlanLimit`, exactly as it
    /// does for a non-streaming call.
    async fn sse(
        &self,
        method: Method,
        path: &str,
        body: Option<Value>,
    ) -> Result<EventStream, MisarMailError> {
        let url = format!("{}{}", self.api_base, path);
        let mut req = self
            .http
            .request(method, &url)
            .header("Authorization", format!("Bearer {}", self.api_key))
            .header("Accept", "text/event-stream");
        if let Some(b) = body {
            req = req.json(&b);
        }

        let resp = req.send().await.map_err(MisarMailError::Network)?;
        let status = resp.status().as_u16();

        if !resp.status().is_success() {
            let hdrs = PlanHeaders::from(resp.headers());
            let text = resp.text().await.unwrap_or_default();
            if is_plan_limit(&text) {
                return Err(parse_plan_limit(status, &text, &hdrs));
            }
            let message = serde_json::from_str::<Value>(&text)
                .ok()
                .and_then(|v| {
                    v.get("error")
                        .or_else(|| v.get("message"))
                        .and_then(|m| m.as_str())
                        .map(str::to_owned)
                })
                .unwrap_or_else(|| if text.is_empty() { "stream error".into() } else { text.clone() });
            return Err(MisarMailError::Api { status, message });
        }

        Ok(streaming::frames_from(resp))
    }
}

/// The two Server-Sent Events endpoints.
pub struct StreamingResource(Arc<Inner>);

impl StreamingResource {
    /// `POST /api/ai/generate-email/stream` — token-by-token generation.
    ///
    /// ```no_run
    /// # use futures_util::StreamExt;
    /// # async fn demo(mail: misarmail::MisarMailClient) -> Result<(), misarmail::MisarMailError> {
    /// let mut stream = mail.streaming.generate_email(serde_json::json!({"prompt": "…"})).await?;
    /// while let Some(frame) = stream.next().await {
    ///     let frame = frame?;
    ///     print!("{}", frame.data["delta"].as_str().unwrap_or(""));
    /// }
    /// # Ok(()) }
    /// ```
    pub async fn generate_email(
        &self,
        options: Value,
    ) -> Result<EventStream, MisarMailError> {
        self.0
            .sse(Method::POST, "/ai/generate-email/stream", Some(options))
            .await
    }

    /// `GET /api/campaigns/{id}/send-stream` — live send progress.
    pub async fn campaign_send(
        &self,
        campaign_id: &str,
    ) -> Result<EventStream, MisarMailError> {
        let path = format!(
            "/campaigns/{}/send-stream",
            urlencoding::encode(campaign_id)
        );
        self.0.sse(Method::GET, &path, None).await
    }
}
