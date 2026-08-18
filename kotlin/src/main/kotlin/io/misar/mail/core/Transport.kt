package io.misar.mail.core

import io.misar.mail.MisarMailException
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

/**
 * HTTP transport shared by the generated resource layer.
 *
 * Everything the SDK does goes through one of three transports — HTTP for REST,
 * SSE for streaming, WebSocket for push — and all three authenticate the same
 * way: the account API key, sent as a bearer token. There is no second
 * credential path. What a key may do, and how much of it, is decided
 * server-side from the subscription behind that key.
 */
class Transport(
    val apiKey: String,
    baseUrl: String = "https://api.misar.io/mail",
    private val maxRetries: Int = 3,
    timeout: Duration = Duration.ofSeconds(30),
) {
    init {
        require(apiKey.isNotEmpty()) {
            "A MisarMail API key is required. Create one at https://mail.misar.io/settings/api-keys."
        }
    }

    val baseUrl: String = baseUrl.trimEnd('/')

    private val http: HttpClient = HttpClient.newBuilder().connectTimeout(timeout).build()

    /** Issues a request against a manifest path and decodes the JSON body. */
    suspend fun request(method: String, path: String, body: Any?): Map<String, Any?> =
        withContext(Dispatchers.IO) {
            val url = baseUrl + path
            var attempt = 0

            while (true) {
                val publisher =
                    if (body == null) HttpRequest.BodyPublishers.noBody()
                    else HttpRequest.BodyPublishers.ofString(Json.write(body))

                val request = HttpRequest.newBuilder(URI.create(url))
                    .header("Authorization", "Bearer $apiKey")
                    .header("Content-Type", "application/json")
                    .method(method, publisher)
                    .build()

                val response = try {
                    http.send(request, HttpResponse.BodyHandlers.ofString())
                } catch (e: Exception) {
                    if (attempt < maxRetries - 1) {
                        delay(backoffMillis(attempt, null))
                        attempt++
                        continue
                    }
                    throw MisarMailException(0, e.message ?: "network error", "network_error")
                }

                if (response.statusCode() in RETRYABLE && attempt < maxRetries - 1) {
                    delay(backoffMillis(attempt, response))
                    attempt++
                    continue
                }

                return@withContext decode(response)
            }
            @Suppress("UNREACHABLE_CODE") emptyMap()
        }

    private fun decode(response: HttpResponse<String>): Map<String, Any?> {
        val raw = response.body().orEmpty()
        val data = if (raw.isEmpty()) emptyMap() else Json.readObject(raw)

        if (response.statusCode() >= 400) {
            val message = data["error"] ?: data["message"] ?: "HTTP ${response.statusCode()}"
            throw MisarMailException(
                response.statusCode(),
                message.toString(),
                (data["error_type"] ?: "api_error").toString(),
            )
        }

        return data
    }

    /**
     * Exponential backoff, but honours `Retry-After` when the server sends one:
     * on a 429 the server knows when the window reopens, and guessing wastes
     * the caller's remaining budget.
     */
    private fun backoffMillis(attempt: Int, response: HttpResponse<String>?): Long {
        response?.headers()?.firstValue("retry-after")?.orElse(null)?.let { header ->
            header.trim().toLongOrNull()?.takeIf { it >= 0 }?.let { return minOf(it, 60) * 1000 }
        }
        return 200L shl attempt
    }

    private companion object {
        val RETRYABLE = setOf(429, 500, 502, 503, 504)
    }
}
