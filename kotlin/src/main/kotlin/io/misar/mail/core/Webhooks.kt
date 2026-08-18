package io.misar.mail.core

import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Inbound webhook signature verification.
 *
 * MisarMail signs each webhook as `HMAC-SHA256(timestamp + "." + rawBody)` with
 * the endpoint's signing secret, sending the digest in `X-Misar-Signature` and
 * the Unix timestamp in `X-Misar-Timestamp`.
 *
 * Verify against the RAW body, not a re-serialized object: field order and
 * whitespace both change the digest. The comparison is constant-time so a
 * timing oracle cannot recover the digest byte by byte.
 */
object Webhooks {

    const val DEFAULT_TOLERANCE_SECONDS = 300L

    /**
     * Produces the digest MisarMail sends. Public because verification is only
     * half the job: testing a webhook consumer needs a valid signature, and the
     * exact framing is where that usually goes wrong.
     */
    fun sign(payload: String, timestamp: String, secret: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(), "HmacSHA256"))
        return mac.doFinal("$timestamp.$payload".toByteArray())
            .joinToString("") { "%02x".format(it) }
    }

    /** Returns true when the signature is authentic and the timestamp is fresh. */
    fun verify(
        payload: String,
        signature: String,
        timestamp: String,
        secret: String,
        toleranceSeconds: Long = DEFAULT_TOLERANCE_SECONDS,
    ): Boolean {
        if (payload.isEmpty() || signature.isEmpty() || timestamp.isEmpty() || secret.isEmpty()) {
            return false
        }

        val sentAt = timestamp.toDoubleOrNull() ?: return false

        // Rejecting stale timestamps is what stops a captured request from
        // being replayed forever, so this is a real check, not a formality.
        if (kotlin.math.abs(System.currentTimeMillis() / 1000.0 - sentAt) > toleranceSeconds) {
            return false
        }

        return MessageDigest.isEqual(
            sign(payload, timestamp, secret).toByteArray(),
            signature.trim().toByteArray(),
        )
    }
}
