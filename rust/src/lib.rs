pub mod errors;

use std::sync::Arc;
use std::time::Duration;

use reqwest::{Client as HttpClient, Method};
use serde_json::{json, Value};
use tokio::time::sleep;

pub use errors::MisarMailError;

// ── Constants ─────────────────────────────────────────────────────────────────

const DEFAULT_BASE_URL: &str = "https://mail.misar.io/api/v1";
const DEFAULT_API_BASE: &str = "https://mail.misar.io/api";
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

                    if RETRYABLE.contains(&status_u16) && attempt < self.max_retries - 1 {
                        last_err = Some(MisarMailError::Api {
                            status: status_u16,
                            message: status.to_string(),
                        });
                        sleep(Duration::from_millis(RETRY_BASE_MS * (1 << attempt))).await;
                        continue;
                    }

                    if status_u16 == 204 {
                        return Ok(Value::Null);
                    }

                    let text = resp.text().await.unwrap_or_default();

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

                    if RETRYABLE.contains(&status_u16) && attempt < self.max_retries - 1 {
                        last_err = Some(MisarMailError::Api {
                            status: status_u16,
                            message: status.to_string(),
                        });
                        sleep(Duration::from_millis(RETRY_BASE_MS * (1 << attempt))).await;
                        continue;
                    }

                    if status_u16 == 204 {
                        return Ok(Value::Null);
                    }

                    let text = resp.text().await.unwrap_or_default();

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

pub struct MisarMailClient {
    pub email: EmailResource,
    pub contacts: ContactsResource,
    pub campaigns: CampaignsResource,
    pub templates: TemplatesResource,
    pub automations: AutomationsResource,
    pub domains: DomainsResource,
    pub aliases: AliasesResource,
    pub dedicated_ips: DedicatedIpsResource,
    pub channels: ChannelsResource,
    pub ab_tests: AbTestsResource,
    pub sandbox: SandboxResource,
    pub inbound: InboundResource,
    pub analytics: AnalyticsResource,
    pub track: TrackResource,
    pub keys: KeysResource,
    pub validate: ValidateResource,
    pub leads: LeadsResource,
    pub autopilot: AutopilotResource,
    pub sales_agent: SalesAgentResource,
    pub crm: CrmResource,
    pub webhooks: WebhooksResource,
    pub usage: UsageResource,
    pub billing: BillingResource,
    pub workspaces: WorkspacesResource,
}

impl MisarMailClient {
    pub fn new(api_key: &str) -> Self {
        Self::build(api_key, DEFAULT_BASE_URL, DEFAULT_API_BASE, DEFAULT_MAX_RETRIES)
    }

    pub fn with_base_url(self, url: &str) -> Self {
        let inner = &self.email.0;
        Self::build(&inner.api_key, url, &inner.api_base.clone(), inner.max_retries)
    }

    pub fn with_max_retries(self, n: u32) -> Self {
        let inner = &self.email.0;
        Self::build(&inner.api_key, &inner.base_url.clone(), &inner.api_base.clone(), n)
    }

    fn build(api_key: &str, base_url: &str, api_base: &str, max_retries: u32) -> Self {
        let inner = Arc::new(Inner::new(api_key, base_url, api_base, max_retries));
        Self {
            email: EmailResource(Arc::clone(&inner)),
            contacts: ContactsResource(Arc::clone(&inner)),
            campaigns: CampaignsResource(Arc::clone(&inner)),
            templates: TemplatesResource(Arc::clone(&inner)),
            automations: AutomationsResource(Arc::clone(&inner)),
            domains: DomainsResource(Arc::clone(&inner)),
            aliases: AliasesResource(Arc::clone(&inner)),
            dedicated_ips: DedicatedIpsResource(Arc::clone(&inner)),
            channels: ChannelsResource(Arc::clone(&inner)),
            ab_tests: AbTestsResource(Arc::clone(&inner)),
            sandbox: SandboxResource(Arc::clone(&inner)),
            inbound: InboundResource(Arc::clone(&inner)),
            analytics: AnalyticsResource(Arc::clone(&inner)),
            track: TrackResource(Arc::clone(&inner)),
            keys: KeysResource(Arc::clone(&inner)),
            validate: ValidateResource(Arc::clone(&inner)),
            leads: LeadsResource(Arc::clone(&inner)),
            autopilot: AutopilotResource(Arc::clone(&inner)),
            sales_agent: SalesAgentResource(Arc::clone(&inner)),
            crm: CrmResource(Arc::clone(&inner)),
            webhooks: WebhooksResource(Arc::clone(&inner)),
            usage: UsageResource(Arc::clone(&inner)),
            billing: BillingResource(Arc::clone(&inner)),
            workspaces: WorkspacesResource(Arc::clone(&inner)),
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

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/contacts/{}", id), Value::Null, false).await
    }

    pub async fn update(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/contacts/{}", id), Some(data), false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/contacts/{}", id), None, false).await
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
        self.0.get_with_params("/domains", Value::Null, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/domains", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/domains/{}", id), Value::Null, false).await
    }

    pub async fn verify(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, &format!("/domains/{}/verify", id), None, false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/domains/{}", id), None, false).await
    }
}

// ── Resource: Aliases ─────────────────────────────────────────────────────────

pub struct AliasesResource(Arc<Inner>);

