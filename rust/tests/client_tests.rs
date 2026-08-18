use misarmail::{MisarMailClient, MisarMailError};
use wiremock::matchers::{header, method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

async fn client(server: &MockServer) -> MisarMailClient {
    MisarMailClient::new("mmk_test").with_base_url(&server.uri())
}

#[tokio::test]
async fn plan_get_is_typed_and_authorized() {
    let server = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/plan"))
        .and(header("authorization", "Bearer mmk_test"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "plan": { "slug": "starter", "name": "Starter" },
            "sending": { "emails_per_day": 500, "emails_per_month": 10000 },
            "usage": [{ "feature": "emails", "used": 120, "limit": 500, "remaining": 380 }],
            "upgrade": null
        })))
        .mount(&server)
        .await;

    let out = client(&server).await.plan.get().await.expect("plan.get");
    assert_eq!(out["plan"]["slug"], "starter");
    assert_eq!(out["usage"][0]["used"], 120);
    assert!(out["upgrade"].is_null(), "upgrade is null while the plan has headroom");
}

/// A spent allowance answers 429 — identical by status to a rate limit — so the
/// client must tell them apart by body and refuse to retry the plan refusal.
#[tokio::test]
async fn plan_limit_is_surfaced_and_not_retried() {
    let server = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/plan"))
        .respond_with(
            ResponseTemplate::new(429)
                .insert_header("x-misar-plan", "starter")
                .insert_header("x-misar-upgrade-url", "https://misarmail.com/pricing")
                .insert_header("retry-after", "600")
                .set_body_json(serde_json::json!({
                    "error": "Monthly send allowance spent.",
                    "code": "plan_limit_exceeded",
                    "upgrade": { "feature": "emails", "currentPlanSlug": "starter" }
                })),
        )
        // Exactly one request: a retry would trip this expectation.
        .expect(1)
        .mount(&server)
        .await;

    let err = client(&server).await.plan.get().await.unwrap_err();

    match err {
        MisarMailError::PlanLimit {
            status,
            ref plan,
            ref upgrade_url,
            retry_after,
            ref feature,
            ..
        } => {
            assert_eq!(status, 429);
            assert_eq!(plan.as_deref(), Some("starter"));
            assert_eq!(upgrade_url.as_deref(), Some("https://misarmail.com/pricing"));
            assert_eq!(retry_after, Some(600));
            assert_eq!(feature.as_deref(), Some("emails"));
        }
        other => panic!("expected PlanLimit, got {other:?}"),
    }
    assert_eq!(err.upgrade_url(), Some("https://misarmail.com/pricing"));
}

/// A plain rate-limit 429 carries no plan marker and must still be retried.
#[tokio::test]
async fn rate_limit_is_still_retried() {
    let server = MockServer::start().await;

    Mock::given(method("GET"))
        .and(path("/plan"))
        .respond_with(ResponseTemplate::new(429).set_body_json(serde_json::json!({
            "error": "Rate limit exceeded"
        })))
        .up_to_n_times(1)
        .mount(&server)
        .await;

    Mock::given(method("GET"))
        .and(path("/plan"))
        .respond_with(ResponseTemplate::new(200).set_body_json(serde_json::json!({
            "plan": { "slug": "starter", "name": "Starter" }
        })))
        .mount(&server)
        .await;

    let out = client(&server).await.plan.get().await.expect("retry then succeed");
    assert_eq!(out["plan"]["slug"], "starter");
}

#[tokio::test]
async fn unauthorized_is_an_api_error() {
    let server = MockServer::start().await;
    Mock::given(method("GET"))
        .and(path("/plan"))
        .respond_with(ResponseTemplate::new(401).set_body_json(serde_json::json!({
            "error": "Invalid or missing API key"
        })))
        .mount(&server)
        .await;

    match client(&server).await.plan.get().await.unwrap_err() {
        MisarMailError::Api { status, message } => {
            assert_eq!(status, 401);
            assert_eq!(message, "Invalid or missing API key");
        }
        other => panic!("expected Api, got {other:?}"),
    }
}
