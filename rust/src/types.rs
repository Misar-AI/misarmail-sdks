use serde::{Deserialize, Serialize};
use std::collections::HashMap;

// ── Email ─────────────────────────────────────────────────────────────────────

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct SendEmailRequest {
    pub from: String,
    pub to: Vec<String>,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub cc: Vec<String>,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub bcc: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reply_to: Option<String>,
    pub subject: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub html: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub tags: Vec<String>,
    #[serde(skip_serializing_if = "HashMap::is_empty", default)]
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SendEmailResponse {
    pub success: bool,
    pub message_id: String,
}

// ── Contacts ──────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct Contact {
    pub id: String,
    pub email: String,
    pub status: String,
    pub created_at: String,
    #[serde(default)]
    pub updated_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ContactsListResponse {
    pub data: Vec<Contact>,
    pub total: i64,
    #[serde(default)]
    pub page: i64,
    #[serde(default)]
    pub limit: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ContactInput {
    pub email: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub first_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_name: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ContactImportRequest {
    pub contacts: Vec<ContactInput>,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub tags: Vec<String>,
}

// ── Campaigns ─────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct Campaign {
    pub id: String,
    pub name: String,
    pub status: String,
    pub subject: String,
    pub created_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CampaignsListResponse {
    pub data: Vec<Campaign>,
    pub total: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateCampaignRequest {
    pub name: String,
    pub subject: String,
    pub from_email: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub from_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub html: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
}

// ── Templates ─────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct Template {
    pub id: String,
    pub name: String,
    pub html: String,
    pub created_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TemplatesListResponse {
    pub data: Vec<Template>,
    pub total: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateTemplateRequest {
    pub name: String,
    pub html: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RenderTemplateRequest {
    pub template_id: String,
    #[serde(skip_serializing_if = "HashMap::is_empty", default)]
    pub variables: HashMap<String, String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RenderTemplateResponse {
    pub html: String,
}

// ── API Keys ──────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct ApiKey {
    pub id: String,
    pub name: String,
    pub created_at: String,
    #[serde(default)]
    pub last_used: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct KeysListResponse {
    pub data: Vec<ApiKey>,
    pub total: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateKeyResponse {
    pub id: String,
    pub key: String,
    pub name: String,
    pub created_at: String,
}

// ── Analytics ─────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct AnalyticsResponse {
    pub sent: i64,
    pub delivered: i64,
    pub opens: i64,
    pub clicks: i64,
    pub bounces: i64,
    pub unsubscribes: i64,
    pub open_rate: f64,
    pub click_rate: f64,
}

// ── Validation ────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct ValidateEmailResponse {
    pub valid: bool,
    #[serde(default)]
    pub disposable: bool,
    #[serde(default)]
    pub mx_found: bool,
    #[serde(default)]
    pub suggestion: Option<String>,
}

// ── A/B Tests ─────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct ABTest {
    pub id: String,
    pub name: String,
    pub status: String,
    #[serde(default)]
    pub winner_variant: String,
    pub created_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ABTestsListResponse {
    pub data: Vec<ABTest>,
    pub total: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateABTestRequest {
    pub name: String,
    pub subject_a: String,
    pub subject_b: String,
    pub from_email: String,
    pub split_percent: i32,
}

// ── Sandbox ───────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct SandboxMessage {
    pub id: String,
    pub to: String,
    pub subject: String,
    pub received_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SandboxListResponse {
    pub data: Vec<SandboxMessage>,
    pub total: i64,
}

// ── Tracking ──────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct TrackEventRequest {
    pub email: String,
    pub event: String,
    #[serde(skip_serializing_if = "serde_json::Map::is_empty", default)]
    pub properties: serde_json::Map<String, serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PurchaseItem {
    pub name: String,
    pub quantity: i32,
    pub price: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TrackPurchaseRequest {
    pub email: String,
    pub amount: f64,
    pub currency: String,
    pub order_id: String,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub items: Vec<PurchaseItem>,
}

// ── Inbound ───────────────────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize)]
pub struct InboundMessage {
    pub id: String,
    pub from: String,
    pub to: String,
    pub subject: String,
    pub received_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct InboundListResponse {
    pub data: Vec<InboundMessage>,
    pub total: i64,
}
