import 'dart:convert';

import 'package:crypto/crypto.dart';

const defaultToleranceSeconds = 300;

/// Produces the digest MisarMail sends in `X-Misar-Signature`.
///
/// Public because verification is only half the job: testing a webhook consumer
/// needs a valid signature, and the exact framing (timestamp + "." + body) is
/// where that usually goes wrong.
String signWebhook(String payload, String timestamp, String secret) {
  final mac = Hmac(sha256, utf8.encode(secret));
  return mac.convert(utf8.encode('$timestamp.$payload')).toString();
}

/// Verifies an inbound webhook.
///
/// MisarMail signs each webhook as `HMAC-SHA256(timestamp + "." + rawBody)` with
/// the endpoint's signing secret. Verify against the RAW body, not a re-encoded
/// map: key order and whitespace both change the digest. The comparison is
/// constant-time so a timing oracle cannot recover the digest byte by byte.
bool verifyWebhookSignature({
  required String payload,
  required String signature,
  required String timestamp,
  required String secret,
  int toleranceSeconds = defaultToleranceSeconds,
}) {
  if (payload.isEmpty || signature.isEmpty || timestamp.isEmpty || secret.isEmpty) {
    return false;
  }

  final sentAt = double.tryParse(timestamp);
  if (sentAt == null) return false;

  // Rejecting stale timestamps is what stops a captured request from being
  // replayed forever, so this is a real check rather than a formality.
  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  if ((now - sentAt).abs() > toleranceSeconds) return false;

  return _constantTimeEquals(signWebhook(payload, timestamp, secret), signature.trim());
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;

  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}
