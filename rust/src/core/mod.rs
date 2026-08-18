//! Hand-written runtime core: transport, streams, webhook verification.
//!
//! The resource layer above it is generated from `sdks/manifest.json`; this half
//! is written by hand because idiom matters most here and generated code reads
//! worst.

pub mod sse;
pub mod transport;
pub mod webhooks;

pub use sse::{stream_sse, SseEvent};
pub use transport::{encode_query, encode_query_with, CoreClient};
pub use webhooks::{sign_webhook, verify_webhook_signature};
