use thiserror::Error;

#[derive(Debug, Error)]
pub enum MisarMailError {
    #[error("API error {status}: {message}")]
    Api { status: u16, message: String },

    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}
