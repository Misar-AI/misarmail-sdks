//! HTTP transport shared by the generated resource layer.
//!
//! Everything the SDK does goes through one of three transports — HTTP for
//! REST, SSE for streaming, WebSocket for push — and all three authenticate the
//! same way: the account API key, sent as a bearer token. There is no second
//! credential path. What a key may do, and how much of it, is decided
//! server-side from the subscription behind that key.

use std::time::Duration;

use reqwest::{Client as HttpClient, Method, Response};
use serde_json::Value;
use tokio::time::sleep;

use crate::errors::MisarMailError;

const RETRYABLE: &[u16] = &[429, 500, 502, 503, 504];
const RETRY_BASE_MS: u64 = 200;

pub struct CoreClient {
    pub(crate) api_key: String,
    pub(crate) base_url: String,
    pub(crate) http: HttpClient,
    pub(crate) max_retries: u32,
}

impl CoreClient {
    pub fn new(api_key: impl Into<String>, base_url: impl Into<String>, max_retries: u32) -> Self {
        Self {
            api_key: api_key.into(),
            base_url: base_url.into().trim_end_matches('/').to_string(),
            http: HttpClient::builder()
                .timeout(Duration::from_secs(30))
                .build()
                .expect("building the HTTP client"),
            max_retries,
        }
    }

    pub fn api_key(&self) -> &str {
        &self.api_key
    }

    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    /// Issue a request against a manifest path and decode the JSON body.
    pub async fn request(
        &self,
        method: &str,
        path: &str,
        body: Option<&Value>,
    ) -> Result<Value, MisarMailError> {
        let url = format!("{}{}", self.base_url, path);
        let verb = Method::from_bytes(method.as_bytes())
            .map_err(|_| MisarMailError::Api {
                status: 0,
                message: format!("unsupported HTTP method: {method}"),
                error_type: "client_error".into(),
            })?;

        let mut attempt = 0u32;
        loop {
            let mut request = self
                .http
                .request(verb.clone(), &url)
                .bearer_auth(&self.api_key)
                .header("Content-Type", "application/json");

            if let Some(payload) = body {
                request = request.json(payload);
            }

            match request.send().await {
                Ok(response) => {
                    let status = response.status().as_u16();
                    if RETRYABLE.contains(&status) && attempt + 1 < self.max_retries {
                        sleep(backoff(attempt, &response)).await;
                        attempt += 1;
                        continue;
                    }
                    return decode(response).await;
                }
                Err(err) => {
                    if attempt + 1 < self.max_retries {
                        sleep(Duration::from_millis(RETRY_BASE_MS * 2u64.pow(attempt))).await;
                        attempt += 1;
                        continue;
                    }
                    return Err(MisarMailError::Network(err.to_string()));
                }
            }
        }
    }
}

async fn decode(response: Response) -> Result<Value, MisarMailError> {
    let status = response.status().as_u16();
    let text = response
        .text()
        .await
        .map_err(|e| MisarMailError::Network(e.to_string()))?;

    let data: Value = if text.is_empty() {
        Value::Null
    } else {
        // A non-JSON error body is still an error; fall through with null.
        serde_json::from_str(&text).unwrap_or(Value::Null)
    };

    if status >= 400 {
        let message = data
            .get("error")
            .and_then(Value::as_str)
            .or_else(|| data.get("message").and_then(Value::as_str))
            .unwrap_or("request failed")
            .to_string();
        let error_type = data
            .get("error_type")
            .and_then(Value::as_str)
            .unwrap_or("api_error")
            .to_string();
        return Err(MisarMailError::Api {
            status,
            message,
            error_type,
        });
    }

    Ok(data)
}

/// Exponential backoff, but honour `Retry-After` when the server sends one: on
/// a 429 the server knows when the window reopens, and guessing wastes the
/// caller's remaining budget.
fn backoff(attempt: u32, response: &Response) -> Duration {
    if let Some(header) = response.headers().get("retry-after") {
        if let Some(seconds) = header.to_str().ok().and_then(|v| v.parse::<u64>().ok()) {
            return Duration::from_secs(seconds.min(60));
        }
    }
    Duration::from_millis(RETRY_BASE_MS * 2u64.pow(attempt))
}

/// Render query pairs, or "" when empty, so generated call sites can always
/// append unconditionally.
pub fn encode_query(params: &[(&str, &str)]) -> String {
    if params.is_empty() {
        return String::new();
    }
    let encoded = params
        .iter()
        .map(|(key, value)| format!("{}={}", urlencode(key), urlencode(value)))
        .collect::<Vec<_>>()
        .join("&");
    format!("?{encoded}")
}

/// Like [`encode_query`], with required parameters merged in first. A caller
/// that passes the same key explicitly still wins.
pub fn encode_query_with(required: &[(&str, &str)], params: &[(&str, &str)]) -> String {
    let mut merged: Vec<(&str, &str)> = Vec::with_capacity(required.len() + params.len());
    for (key, value) in required {
        if !params.iter().any(|(k, _)| k == key) {
            merged.push((key, value));
        }
    }
    merged.extend_from_slice(params);
    encode_query(&merged)
}

/// Percent-encode a component. Kept local so the crate does not pull in a URL
/// dependency for what amounts to one loop.
pub fn urlencode(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for byte in value.as_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(*byte as char)
            }
            _ => out.push_str(&format!("%{byte:02X}")),
        }
    }
    out
}
