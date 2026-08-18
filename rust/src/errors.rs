use thiserror::Error;

#[derive(Debug, Error)]
pub enum MisarMailError {
    #[error("API error {status}: {message}")]
    Api { status: u16, message: String },

    /// The subscription attached to the API key blocks this call.
    ///
    /// MisarMail meters per-plan server-side: a spent allowance answers 429 and
    /// a feature not on the plan answers 402. It is a distinct variant rather
    /// than a generic 429 because retrying cannot help until the allowance
    /// resets or the plan changes — the client stops retrying on sight.
    #[error("Plan limit ({status}): {message}")]
    PlanLimit {
        status: u16,
        message: String,
        /// The account's current plan slug, when reported.
        plan: Option<String>,
        /// Pricing page to send the user to.
        upgrade_url: Option<String>,
        /// Seconds until the allowance resets, when supplied.
        retry_after: Option<u64>,
        /// The allowance that was exhausted.
        feature: Option<String>,
    },

    #[error("Network error: {0}")]
    Network(#[from] reqwest::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}

impl MisarMailError {
    /// The pricing URL to send the user to, when this is a plan refusal.
    pub fn upgrade_url(&self) -> Option<&str> {
        match self {
            MisarMailError::PlanLimit { upgrade_url, .. } => upgrade_url.as_deref(),
            _ => None,
        }
    }
}
