package io.misar.mail.core;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * Inbound webhook signature verification.
 *
 * <p>MisarMail signs each webhook as {@code HMAC-SHA256(timestamp + "." +
 * rawBody)} with the endpoint's signing secret, sending the digest in
 * {@code X-Misar-Signature} and the Unix timestamp in {@code X-Misar-Timestamp}.
 *
 * <p>Verify against the RAW body, not a re-serialized object: field order and
 * whitespace both change the digest. {@link MessageDigest#isEqual} is
 * constant-time so a timing oracle cannot recover the digest byte by byte.
 */
public final class Webhooks {

  public static final long DEFAULT_TOLERANCE_SECONDS = 300;

  private Webhooks() {}

  /** Returns true when the signature is authentic and the timestamp is fresh. */
  public static boolean verify(
      String payload, String signature, String timestamp, String secret, long toleranceSeconds) {

    if (isBlank(payload) || isBlank(signature) || isBlank(timestamp) || isBlank(secret)) {
      return false;
    }

    double sentAt;
    try {
      sentAt = Double.parseDouble(timestamp);
    } catch (NumberFormatException e) {
      return false;
    }

    // Rejecting stale timestamps is what stops a captured request from being
    // replayed forever, so this is a real check rather than a formality.
    long tolerance = toleranceSeconds > 0 ? toleranceSeconds : DEFAULT_TOLERANCE_SECONDS;
    if (Math.abs(System.currentTimeMillis() / 1000.0 - sentAt) > tolerance) {
      return false;
    }

    return MessageDigest.isEqual(
        sign(payload, timestamp, secret).getBytes(StandardCharsets.UTF_8),
        signature.trim().getBytes(StandardCharsets.UTF_8));
  }

  /**
   * Produces the digest MisarMail sends. Public because verification is only
   * half the job: testing a webhook consumer needs a valid signature, and the
   * exact framing is where that usually goes wrong.
   */
  public static String sign(String payload, String timestamp, String secret) {
    try {
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
      byte[] digest = mac.doFinal((timestamp + "." + payload).getBytes(StandardCharsets.UTF_8));

      StringBuilder hex = new StringBuilder(digest.length * 2);
      for (byte b : digest) {
        hex.append(Character.forDigit((b >> 4) & 0xF, 16)).append(Character.forDigit(b & 0xF, 16));
      }
      return hex.toString();
    } catch (Exception e) {
      throw new IllegalStateException("HmacSHA256 is required by the Java platform", e);
    }
  }

  private static boolean isBlank(String value) {
    return value == null || value.isEmpty();
  }
}
