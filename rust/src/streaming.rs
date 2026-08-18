//! Server-Sent Events support.
//!
//! MisarMail exposes two streams, both **outside** the `/v1` prefix, so they use
//! the API base rather than the versioned one:
//!
//! - `POST /api/ai/generate-email/stream`
//! - `GET  /api/campaigns/{id}/send-stream`
//!
//! Both emit *unnamed* frames — `data: {...}` with no `event:` line — and
//! terminate with the sentinel `data: [DONE]`, which is consumed here rather
//! than surfaced. MisarReach uses named events instead, so the two products
//! deliberately do not share a parser.

use futures_util::{Stream, StreamExt};
use serde_json::Value;

use crate::MisarMailError;

/// One decoded SSE frame.
#[derive(Debug, Clone, PartialEq)]
pub struct StreamEvent {
    /// The SSE `event:` name, when the server sends one. Normally `None`.
    pub event: Option<String>,
    /// Decoded JSON payload, or `Value::String` when the payload was not JSON.
    pub data: Value,
}

/// Index of the blank line ending the first complete frame, or `None`.
pub(crate) fn frame_end(buffer: &str) -> Option<usize> {
    match (buffer.find("\n\n"), buffer.find("\r\n\r\n")) {
        (None, None) => None,
        (Some(lf), None) => Some(lf),
        (None, Some(crlf)) => Some(crlf),
        (Some(lf), Some(crlf)) => Some(lf.min(crlf)),
    }
}

/// Outcome of parsing one frame.
pub(crate) enum Frame {
    /// A payload to hand to the caller.
    Event(StreamEvent),
    /// The `[DONE]` sentinel — stop reading.
    Done,
    /// A keepalive comment or an empty frame.
    Skip,
}

pub(crate) fn parse_frame(frame: &str) -> Frame {
    let mut event = None;
    let mut data_lines: Vec<&str> = Vec::new();

    let normalised = frame.replace("\r\n", "\n");
    for line in normalised.lines() {
        if line.is_empty() || line.starts_with(':') {
            continue;
        }
        if let Some(rest) = line.strip_prefix("event:") {
            event = Some(rest.trim().to_owned());
        } else if let Some(rest) = line.strip_prefix("data:") {
            data_lines.push(rest.strip_prefix(' ').unwrap_or(rest));
        }
    }
    if data_lines.is_empty() {
        return Frame::Skip;
    }
    let raw = data_lines.join("\n");
    if raw == "[DONE]" {
        return Frame::Done;
    }
    let data = serde_json::from_str(&raw).unwrap_or(Value::String(raw));
    Frame::Event(StreamEvent { event, data })
}

/// Consumes a streaming response and yields decoded frames, stopping at `[DONE]`.
///
/// Deliberately not retried: replaying a stream that failed mid-flight would
/// duplicate whatever the caller already consumed.
pub type EventStream =
    std::pin::Pin<Box<dyn Stream<Item = Result<StreamEvent, MisarMailError>> + Send>>;

pub(crate) fn frames_from(resp: reqwest::Response) -> EventStream {
    let bytes = resp.bytes_stream();
    Box::pin(futures_util::stream::unfold(
        (Box::pin(bytes), String::new(), false),
        |(mut bytes, mut buffer, done)| async move {
            if done {
                return None;
            }
            loop {
                // Serve anything already buffered before reading more.
                if let Some(end) = frame_end(&buffer) {
                    let frame: String = buffer.drain(..end).collect();
                    // Drop the blank-line separator that follows.
                    while buffer.starts_with('\n') || buffer.starts_with('\r') {
                        buffer.remove(0);
                    }
                    match parse_frame(&frame) {
                        Frame::Event(e) => return Some((Ok(e), (bytes, buffer, false))),
                        Frame::Done => return None,
                        Frame::Skip => continue,
                    }
                }

                match bytes.next().await {
                    Some(Ok(chunk)) => buffer.push_str(&String::from_utf8_lossy(&chunk)),
                    Some(Err(e)) => {
                        return Some((Err(MisarMailError::Network(e)), (bytes, buffer, true)))
                    }
                    None => {
                        // Socket closed: emit a trailing frame if one is complete.
                        if buffer.trim().is_empty() {
                            return None;
                        }
                        let frame = std::mem::take(&mut buffer);
                        return match parse_frame(&frame) {
                            Frame::Event(e) => Some((Ok(e), (bytes, String::new(), true))),
                            _ => None,
                        };
                    }
                }
            }
        },
    ))
}
