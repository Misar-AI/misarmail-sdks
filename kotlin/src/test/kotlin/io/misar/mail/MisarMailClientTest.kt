package io.misar.mail

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.toList
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicInteger
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Exercises the client against a real HTTP server.
 *
 * The JDK's own [HttpServer] rather than a mocking library: the client is built
 * on java.net.http, so a real socket tests the transport that actually ships —
 * and the SSE tests need a server that can flush a body in pieces, which is
 * where frame-boundary bugs live.
 */
class MisarMailClientTest {

    private lateinit var server: HttpServer
    private var port = 0
    private val requests = AtomicInteger(0)

    /** Routes registered per test, keyed by path. */
    private val routes = mutableMapOf<String, (HttpExchange) -> Unit>()

    @BeforeTest
    fun start() {
        server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        port = server.address.port
        server.createContext("/") { exchange ->
            requests.incrementAndGet()
            val handler = routes[exchange.requestURI.path]
            if (handler == null) {
                respond(exchange, 404, """{"error":"no route for ${exchange.requestURI.path}"}""")
            } else {
                handler(exchange)
            }
        }
        server.executor = null
        server.start()
    }

    @AfterTest
    fun stop() = server.stop(0)

    private fun client(maxRetries: Int = 1) =
        MisarMailClient("test-key", "http://127.0.0.1:$port/mail/v1", maxRetries)

    private fun respond(
        exchange: HttpExchange,
        status: Int,
        body: String,
        headers: Map<String, String> = emptyMap(),
    ) {
        exchange.responseHeaders.add("Content-Type", "application/json")
        headers.forEach { (k, v) -> exchange.responseHeaders.add(k, v) }
        val bytes = body.toByteArray()
        exchange.sendResponseHeaders(status, bytes.size.toLong())
        exchange.responseBody.use { it.write(bytes) }
    }

    /** Writes an SSE body, flushing after each piece so frames arrive split. */
    private fun sse(exchange: HttpExchange, vararg pieces: String) {
        exchange.responseHeaders.add("Content-Type", "text/event-stream")
        exchange.sendResponseHeaders(200, 0)
        exchange.responseBody.use { out ->
            pieces.forEach { piece ->
                out.write(piece.toByteArray())
                out.flush()
            }
        }
    }

    // -------------------------------------------------------------------------
    // REST
    // -------------------------------------------------------------------------

    @Test
    fun `email send returns the parsed body`() = runBlocking {
        routes["/mail/v1/send"] = { respond(it, 200, """{"success":true,"message_id":"msg_123"}""") }

        val result = client().email.send(mapOf("from" to "a@b.com", "to" to listOf("c@d.com")))

        assertEquals(true, result["success"])
        assertEquals("msg_123", result["message_id"])
    }

    @Test
    fun `contacts list returns data`() = runBlocking {
        routes["/mail/v1/contacts"] = {
            respond(it, 200, """{"data":[{"id":"c1","email":"a@b.com"}],"total":1}""")
        }

        val result = client().contacts.list()

        @Suppress("UNCHECKED_CAST")
        val data = result["data"] as List<Map<String, Any>>
        assertEquals("a@b.com", data[0]["email"])
    }

    @Test
    fun `plan reports the subscription behind the key`() = runBlocking {
        routes["/mail/v1/plan"] = {
            respond(it, 200, """{"plan":{"slug":"pro"},"limits":{"emails_per_month":50000}}""")
        }

        val result = client().plan.get()

        @Suppress("UNCHECKED_CAST")
        val plan = result["plan"] as Map<String, Any>
        assertEquals("pro", plan["slug"])
    }

    @Test
    fun `unauthorized raises with the status`() = runBlocking {
        routes["/mail/v1/contacts"] = { respond(it, 401, """{"error":"unauthorized"}""") }

        val ex = assertFailsWith<MisarMailException> { client().contacts.list() }
        assertEquals(401, ex.status)
    }

    @Test
    fun `retries a 503 then succeeds`() = runBlocking {
        val attempts = AtomicInteger(0)
        routes["/mail/v1/templates"] = { exchange ->
            if (attempts.incrementAndGet() < 3) {
                respond(exchange, 503, """{"error":"unavailable"}""")
            } else {
                respond(exchange, 200, """{"data":[{"id":"t1"}]}""")
            }
        }

        val result = client(maxRetries = 3).templates.list()

        @Suppress("UNCHECKED_CAST")
        val data = result["data"] as List<Map<String, Any>>
        assertEquals("t1", data[0]["id"])
        assertEquals(3, attempts.get())
    }

