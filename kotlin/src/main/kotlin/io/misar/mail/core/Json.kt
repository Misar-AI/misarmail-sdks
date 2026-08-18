package io.misar.mail.core

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import io.misar.mail.MisarMailException

/**
 * JSON encoding for the transport.
 *
 * Wrapped in one place so the rest of the SDK never touches the mapper directly
 * and never has to decide what a decode failure means: a body that will not
 * parse surfaces as an ordinary SDK exception rather than leaking a
 * Jackson-specific one through the public API.
 */
object Json {
    private val mapper: ObjectMapper = ObjectMapper().registerKotlinModule()

    fun write(value: Any): String =
        try {
            mapper.writeValueAsString(value)
        } catch (e: Exception) {
            throw MisarMailException(0, "could not encode request body: ${e.message}", "client_error")
        }

    @Suppress("UNCHECKED_CAST")
    fun readObject(raw: String): Map<String, Any?> =
        try {
            mapper.readValue(raw, Map::class.java) as Map<String, Any?>
        } catch (e: Exception) {
            // A non-JSON error body is still an error; the status carries the meaning.
            emptyMap()
        }
}
