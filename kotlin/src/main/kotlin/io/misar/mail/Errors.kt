package io.misar.mail

/**
 * Thrown when the MisarMail API returns a non-2xx HTTP response.
 *
 * @property status HTTP status code returned by the server.
 * @property message Human-readable error description from the API.
 */
open class MisarMailException(
    val status: Int,
    message: String,
) : Exception("MisarMailException($status): $message")

/**
 * Thrown when a network-level error prevents the request from completing
 * (e.g. DNS failure, connection refused, timeout) or when the maximum
 * number of retries is exhausted.
 *
 * @property message Cause description.
 */
class MisarMailNetworkException(message: String) : MisarMailException(0, message)

/**
 * Thrown when the subscription attached to the API key blocks the call.
 *
 * MisarMail meters per-plan server-side: a spent allowance answers 429 and a
 * feature not on the plan answers 402. A distinct type rather than a generic
 * 429 because retrying cannot help until the allowance resets or the plan
 * changes — the client stops retrying on sight.
 *
 * Surface [upgradeUrl] rather than reporting a bare failure.
 */
class PlanLimitException(
    status: Int,
    message: String,
    /** The account's current plan slug, when reported. */
    val plan: String? = null,
    /** Pricing page to send the user to. */
    val upgradeUrl: String? = null,
    /** Seconds until the allowance resets, when supplied. */
    val retryAfter: Int? = null,
    /** The allowance that was exhausted. */
    val feature: String? = null,
) : MisarMailException(status, message)
