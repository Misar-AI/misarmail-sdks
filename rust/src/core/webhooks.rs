//! Inbound webhook signature verification.
//!
//! MisarMail signs each webhook as `HMAC-SHA256(timestamp + "." + raw_body)`
//! with the endpoint's signing secret, sending the digest in
//! `X-Misar-Signature` and the Unix timestamp in `X-Misar-Timestamp`.
//!
//! Verify against the RAW body, not a re-serialized struct: field order and
//! whitespace both change the digest. The comparison is constant-time so a
//! timing oracle cannot recover the digest byte by byte.

use std::time::{SystemTime, UNIX_EPOCH};

use hmac::{Hmac, Mac};
use sha2::Sha256;

pub const DEFAULT_TOLERANCE_SECONDS: u64 = 300;

/// Produce the digest MisarMail sends in `X-Misar-Signature`.
///
/// Public because verification is only half the job: testing a webhook consumer
/// needs a valid signature, and the exact framing is where that usually goes
/// wrong.
pub fn sign_webhook(payload: &[u8], timestamp: &str, secret: &str) -> String {
    let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes())
        .expect("HMAC accepts keys of any length");
    mac.update(timestamp.as_bytes());
    mac.update(b".");
    mac.update(payload);
    hex(&mac.finalize().into_bytes())
}

/// Returns true when the signature is authentic and the timestamp is fresh.
/// Never panics on malformed input — a bad signature is `false`, not an error.
pub fn verify_webhook_signature(
    payload: &[u8],
    signature: &str,
    timestamp: &str,
    secret: &str,
    tolerance_seconds: u64,
) -> bool {
    if payload.is_empty() || signature.is_empty() || timestamp.is_empty() || secret.is_empty() {
        return false;
    }

    let Ok(sent_at) = timestamp.parse::<f64>() else {
        return false;
    };

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0);

    // Rejecting stale timestamps is what stops a captured request from being
    // replayed forever, so this is a real check rather than a formality.
    let tolerance = if tolerance_seconds == 0 {
        DEFAULT_TOLERANCE_SECONDS
    } else {
        tolerance_seconds
    };
    if (now - sent_at).abs() > tolerance as f64 {
        return false;
    }

    constant_time_eq(
        sign_webhook(payload, timestamp, secret).as_bytes(),
        signature.trim().as_bytes(),
    )
}

fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    // Comparing lengths first would leak length either way; returning early is
    // the honest option since the digest length is fixed and public.
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}
