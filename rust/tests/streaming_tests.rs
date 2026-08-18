use futures_util::StreamExt;
use misarmail::{MisarMailClient, MisarMailError};
use wiremock::matchers::{header, method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

/// Points the client's API base at the mock server. Both streaming routes live
/// outside /v1, so it is api_base — not base_url — that must be overridden.
async fn client(server: &MockServer) -> MisarMailClient {
    MisarMailClient::new("mmk_test").with_api_base(&server.uri())
}

async fn drain(server: &MockServer) -> Result<Vec<serde_json::Value>, MisarMailError> {
    let c = client(server).await;
    let mut stream = c
        .streaming
        .generate_email(serde_json::json!({ "prompt": "hi" }))
        .await?;
    let mut out = Vec::new();
    while let Some(frame) = stream.next().await {
        out.push(frame?.data);
    }
    Ok(out)
}

fn sse(body: &str) -> ResponseTemplate {
    ResponseTemplate::new(200)
        .insert_header("content-type", "text/event-stream")
        .set_body_string(body)
}

#[tokio::test]
async fn yields_frames_and_stops_at_done() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/ai/generate-email/stream"))
        .and(header("accept", "text/event-stream"))
        .respond_with(sse(concat!(
            "data: {\"delta\":\"Hel\",\"type\":\"body\"}\n\n",
            "data: {\"delta\":\"lo\",\"type\":\"body\"}\n\n",
            "data: {\"done\":true,\"type\":\"body\"}\n\n",
            "data: [DONE]\n\n",
            "data: {\"delta\":\"after-done\"}\n\n",
        )))
        .mount(&server)
        .await;

    let got = drain(&server).await.expect("stream");
    assert_eq!(got.len(), 3, "frames after [DONE] must not be delivered: {got:?}");
    assert_eq!(got[0]["delta"], "Hel");
    assert_eq!(got[1]["delta"], "lo");
    assert_eq!(got[2]["done"], true);
}

#[tokio::test]
async fn skips_keepalives_and_handles_crlf() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .respond_with(sse(concat!(
            ": keepalive\n\n",
            "data: {\"delta\":\"a\"}\r\n\r\n",
            ": keepalive\n\n",
            "data: [DONE]\r\n\r\n",
        )))
        .mount(&server)
        .await;

    let got = drain(&server).await.expect("stream");
    assert_eq!(got.len(), 1);
    assert_eq!(got[0]["delta"], "a");
}

#[tokio::test]
async fn surfaces_the_server_error_frame() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .respond_with(sse("data: {\"error\":\"generation_failed\"}\n\ndata: [DONE]\n\n"))
        .mount(&server)
        .await;

    let got = drain(&server).await.expect("stream");
    assert_eq!(got.len(), 1);
    assert_eq!(got[0]["error"], "generation_failed");
}

#[tokio::test]
async fn emits_a_trailing_frame_with_no_blank_line() {
    let server = MockServer::start().await;
    // A server that closes without a final separator must not lose the frame.
    Mock::given(method("POST"))
        .respond_with(sse("data: {\"delta\":\"tail\"}"))
        .mount(&server)
        .await;

    let got = drain(&server).await.expect("stream");
    assert_eq!(got.len(), 1);
    assert_eq!(got[0]["delta"], "tail");
}

#[tokio::test]
async fn unauthorized_is_an_api_error() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .respond_with(
            ResponseTemplate::new(401)
                .set_body_json(serde_json::json!({ "error": "Invalid or missing API key" })),
        )
        .mount(&server)
        .await;

    match drain(&server).await.unwrap_err() {
        MisarMailError::Api { status, message } => {
            assert_eq!(status, 401);
            assert_eq!(message, "Invalid or missing API key");
        }
        other => panic!("expected Api, got {other:?}"),
    }
}

#[tokio::test]
async fn plan_refusal_on_open_is_typed() {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .respond_with(
            ResponseTemplate::new(429)
                .insert_header("x-misar-plan", "starter")
                .set_body_json(serde_json::json!({
                    "error": "spent",
                    "code": "plan_limit_exceeded",
                    "upgrade": { "feature": "ai" }
                })),
        )
        .mount(&server)
        .await;

    match drain(&server).await.unwrap_err() {
        MisarMailError::PlanLimit { plan, feature, .. } => {
            assert_eq!(plan.as_deref(), Some("starter"));
            assert_eq!(feature.as_deref(), Some("ai"));
        }
        other => panic!("expected PlanLimit, got {other:?}"),
    }
}
