package io.misar.mail

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import okhttp3.Call
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull

class MisarMailClientTest {

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun mockHttpClient(statusCode: Int, body: String): OkHttpClient {
        val client = mockk<OkHttpClient>()
        val call = mockk<Call>()
        val requestSlot = slot<Request>()

        every { client.newCall(capture(requestSlot)) } returns call
        every { call.execute() } returns Response.Builder()
            .request(requestSlot.captured)
            .protocol(Protocol.HTTP_1_1)
            .code(statusCode)
            .message("OK")
            .body(body.toResponseBody())
            .build()

        return client
    }

    /** Build a client whose HTTP layer is fully mocked. */
    private fun clientWith(statusCode: Int, body: String): MisarMailClient =
        MisarMailClient(
            apiKey = "your_api_key_here",
            baseUrl = "https://mail.misar.io/api/v1",
            maxRetries = 1,        // single attempt — no real back-off in unit tests
            httpClient = mockHttpClient(statusCode, body),
        )

    // -------------------------------------------------------------------------
    // Tests
    // -------------------------------------------------------------------------

    @Test
    fun `sendEmail returns parsed response on 200`() {
        val client = clientWith(200, """{"id":"msg_123","status":"queued"}""")
        val result = client.sendEmail(mapOf("to" to "test@example.com", "subject" to "Hi"))
        assertEquals("msg_123", result["id"])
        assertEquals("queued", result["status"])
    }

    @Test
    fun `contactsList returns parsed response on 200`() {
        val client = clientWith(200, """{"data":[{"id":"c1","email":"a@b.com"}]}""")
        val result = client.contactsList()
        assertNotNull(result["data"])
    }

    @Test
    fun `contactsCreate returns parsed response on 201`() {
        val client = clientWith(201, """{"id":"c2","email":"new@example.com"}""")
        val result = client.contactsCreate(mapOf("email" to "new@example.com"))
        assertEquals("c2", result["id"])
    }

    @Test
    fun `analyticsGet returns parsed response on 200`() {
        val client = clientWith(200, """{"opens":10,"clicks":3}""")
        val result = client.analyticsGet("camp_abc")
        assertEquals(10.0, result["opens"])
    }

    @Test
    fun `validateEmail returns parsed response on 200`() {
        val client = clientWith(200, """{"valid":true,"email":"test@example.com"}""")
        val result = client.validateEmail("test@example.com")
        assertEquals(true, result["valid"])
    }

    @Test
    fun `templatesRender returns parsed response on 200`() {
        val client = clientWith(200, """{"html":"<p>Hello World</p>"}""")
        val result = client.templatesRender("tmpl_1", mapOf("name" to "World"))
        assertEquals("<p>Hello World</p>", result["html"])
    }

    @Test
    fun `non-2xx throws MisarMailException with correct status`() {
        val client = clientWith(401, """{"error":"Unauthorized"}""")
        val ex = assertFailsWith<MisarMailException> {
            client.sendEmail(mapOf("to" to "x@y.com"))
        }
        assertEquals(401, ex.status)
    }

    @Test
    fun `404 throws MisarMailException`() {
        val client = clientWith(404, """{"error":"not found"}""")
        val ex = assertFailsWith<MisarMailException> {
            client.analyticsGet("nonexistent")
        }
        assertEquals(404, ex.status)
    }

    @Test
    fun `empty body on 200 returns empty map`() {
        val client = clientWith(200, "")
        val result = client.sandboxList()
        assertEquals(emptyMap(), result)
    }

    @Test
    fun `trackEvent returns parsed response`() {
        val client = clientWith(200, """{"tracked":true}""")
        val result = client.trackEvent(mapOf("event" to "signup", "email" to "u@x.com"))
        assertEquals(true, result["tracked"])
    }

    @Test
    fun `trackPurchase returns parsed response`() {
        val client = clientWith(200, """{"tracked":true}""")
        val result = client.trackPurchase(mapOf("email" to "u@x.com", "amount" to 99.0))
        assertEquals(true, result["tracked"])
    }
}
