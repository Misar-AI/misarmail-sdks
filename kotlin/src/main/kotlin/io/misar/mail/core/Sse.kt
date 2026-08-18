package io.misar.mail.core

import io.misar.mail.MisarMailException
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn

/**
 * Server-Sent Events client for the MisarMail streaming endpoints.
 *
 * Both streams frame events as `data: <json>` and close with the sentinel
 * `data: [DONE]`. One of the two is a POST, so the stream is driven off a
 * normal request with a streamed body rather than an EventSource-style helper.
 */
object Sse {

    private const val DONE = "[DONE]"

    /**
     * Streams a MisarMail SSE endpoint as a cold [Flow], emitting one decoded
     * payload per event. Collecting the flow opens the connection; cancelling
     * the collector closes it.
     */
    fun stream(
        url: String,
        apiKey: String,
        method: String = "GET",
        body: Any? = null,
    ): Flow<Map<String, Any?>> = flow {
        // A stream has no useful deadline, so it gets its own client rather
        // than inheriting the transport's per-request timeout.
        val http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(30)).build()

        val builder = HttpRequest.newBuilder(URI.create(url))
            .header("Authorization", "Bearer $apiKey")
            .header("Accept", "text/event-stream")

        if (body != null) {
            builder.header("Content-Type", "application/json")
            builder.method(method, HttpRequest.BodyPublishers.ofString(Json.write(body)))
        } else {
            builder.method(method, HttpRequest.BodyPublishers.noBody())
        }

        val response = http.send(builder.build(), HttpResponse.BodyHandlers.ofLines())

        if (response.statusCode() >= 400) {
            // Errors arrive as a normal JSON body, not as an SSE frame.
            val raw = response.body().toList().joinToString("\n")
            val data = Json.readObject(raw)
            throw MisarMailException(
                response.statusCode(),
                (data["error"] ?: "stream failed").toString(),
                "api_error",
            )
        }

        for (line in response.body()) {
            if (!line.startsWith("data:")) continue

            val payload = line.substring(5).trim()
            if (payload == DONE) return@flow
            if (payload.isEmpty()) continue

            val decoded = Json.readObject(payload)
            // One malformed frame should not discard everything already streamed.
            emit(if (decoded.isEmpty()) mapOf("raw" to payload) else decoded)
        }
    }.flowOn(Dispatchers.IO)
}
