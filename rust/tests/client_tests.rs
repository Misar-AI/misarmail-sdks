use misar_mail::{MisarMailClient, MisarMailError, SendEmailRequest};
use wiremock::matchers::{method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

fn make_client(server: &MockServer) -> MisarMailClient {
    MisarMailClient::new("test-key")
        .with_base_url(&server.uri())
        .with_max_retries(3)
}

#[tokio::test]
async fn send_email_success() {
    let server = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path("/send"))
        .respond_with(
            ResponseTemplate::new(200)
                .set_body_json(serde_json::json!({ "success": true, "message_id": "msg_123" })),
        )
        .mount(&server)
        .await;

    let client = make_client(&server);
    let resp = client
        .send_email(&SendEmailRequest {
            from: "sender@example.com".into(),
            to: vec!["recipient@example.com".into()],
            subject: "Test".into(),
            html: Some("<p>Hello</p>".into()),
            ..Default::default()
        })
        .await
        .expect("send_email failed");

    assert!(resp.success);
    assert_eq!(resp.message_id, "msg_123");
}

#[tokio::test]
async fn contacts_list() {
    let server = MockServer::start().await;

    Mock::given(method("GET"))
        .and(path("/contacts"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "data": [{ "id": "c1", "email": "a@b.com", "status": "active", "created_at": "", "updated_at": "" }],
            "total": 1, "page": 1, "limit": 10
        })))
        .mount(&server)
        .await;

    let client = make_client(&server);
    let resp = client.contacts_list(1, 10).await.expect("contacts_list failed");

    assert_eq!(resp.data.len(), 1);
    assert_eq!(resp.data[0].email, "a@b.com");
}

#[tokio::test]
async fn analytics_get() {
    let server = MockServer::start().await;

    Mock::given(method("GET"))
        .and(path("/analytics"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "sent": 100, "delivered": 95, "opens": 40, "clicks": 10,
            "bounces": 5, "unsubscribes": 2, "open_rate": 0.42, "click_rate": 0.10
        })))
        .mount(&server)
        .await;

    let client = make_client(&server);
    let resp = client.analytics_get().await.expect("analytics_get failed");

    assert_eq!(resp.sent, 100);
    assert_eq!(resp.delivered, 95);
}

#[tokio::test]
async fn validate_email() {
    let server = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path("/validate"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "valid": true, "disposable": false, "mx_found": true, "suggestion": null
        })))
        .mount(&server)
        .await;

    let client = make_client(&server);
    let resp = client
        .validate_email("user@example.com")
        .await
        .expect("validate_email failed");

    assert!(resp.valid);
    assert!(!resp.disposable);
}

#[tokio::test]
async fn error_401() {
    let server = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path("/send"))
        .respond_with(
            ResponseTemplate::new(401)
                .set_body_json(serde_json::json!({ "error": "unauthorized" })),
        )
        .mount(&server)
        .await;

    let client = make_client(&server);
    let err = client
        .send_email(&SendEmailRequest {
            from: "a@b.com".into(),
            to: vec!["c@d.com".into()],
            subject: "Test".into(),
            ..Default::default()
        })
        .await
        .expect_err("expected error");

    match err {
        MisarMailError::Api { status, message } => {
            assert_eq!(status, 401);
            assert_eq!(message, "unauthorized");
        }
        other => panic!("expected Api error, got {:?}", other),
    }
}

#[tokio::test]
async fn retry_503() {
    let server = MockServer::start().await;

    // First two requests return 503
    Mock::given(method("POST"))
        .and(path("/send"))
        .respond_with(ResponseTemplate::new(503))
        .up_to_n_times(2)
        .mount(&server)
        .await;

    // Third request succeeds
    Mock::given(method("POST"))
        .and(path("/send"))
        .respond_with(
            ResponseTemplate::new(200)
                .set_body_json(serde_json::json!({ "success": true, "message_id": "msg_retry" })),
        )
        .mount(&server)
        .await;

    let client = make_client(&server);
    let resp = client
        .send_email(&SendEmailRequest {
            from: "a@b.com".into(),
            to: vec!["c@d.com".into()],
            subject: "Retry test".into(),
            ..Default::default()
        })
        .await
        .expect("send_email failed after retry");

    assert!(resp.success);
    assert_eq!(resp.message_id, "msg_retry");
}

#[tokio::test]
async fn network_ok_after_retry() {
    // Same as retry_503 but verifies the happy path after transient failures
    let server = MockServer::start().await;

    Mock::given(method("GET"))
        .and(path("/analytics"))
        .respond_with(ResponseTemplate::new(503))
        .up_to_n_times(1)
        .mount(&server)
        .await;

    Mock::given(method("GET"))
        .and(path("/analytics"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "sent": 50, "delivered": 48, "opens": 20, "clicks": 5,
            "bounces": 2, "unsubscribes": 1, "open_rate": 0.40, "click_rate": 0.10
        })))
        .mount(&server)
        .await;

    let client = make_client(&server);
    let resp = client.analytics_get().await.expect("analytics_get failed");

    assert_eq!(resp.sent, 50);
}
