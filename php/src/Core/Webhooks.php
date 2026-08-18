<?php

declare(strict_types=1);

namespace MisarMail\Core;

/**
 * Inbound webhook signature verification.
 *
 * MisarMail signs each webhook as HMAC-SHA256(timestamp + "." + rawBody) with
 * the endpoint's signing secret, sending the digest in X-Misar-Signature and
 * the Unix timestamp in X-Misar-Timestamp.
 *
 * Verify against the RAW body (php://input), not a re-encoded array: key order
 * and whitespace both change the digest. hash_equals is constant-time so a
 * timing oracle cannot recover the digest byte by byte.
 */
final class Webhooks
{
    public const DEFAULT_TOLERANCE_SECONDS = 300;

    /** Returns true when the signature is authentic and the timestamp is fresh. */
    public static function verify(
        string $payload,
        string $signature,
        string $timestamp,
        string $secret,
        int $toleranceSeconds = self::DEFAULT_TOLERANCE_SECONDS,
    ): bool {
        if ($payload === '' || $signature === '' || $timestamp === '' || $secret === '') {
            return false;
        }

        if (!is_numeric($timestamp)) {
            return false;
        }

        // Rejecting stale timestamps is what stops a captured request from
        // being replayed forever, so this is a real check, not a formality.
        if (abs(time() - (float) $timestamp) > $toleranceSeconds) {
            return false;
        }

        return hash_equals(self::sign($payload, $timestamp, $secret), trim($signature));
    }

    /**
     * Produces the digest MisarMail sends. Public because verification is only
     * half the job: testing a webhook consumer needs a valid signature, and the
     * exact framing is where that usually goes wrong.
     */
    public static function sign(string $payload, string $timestamp, string $secret): string
    {
        return hash_hmac('sha256', $timestamp . '.' . $payload, $secret);
    }
}
