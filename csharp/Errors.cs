using System;

namespace MisarMail;

/// <summary>
/// Thrown when the MisarMail API returns a non-2xx HTTP response, or when a
/// transport failure prevents the request from completing.
/// </summary>
/// <remarks>
/// For transport failures <see cref="Status"/> is <c>0</c>. The type is open
/// rather than sealed because <see cref="MisarMailNetworkException"/> and
/// <see cref="MisarMailPlanLimitException"/> both narrow it, and callers catch
/// the base type when they only care that the call failed.
/// </remarks>
public class MisarMailException : Exception
{
    /// <summary>HTTP status code returned by the server, or <c>0</c> for transport failures.</summary>
    public int Status { get; }

    public MisarMailException(int status, string message)
        : base($"MisarMailException({status}): {message}")
    {
        Status = status;
    }

    public MisarMailException(int status, string message, Exception inner)
        : base($"MisarMailException({status}): {message}", inner)
    {
        Status = status;
    }

    /// <summary>
    /// The key was rejected outright — missing, revoked, expired, or issued for
    /// a different product.
    /// </summary>
    public bool IsUnauthorized => Status == 401;

    /// <summary>
    /// The key is valid but the account's subscription does not cover this
    /// call: the feature is not in the plan, a plan limit is exhausted, or a
    /// volume ceiling was hit. Gating is decided server-side from the
    /// subscription behind the key, so this is the signal to prompt an upgrade
    /// — without parsing error strings.
    /// </summary>
    public bool IsPlanDenied => Status is 402 or 403 or 429;

    /// <summary>Worth retrying as-is: transient server or rate-limit conditions.</summary>
    public bool IsRetryable => Status == 429 || (Status >= 500 && Status < 600);
}

/// <summary>
/// Thrown when a network-level error prevents the request from completing,
/// or when the maximum number of retries is exhausted.
/// </summary>
public sealed class MisarMailNetworkException : MisarMailException
{
    public MisarMailNetworkException(string message)
        : base(0, message) { }

    public MisarMailNetworkException(string message, Exception inner)
        : base(0, message, inner) { }
}

/// <summary>
/// Thrown when the subscription attached to the API key blocks the call.
/// </summary>
/// <remarks>
/// MisarMail meters per-plan server-side: a spent allowance answers 429 and a
/// feature not on the plan answers 402. A distinct type rather than a generic
/// 429 because retrying cannot help until the allowance resets or the plan
/// changes — the client stops retrying on sight.
/// </remarks>
public sealed class MisarMailPlanLimitException : MisarMailException
{
    /// <summary>The account's current plan slug, when reported.</summary>
    public string? Plan { get; }

    /// <summary>Pricing page to send the user to.</summary>
    public string? UpgradeUrl { get; }

    /// <summary>Seconds until the allowance resets, when supplied.</summary>
    public int? RetryAfter { get; }

    /// <summary>The allowance that was exhausted.</summary>
    public string? Feature { get; }

    public MisarMailPlanLimitException(
        int status,
        string message,
        string? plan = null,
        string? upgradeUrl = null,
        int? retryAfter = null,
        string? feature = null)
        : base(status, message)
    {
        Plan = plan;
        UpgradeUrl = upgradeUrl;
        RetryAfter = retryAfter;
        Feature = feature;
    }
}
