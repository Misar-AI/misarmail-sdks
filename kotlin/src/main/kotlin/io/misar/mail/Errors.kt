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
