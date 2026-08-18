using System;
using System.Security.Cryptography;
using System.Text;

namespace Misar.Mail.Core;

/// <summary>
/// Inbound webhook signature verification.
/// </summary>
/// <remarks>
/// MisarMail signs each webhook as HMAC-SHA256(timestamp + "." + rawBody) with
/// the endpoint's signing secret, sending the digest in X-Misar-Signature and
/// the Unix timestamp in X-Misar-Timestamp.
///
/// Verify against the RAW body, not a re-serialized object: property order and
/// whitespace both change the digest. CryptographicOperations.FixedTimeEquals is
/// constant-time so a timing oracle cannot recover the digest byte by byte.
/// </remarks>
public static class Webhooks
{
    public const int DefaultToleranceSeconds = 300;

    /// <summary>
    /// Produces the digest MisarMail sends. Public because verification is only
    /// half the job: testing a webhook consumer needs a valid signature, and the
    /// exact framing is where that usually goes wrong.
    /// </summary>
    public static string Sign(string payload, string timestamp, string secret)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
        var digest = hmac.ComputeHash(Encoding.UTF8.GetBytes($"{timestamp}.{payload}"));
        return Convert.ToHexString(digest).ToLowerInvariant();
    }

    /// <summary>Returns true when the signature is authentic and the timestamp is fresh.</summary>
    public static bool Verify(
        string payload,
        string signature,
        string timestamp,
        string secret,
        int toleranceSeconds = DefaultToleranceSeconds)
    {
        if (string.IsNullOrEmpty(payload) || string.IsNullOrEmpty(signature)
            || string.IsNullOrEmpty(timestamp) || string.IsNullOrEmpty(secret))
        {
            return false;
        }

        if (!double.TryParse(timestamp, out var sentAt))
        {
            return false;
        }

        // Rejecting stale timestamps is what stops a captured request from
        // being replayed forever, so this is a real check, not a formality.
        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        if (Math.Abs(now - sentAt) > toleranceSeconds)
        {
            return false;
        }

        var expected = Encoding.UTF8.GetBytes(Sign(payload, timestamp, secret));
        var actual = Encoding.UTF8.GetBytes(signature.Trim());

        // FixedTimeEquals requires equal lengths; comparing first avoids the
        // exception without leaking more than the (public, fixed) digest length.
        return expected.Length == actual.Length && CryptographicOperations.FixedTimeEquals(expected, actual);
    }
}