    // -------------------------------------------------------------------------
    // Plan limits
    // -------------------------------------------------------------------------

    @Test
    fun `spent allowance raises PlanLimitException and is not retried`() = runBlocking {
        val attempts = AtomicInteger(0)
        routes["/mail/v1/campaigns"] = { exchange ->
            attempts.incrementAndGet()
            respond(
                exchange, 429,
                """{"code":"plan_limit_exceeded","error":"monthly campaign allowance spent",
                    "upgrade":{"feature":"campaigns","currentPlanSlug":"starter",
                    "urls":{"pricing":"https://misarmail.com/pricing"}}}""",
                mapOf("X-Misar-Plan" to "starter", "Retry-After" to "3600"),
            )
        }

        // maxRetries 3, so a plain retryable 429 would have been retried twice more.
        val ex = assertFailsWith<PlanLimitException> {
            client(maxRetries = 3).campaigns.create(mapOf("name" to "Blast"))
        }

        assertEquals(429, ex.status)
        assertEquals("starter", ex.plan)
        assertEquals("campaigns", ex.feature)
        assertEquals(3600, ex.retryAfter)
        assertEquals("https://misarmail.com/pricing", ex.upgradeUrl)

        // A spent allowance cannot be fixed by retrying.
        assertEquals(1, attempts.get())
    }

    // -------------------------------------------------------------------------
    // Server-Sent Events
    // -------------------------------------------------------------------------

    @Test
    fun `generateEmail emits each frame`() = runBlocking {
        routes["/mail/ai/generate-email/stream"] = { exchange ->
            // The frame boundary is deliberately split across two writes.
            sse(
                exchange,
                "data: {\"delta\":\"Hel\"}\n",
                "\ndata: {\"delta\":\"lo\"}\n\n",
                ": keepalive\n\n",
                "data: {\"delta\":\"!\"}\n\n",
                "data: [DONE]\n\n",
            )
        }

        val deltas = client().streaming.generateEmail(mapOf("prompt" to "hi"))
            .toList()
            .map { it.data?.get("delta") }

        assertEquals(listOf("Hel", "lo", "!"), deltas)
    }

    @Test
    fun `stream stops at the DONE sentinel`() = runBlocking {
        routes["/mail/campaigns/camp1/send-stream"] = { exchange ->
            sse(
                exchange,
                "data: {\"sent\":1}\n\n",
                "data: [DONE]\n\n",
                "data: {\"sent\":999}\n\n",
            )
        }

        val seen = client().streaming.campaignSend("camp1").toList()

        // Anything after the sentinel must never be delivered.
        assertEquals(1, seen.size)
        assertEquals("""{"sent":1}""", seen[0].raw)
    }

    @Test
    fun `stream uses the unversioned api base`() = runBlocking {
        // Registering the path without /v1 is the assertion: if the client used
        // the versioned base the request would 404 and this would throw.
        routes["/mail/campaigns/camp1/send-stream"] = { sse(it, "data: [DONE]\n\n") }

        val seen = client().streaming.campaignSend("camp1").toList()
        assertTrue(seen.isEmpty())
    }

    @Test
    fun `stream refusal raises PlanLimitException before any frame`() = runBlocking {
        routes["/mail/campaigns/locked/send-stream"] = { exchange ->
            respond(
                exchange, 402,
                """{"code":"plan_limit_exceeded","error":"streaming is not on your plan",
                    "upgrade":{"feature":"campaign_streaming",
                    "urls":{"pricing":"https://misarmail.com/pricing"}}}""",
                mapOf("X-Misar-Plan" to "free"),
            )
        }

        val ex = assertFailsWith<PlanLimitException> {
            client().streaming.campaignSend("locked").toList()
        }

        assertEquals(402, ex.status)
        assertEquals("free", ex.plan)
        assertEquals("campaign_streaming", ex.feature)
    }

    @Test
    fun `non-json stream payload still arrives as raw`() = runBlocking {
        routes["/mail/campaigns/camp1/send-stream"] = { exchange ->
            sse(exchange, "data: not json\n\n", "data: [DONE]\n\n")
        }

        val seen = client().streaming.campaignSend("camp1").toList()

        assertEquals(1, seen.size)
        assertNull(seen[0].data)
        assertEquals("not json", seen[0].raw)
    }
}