impl AliasesResource {
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/aliases", Value::Null, false).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/aliases", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/aliases/{}", id), Value::Null, false).await
    }

    pub async fn update(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/aliases/{}", id), Some(data), false).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/aliases/{}", id), None, false).await
    }
}

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

// ── Resource: Channels ────────────────────────────────────────────────────────

pub struct ChannelsResource(Arc<Inner>);

impl ChannelsResource {
    pub async fn send_whatsapp(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/channels/whatsapp/send", Some(data), false).await
    }

    pub async fn send_push(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/channels/push/send", Some(data), false).await
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
        self.0.get_with_params("/analytics/overview", params, false).await
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
    pub async fn email(&self, address: &str) -> Result<Value, MisarMailError> {
        self.0
            .get_with_params(
                "/validate/email",
                json!({ "address": address }),
                false,
            )
            .await
    }
}

// ── Resource: Leads ───────────────────────────────────────────────────────────

pub struct LeadsResource(Arc<Inner>);

impl LeadsResource {
    pub async fn search(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/leads/search", Some(data), false).await
    }

    pub async fn get_job(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/leads/jobs/{}", id), Value::Null, false).await
    }

    pub async fn list_jobs(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/leads/jobs", params, false).await
    }

    pub async fn results(&self, job_id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/leads/jobs/{}/results", job_id), Value::Null, false).await
    }

    pub async fn import_leads(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/leads/import", Some(data), false).await
    }

    pub async fn credits(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/leads/credits", Value::Null, false).await
    }
}

// ── Resource: Autopilot ───────────────────────────────────────────────────────

pub struct AutopilotResource(Arc<Inner>);

impl AutopilotResource {
    pub async fn start(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/autopilot", Some(data), false).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/autopilot/{}", id), Value::Null, false).await
    }

    pub async fn list(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/autopilot", params, false).await
    }

    pub async fn daily_plan(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/autopilot/daily-plan", Value::Null, false).await
    }
}

// ── Resource: Sales Agent ─────────────────────────────────────────────────────

pub struct SalesAgentResource(Arc<Inner>);

impl SalesAgentResource {
    pub async fn get_config(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/sales-agent/config", Value::Null, false).await
    }

    pub async fn update_config(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, "/sales-agent/config", Some(data), false).await
    }

    pub async fn get_actions(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/sales-agent/actions", params, false).await
    }
}

// ── Resource: CRM ─────────────────────────────────────────────────────────────

pub struct CrmResource(Arc<Inner>);

impl CrmResource {
    pub async fn list_conversations(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/crm/conversations", params, false).await
    }

    pub async fn get_conversation(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/crm/conversations/{}", id), Value::Null, false).await
    }

    pub async fn update_conversation(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/crm/conversations/{}", id), Some(data), false).await
    }

    pub async fn list_messages(&self, conversation_id: &str) -> Result<Value, MisarMailError> {
        self.0
            .get_with_params(
                &format!("/crm/conversations/{}/messages", conversation_id),
                Value::Null,
                false,
            )
            .await
    }

    pub async fn list_deals(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/crm/deals", params, false).await
    }

    pub async fn create_deal(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/crm/deals", Some(data), false).await
    }

    pub async fn get_deal(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/crm/deals/{}", id), Value::Null, false).await
    }

    pub async fn update_deal(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/crm/deals/{}", id), Some(data), false).await
    }

    pub async fn delete_deal(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/crm/deals/{}", id), None, false).await
    }

    pub async fn list_clients(&self, params: Value) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/crm/clients", params, false).await
    }

    pub async fn create_client(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/crm/clients", Some(data), false).await
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

pub struct WorkspacesResource(Arc<Inner>);

impl WorkspacesResource {
    pub async fn list(&self) -> Result<Value, MisarMailError> {
        self.0.get_with_params("/workspaces", Value::Null, true).await
    }

    pub async fn create(&self, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::POST, "/workspaces", Some(data), true).await
    }

    pub async fn get(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/workspaces/{}", id), Value::Null, true).await
    }

    pub async fn update(&self, id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0.request(Method::PATCH, &format!("/workspaces/{}", id), Some(data), true).await
    }

    pub async fn delete(&self, id: &str) -> Result<Value, MisarMailError> {
        self.0.request(Method::DELETE, &format!("/workspaces/{}", id), None, true).await
    }

    pub async fn list_members(&self, ws_id: &str) -> Result<Value, MisarMailError> {
        self.0.get_with_params(&format!("/workspaces/{}/members", ws_id), Value::Null, true).await
    }

    pub async fn invite_member(&self, ws_id: &str, data: Value) -> Result<Value, MisarMailError> {
        self.0
            .request(Method::POST, &format!("/workspaces/{}/members", ws_id), Some(data), true)
            .await
    }

    pub async fn update_member(
        &self,
        ws_id: &str,
        user_id: &str,
        data: Value,
    ) -> Result<Value, MisarMailError> {
        self.0
            .request(
                Method::PATCH,
                &format!("/workspaces/{}/members/{}", ws_id, user_id),
                Some(data),
                true,
            )
            .await
    }

    pub async fn remove_member(&self, ws_id: &str, user_id: &str) -> Result<Value, MisarMailError> {
        self.0
            .request(
                Method::DELETE,
                &format!("/workspaces/{}/members/{}", ws_id, user_id),
                None,
                true,
            )
            .await
    }
}
