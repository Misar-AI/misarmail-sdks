package io.misar.mail.core

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

/** Percent-encodes a single path or query component. */
fun enc(value: String): String =
    URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20")

/**
 * Query-string encoding shared by every generated GET/DELETE method.
 *
 * Returns "" for an empty map so a generated call site can always append
 * unconditionally.
 */
fun encodeQuery(params: Map<String, String?>): String {
    val pairs = params.entries
        .filter { it.value != null }
        .joinToString("&") { "${enc(it.key)}=${enc(it.value!!)}" }

    return if (pairs.isEmpty()) "" else "?$pairs"
}
