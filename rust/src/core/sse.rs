//! Server-Sent Events client for the MisarMail streaming endpoints.
//!
//! Both streams frame events as `data: <json>` and close with the sentinel
//! `data: [DONE]`. One of the two is a POST, so the stream is driven off a
//! normal request with a chunked body reader.

use futures_util::StreamExt;
use serde_json::Value;
use tokio::sync::mpsc;

use crate::core::transport::CoreClient;
use crate::errors::MisarMailError;

const DONE: &str = "[DONE]";

/// One decoded SSE frame. `Raw` carries frames that were not valid JSON, so a
/// single malformed frame does not discard everything already streamed.
#[derive(Debug, Clone)]
pub enum SseEvent {
    Data(Value),
    Raw(String),
}

/// Open an SSE endpoint and push each decoded frame onto a channel.
///
/// A channel rather than an `impl Stream` keeps the signature free of the
/// pinning dance callers would otherwise have to perform, and lets the reader
/// drop out simply by dropping the receiver.
pub async fn stream_sse(
    client: &CoreClient,
    method: &str,
    path: &str,
    body: Option<&Value>,
) -> Result<mpsc::Receiver<SseEvent>, MisarMailError> {
    let url = format!("{}{}", client.base_url(), path);
    let verb = reqwest::Method::from_bytes(method.as_bytes()).map_err(|_| MisarMailError::Api {
        status: 0,
        message: format!("unsupported HTTP method: {method}"),
        error_type: "client_error".into(),
    })?;

    let mut request = client
        .http
        .request(verb, &url)
        .bearer_auth(client.api_key())
        .header("Accept", "text/event-stream")
        // A stream has no useful deadline, so it must not inherit the client's
        // per-request timeout.
        .timeout(std::time::Duration::from_secs(3600));

    if let Some(payload) = body {
        request = request.json(payload);
    }

    let response = request
        .send()
        .await
        .map_err(|e| MisarMailError::Network(e.to_string()))?;

    let status = response.status().as_u16();
    if status >= 400 {
        // Errors arrive as a normal JSON body, not as an SSE frame.
        let text = response.text().await.unwrap_or_default();
        let data: Value = serde_json::from_str(&text).unwrap_or(Value::Null);
        return Err(MisarMailError::Api {
            status,
            message: data
                .get("error")
                .and_then(Value::as_str)
                .unwrap_or("stream failed")
                .to_string(),
            error_type: "api_error".into(),
        });
    }

    let (tx, rx) = mpsc::channel(64);

    tokio::spawn(async move {
        let mut bytes = response.bytes_stream();
        let mut buffer = String::new();

        while let Some(chunk) = bytes.next().await {
            let Ok(chunk) = chunk else { break };
            buffer.push_str(&String::from_utf8_lossy(&chunk));

            while let Some(index) = buffer.find('\n') {
                let line: String = buffer.drain(..=index).collect();
                let line = line.trim_end();

                let Some(payload) = line.strip_prefix("data:") else {
                    continue;
                };
                let payload = payload.trim();

                if payload == DONE {
                    return;
                }
                if payload.is_empty() {
                    continue;
                }

                let event = match serde_json::from_str::<Value>(payload) {
                    Ok(value) => SseEvent::Data(value),
                    Err(_) => SseEvent::Raw(payload.to_string()),
                };
                if tx.send(event).await.is_err() {
                    return; // receiver dropped — stop reading
                }
            }
        }
    });

    Ok(rx)
}
