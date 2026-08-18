"""Inbound webhook signature verification.

MisarMail signs each webhook as ``HMAC-SHA256(timestamp + "." + raw_body)`` with
the endpoint's signing secret, sending the digest in ``X-Misar-Signature`` and
the Unix timestamp in ``X-Misar-Timestamp``.

Two things matter and are easy to get wrong: verify against the RAW body rather
than a re-serialized dict (key order and whitespace both change the digest), and
compare in constant time so a timing oracle cannot recover the digest byte by
byte.
"""

from __future__ import annotations

import hashlib
import hmac
import time

DEFAULT_TOLERANCE_SECONDS = 300


def verify_webhook_signature(
    payload: str | bytes,
    signature: str,
    timestamp: str,
    secret: str,
    tolerance_seconds: int = DEFAULT_TOLERANCE_SECONDS,
) -> bool:
    """Return True when the signature is authentic and the timestamp is fresh.

    Never raises on malformed input — a bad signature is a False, not an error.
    """
    if not payload or not signature or not timestamp or not secret:
        return False

    try:
        sent_at = float(timestamp)
    except (TypeError, ValueError):
        return False

    # Rejecting stale timestamps is what stops a captured request from being
    # replayed forever, so this is a real check rather than a formality.
    if abs(time.time() - sent_at) > tolerance_seconds:
        return False

    body = payload.encode("utf-8") if isinstance(payload, str) else payload
    signed = timestamp.encode("utf-8") + b"." + body
    expected = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()

    return hmac.compare_digest(expected, signature.strip())
