package io.misar.mail

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withContext
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.time.Duration

/**
 * MisarMail API client.
 *
 * All suspend methods perform up to [maxRetries] attempts with exponential
 * back-off (starting at 500 ms) on retryable HTTP statuses (429, 500, 502, 503, 504).
 *
 * Usage:
 * ```kotlin
 * val client = MisarMailClient("msk_...")
 * val result = client.email.send(mapOf("to" to "user@example.com", "subject" to "Hello"))
 * ```
 */
class MisarMailClient(
    private val apiKey: String,
    private val baseUrl: String = "https://api.misar.io/mail/v1",
    private val maxRetries: Int = 3,
) {
    private val normalizedBase = baseUrl.trimEnd('/')
    private val apiBase = normalizedBase.removeSuffix("/v1")

    private val http: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(10))
        .build()

    private val mapper = jacksonObjectMapper()

    // ── resource accessors ────────────────────────────────────────────────────
    val plan = PlanResource()
    val streaming = StreamingResource()
    val ai = AiResource()
    val creditRates = CreditRatesResource()
    val deliverability = DeliverabilityResource()
    val dmarc = DmarcResource()
    val emailAccounts = EmailAccountsResource()
    val emails = EmailsResource()
    val landingPages = LandingPagesResource()
    val monetization = MonetizationResource()
    val revenue = RevenueResource()
    val segments = SegmentsResource()
    val subscription = SubscriptionResource()
    val teamMembers = TeamMembersResource()
    val wallet = WalletResource()
    val warmup = WarmupResource()
    val email = EmailResource()
    val contacts = ContactsResource()
    val campaigns = CampaignsResource()
    val templates = TemplatesResource()
    val automations = AutomationsResource()
    val domains = DomainsResource()
    val dedicatedIps = DedicatedIpsResource()
    val abTests = AbTestsResource()
    val sandbox = SandboxResource()
    val inbound = InboundResource()
    val analytics = AnalyticsResource()
    val track = TrackResource()
    val keys = KeysResource()
    val validate = ValidateResource()
    val webhooks = WebhooksResource()
    val usage = UsageResource()
    val billing = BillingResource()

    // ── Core HTTP ─────────────────────────────────────────────────────────────

    /** Like [toQueryString] but drops null values — used by the generated resources. */
    private fun Map<String, Any?>.toQueryStringOrEmpty(): String {
        val set = filterValues { it != null }
        if (set.isEmpty()) return ""
        return "?" + set.entries.joinToString("&") { (k, v) ->
            "${URLEncoder.encode(k, StandardCharsets.UTF_8)}=${URLEncoder.encode(v.toString(), StandardCharsets.UTF_8)}"
        }
    }

    /** Percent-encodes a path segment. */
    private fun enc(s: String): String = URLEncoder.encode(s, StandardCharsets.UTF_8)

    private fun Map<String, Any>.toQueryString(): String {
        if (isEmpty()) return ""
        return "?" + entries.joinToString("&") { (k, v) ->
            "${URLEncoder.encode(k, StandardCharsets.UTF_8)}=${URLEncoder.encode(v.toString(), StandardCharsets.UTF_8)}"
        }
    }

    private suspend fun requestUrl(method: String, url: String, body: Any? = null): Map<String, Any> =
        withContext(Dispatchers.IO) {
            val bodyStr = if (body != null) mapper.writeValueAsString(body) else "{}"
            var lastException: Exception? = null
            var delay = 500L

            repeat(maxRetries) { attempt ->
                if (attempt > 0) Thread.sleep(delay).also { delay *= 2 }

                val bodyPublisher = when (method) {
                    "GET", "DELETE" -> HttpRequest.BodyPublishers.noBody()
                    else -> HttpRequest.BodyPublishers.ofString(bodyStr)
                }

                val request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(30))
                    .header("Authorization", "Bearer $apiKey")
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json")
                    .method(method, bodyPublisher)
                    .build()

                val response: HttpResponse<String>
                try {
                    response = http.send(request, HttpResponse.BodyHandlers.ofString())
                } catch (e: Exception) {
                    lastException = MisarMailNetworkException(e.message ?: "network error")
                    return@repeat
                }

                val status = response.statusCode()

                // A rate-limit 429 and a spent-allowance 429 are identical by
                // status, so the body decides. Only the first is worth retrying.
                if (isPlanLimit(response.body())) {
                    throw planLimitException(status, response)
                }

                if (status in RETRYABLE && attempt < maxRetries - 1) {
                    lastException = MisarMailException(status, response.body() ?: "retryable error")
                    return@repeat
                }

                if (status in 200..299) {
                    val rb = response.body()
                    if (rb.isNullOrBlank()) return@withContext emptyMap()
                    return@withContext mapper.readValue<Map<String, Any>>(rb)
                }

                val msg = runCatching {
                    mapper.readValue<Map<String, Any>>(response.body() ?: "")["error"] as? String
                }.getOrNull() ?: response.body()?.ifBlank { "error" } ?: "error"

                throw MisarMailException(status, msg)
            }

            throw lastException ?: MisarMailNetworkException("max retries exceeded")
        }

    private suspend fun request(method: String, path: String, body: Any? = null): Map<String, Any> =
        requestUrl(method, "$normalizedBase$path", body)

    private suspend fun requestApi(method: String, path: String, body: Any? = null): Map<String, Any> =
        requestUrl(method, "$apiBase$path", body)

    // ── Resources ─────────────────────────────────────────────────────────────

    /** POST /send */
    inner class EmailResource {
        suspend fun send(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/send", data)
    }

    /** /contacts */
    inner class ContactsResource {
        suspend fun list(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/contacts${params.toQueryString()}")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/contacts", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/contacts/$id")

        suspend fun update(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/contacts/$id", data)

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/contacts/$id")

        suspend fun importContacts(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/contacts/import", data)
    }

    /** /campaigns */
    inner class CampaignsResource {
        suspend fun list(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/campaigns${params.toQueryString()}")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/campaigns", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/campaigns/$id")

        suspend fun update(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/campaigns/$id", data)

        suspend fun send(id: String): Map<String, Any> =
            request("POST", "/campaigns/$id/send")

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/campaigns/$id")
    }

    /** /templates */
    inner class TemplatesResource {
        suspend fun list(): Map<String, Any> =
            request("GET", "/templates")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/templates", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/templates/$id")

        suspend fun update(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/templates/$id", data)

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/templates/$id")

        suspend fun render(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/templates/render", data)
    }

    /** /automations */
    inner class AutomationsResource {
        suspend fun list(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/automations${params.toQueryString()}")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/automations", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/automations/$id")

        suspend fun update(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/automations/$id", data)

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/automations/$id")

        suspend fun activate(id: String, active: Boolean): Map<String, Any> =
            request("PATCH", "/automations/$id/activate", mapOf("active" to active))
    }

    /** /domains — served off /api, not /api/v1; dual-auth accepts an msk_ key. */
    inner class DomainsResource {
        suspend fun list(): Map<String, Any> =
            requestApi("GET", "/domains")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            requestApi("POST", "/domains", data)

        suspend fun get(id: String): Map<String, Any> =
            requestApi("GET", "/domains/$id")

        suspend fun verify(id: String): Map<String, Any> =
            requestApi("POST", "/domains/$id/verify")

        suspend fun delete(id: String): Map<String, Any> =
            requestApi("DELETE", "/domains/$id")
    }


    /** /dedicated-ips */
    inner class DedicatedIpsResource {
        suspend fun list(): Map<String, Any> =
            request("GET", "/dedicated-ips")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/dedicated-ips", data)

        suspend fun update(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/dedicated-ips/$id", data)

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/dedicated-ips/$id")
    }

    /** /ab-tests */
    inner class AbTestsResource {
        suspend fun list(): Map<String, Any> =
            request("GET", "/ab-tests")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/ab-tests", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/ab-tests/$id")

        suspend fun setWinner(id: String, variantId: String): Map<String, Any> =
            request("POST", "/ab-tests/$id/winner", mapOf("variantId" to variantId))
    }

    /** /sandbox */
    inner class SandboxResource {
        suspend fun send(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/sandbox/send", data)

        suspend fun list(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/sandbox${params.toQueryString()}")

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/sandbox/$id")
    }

    /** /inbound */
    inner class InboundResource {
        suspend fun list(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/inbound${params.toQueryString()}")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/inbound", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/inbound/$id")

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/inbound/$id")
    }

    /** /analytics */
    inner class AnalyticsResource {
        suspend fun overview(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/analytics${params.toQueryString()}")
    }

    /** /track */
    inner class TrackResource {
        suspend fun event(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/track/event", data)

        suspend fun purchase(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/track/purchase", data)
    }

    /** /keys */
    inner class KeysResource {
        suspend fun list(): Map<String, Any> =
            request("GET", "/keys")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/keys", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/keys/$id")

        suspend fun revoke(id: String): Map<String, Any> =
            request("DELETE", "/keys/$id")
    }

    /** /validate */
    inner class ValidateResource {
        suspend fun email(address: String): Map<String, Any> =
            request("POST", "/validate", mapOf("email" to address))
    }

    /** /webhooks */
    inner class WebhooksResource {
        suspend fun list(): Map<String, Any> =
            request("GET", "/webhooks")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/webhooks", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/webhooks/$id")

        suspend fun update(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/webhooks/$id", data)

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/webhooks/$id")

        suspend fun test(id: String): Map<String, Any> =
            request("POST", "/webhooks/$id/test")
    }

    /** /usage */
    inner class UsageResource {
        suspend fun get(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/usage${params.toQueryString()}")
    }

    /** /billing (uses apiBase) */
    inner class BillingResource {
        suspend fun subscription(): Map<String, Any> =
            requestApi("GET", "/billing/subscription")

        suspend fun checkout(data: Map<String, Any>): Map<String, Any> =
            requestApi("POST", "/billing/checkout", data)
    }


    companion object {
        private val RETRYABLE = setOf(429, 500, 502, 503, 504)
    }

    /** True when the body carries the API's plan-refusal marker. */
    private fun isPlanLimit(body: String?): Boolean {
        if (body.isNullOrBlank()) return false
        return runCatching {
            val m = mapper.readValue<Map<String, Any>>(body)
            m["code"] == "plan_limit_exceeded" ||
                m["error_type"] == "plan_limit_exceeded" ||
                m["upgrade"] is Map<*, *>
        }.getOrDefault(false)
    }

    private fun planLimitException(status: Int, response: HttpResponse<String>): PlanLimitException {
        @Suppress("UNCHECKED_CAST")
        val root = runCatching {
            mapper.readValue<Map<String, Any>>(response.body() ?: "")
        }.getOrDefault(emptyMap())
        val offer = root["upgrade"] as? Map<String, Any> ?: emptyMap()

        @Suppress("UNCHECKED_CAST")
        val bodyPlan = offer["currentPlanSlug"]?.toString()
            ?: (offer["current_plan"] as? Map<String, Any>)?.get("slug")?.toString()
        @Suppress("UNCHECKED_CAST")
        val bodyUrl = (offer["urls"] as? Map<String, Any>)?.get("pricing")?.toString()

        // Headers are authoritative; the offer body is the fallback when a
        // proxy has stripped them.
        val header = { name: String -> response.headers().firstValue(name).orElse(null) }

        return PlanLimitException(
            status = status,
            message = root["error"]?.toString() ?: "plan limit exceeded",
            plan = header("x-misar-plan") ?: bodyPlan,
            upgradeUrl = header("x-misar-upgrade-url") ?: bodyUrl,
            retryAfter = header("retry-after")?.toIntOrNull(),
            feature = offer["feature"]?.toString(),
        )
    }

    /**
     * Live subscription standing for the key's owner.
     *
     * Read this before an expensive call rather than discovering the ceiling
     * through a [PlanLimitException]: `usage` reports every metered feature and
     * `upgrade` is non-null as soon as one is spent.
     */
    inner class PlanResource {
        /** `GET /plan` — plan, allowances, per-feature usage, upgrade offer. */
        suspend fun get(): Map<String, Any> = request("GET", "/plan")

        /** `GET /monetization/stats` — revenue and monetization counters. */
        suspend fun monetization(): Map<String, Any> = request("GET", "/monetization/stats")
    }

    // ── Generated from scripts/sdk-endpoint-spec.json ────────────────────────
    //
    // These twenty endpoints were missing from every SDK except TypeScript.

    /** ai — generated. */
    inner class AiResource {
        /** `POST /ai/subject-lines` */
        suspend fun subjectLines(body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("POST", "/ai/subject-lines", body)

    }

    /** creditRates — generated. */
    inner class CreditRatesResource {
        /** `GET /credit-rates` */
        suspend fun list(): Map<String, Any> = request("GET", "/credit-rates")

    }

    /** deliverability — generated. */
    inner class DeliverabilityResource {
        /** `GET /deliverability/audit` */
        suspend fun audit(): Map<String, Any> = request("GET", "/deliverability/audit")

        /** `GET /deliverability/score` */
        suspend fun score(): Map<String, Any> = request("GET", "/deliverability/score")

    }

    /** dmarc — generated. */
    inner class DmarcResource {
        /** `GET /dmarc/check` */
        suspend fun check(domain: String? = null, dkim_selector: String? = null): Map<String, Any> = request("GET", "/dmarc/check" + mapOf("domain" to domain, "dkim_selector" to dkim_selector).toQueryStringOrEmpty())

        /** `GET /dmarc/domains` */
        suspend fun listDomains(): Map<String, Any> = request("GET", "/dmarc/domains")

        /** `POST /dmarc/domains` */
        suspend fun addDomain(body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("POST", "/dmarc/domains", body)

        /** `DELETE /dmarc/domains` */
        suspend fun removeDomain(domain_id: String? = null): Map<String, Any> = request("DELETE", "/dmarc/domains" + mapOf("domain_id" to domain_id).toQueryStringOrEmpty())

    }

    /** emailAccounts — generated. */
    inner class EmailAccountsResource {
        /** `GET /email-accounts` */
        suspend fun list(): Map<String, Any> = request("GET", "/email-accounts")

    }

    /** emails — generated. */
    inner class EmailsResource {
        /** `GET /emails` */
        suspend fun list(folder: String? = null, search: String? = null, limit: Int? = null): Map<String, Any> = request("GET", "/emails" + mapOf("folder" to folder, "search" to search, "limit" to limit).toQueryStringOrEmpty())

        /** `GET /emails/:id` */
        suspend fun get(id: String): Map<String, Any> = request("GET", "/emails/${enc(id)}")

        /** `PATCH /emails/:id` */
        suspend fun update(id: String, body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("PATCH", "/emails/${enc(id)}", body)

    }

    /** landingPages — generated. */
    inner class LandingPagesResource {
        /** `POST /landing-pages` */
        suspend fun create(body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("POST", "/landing-pages", body)

    }

    /** monetization — generated. */
    inner class MonetizationResource {
        /** `POST /monetization/tip` */
        suspend fun tip(body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("POST", "/monetization/tip", body)

    }

    /** revenue — generated. */
    inner class RevenueResource {
        /** `GET /revenue/attribution` */
        suspend fun attribution(campaign_id: String? = null, period: String? = null): Map<String, Any> = request("GET", "/revenue/attribution" + mapOf("campaign_id" to campaign_id, "period" to period).toQueryStringOrEmpty())

    }

    /** segments — generated. */
    inner class SegmentsResource {
        /** `GET /segments/:id/members` */
        suspend fun members(id: String, page: Int? = null, limit: Int? = null): Map<String, Any> = request("GET", "/segments/${enc(id)}/members" + mapOf("page" to page, "limit" to limit).toQueryStringOrEmpty())

    }

    /** subscription — generated. */
    inner class SubscriptionResource {
        /** `GET /subscription` */
        suspend fun get(product: String? = null): Map<String, Any> = request("GET", "/subscription" + mapOf("product" to product).toQueryStringOrEmpty())

        /** `POST /subscription` */
        suspend fun upsert(body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("POST", "/subscription", body)

        /** `DELETE /subscription` */
        suspend fun cancel(body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("DELETE", "/subscription", body)

    }

    /** teamMembers — generated. */
    inner class TeamMembersResource {
        /** `GET /team-members` */
        suspend fun get(owner_id: String? = null): Map<String, Any> = request("GET", "/team-members" + mapOf("owner_id" to owner_id).toQueryStringOrEmpty())

    }

    /** wallet — generated. */
    inner class WalletResource {
        /** `GET /wallet` */
        suspend fun get(): Map<String, Any> = request("GET", "/wallet")

        /** `POST /wallet/credit` */
        suspend fun credit(body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("POST", "/wallet/credit", body)

        /** `POST /wallet/debit` */
        suspend fun debit(body: Map<String, Any?> = emptyMap()): Map<String, Any> = request("POST", "/wallet/debit", body)

    }

    /** warmup — generated. */
    inner class WarmupResource {
        /** `GET /warmup` */
        suspend fun get(): Map<String, Any> = request("GET", "/warmup")

    }

    // ── Server-Sent Events ───────────────────────────────────────────────────

    /**
     * The two Server-Sent Events endpoints.
     *
     * Both live outside `/v1`, so they use [apiBase]. Both are API-key
     * authenticated and metered, so a plan refusal on open throws
     * [PlanLimitException] exactly as a non-streaming call would.
     */
    inner class StreamingResource {

        /**
         * `POST /api/ai/generate-email/stream` — token-by-token generation.
         *
         * ```kotlin
         * mail.streaming.generateEmail(mapOf("prompt" to "…")).collect { frame ->
         *     print(frame.data?.get("delta") ?: "")
         * }
         * ```
         */
        fun generateEmail(body: Map<String, Any?> = emptyMap()): Flow<StreamEvent> =
            sseFlow("POST", "/ai/generate-email/stream", body)

        /** `GET /api/campaigns/{id}/send-stream` — live send progress. */
        fun campaignSend(campaignId: String): Flow<StreamEvent> =
            sseFlow("GET", "/campaigns/${enc(campaignId)}/send-stream", null)
    }

    /**
     * Opens an SSE connection and emits each frame.
     *
     * Deliberately not retried: replaying a stream that failed mid-flight would
     * duplicate whatever the caller already consumed.
     */
    private fun sseFlow(method: String, path: String, body: Map<String, Any?>?): Flow<StreamEvent> = flow {
        val publisher = if (body != null) {
            HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(body))
        } else {
            HttpRequest.BodyPublishers.noBody()
        }

        val request = HttpRequest.newBuilder()
            .uri(URI.create("$apiBase$path"))
            .header("Authorization", "Bearer $apiKey")
            .header("Accept", "text/event-stream")
            .header("Content-Type", "application/json")
            .method(method, publisher)
            .build()

        val response = withContext(Dispatchers.IO) {
            http.send(request, HttpResponse.BodyHandlers.ofLines())
        }

        val status = response.statusCode()
        if (status !in 200..299) {
            // The body is a line stream even on an error, so rejoin it to read
            // the JSON envelope.
            val raw = response.body().toList().joinToString("\n")
            if (isPlanLimit(raw)) throw planLimitFromBody(status, raw, response)
            throw MisarMailException(status, messageFrom(raw))
        }

        var eventName: String? = null
        val dataLines = mutableListOf<String>()

        // ofLines() already splits on line terminators, so a frame ends at the
        // first empty line rather than a "\n\n" scan.
        for (rawLine in response.body()) {
            val line = rawLine.removeSuffix("\r")

            if (line.isEmpty()) {
                val frame = buildFrame(eventName, dataLines)
                eventName = null
                dataLines.clear()
                if (frame === DONE_FRAME) return@flow
                if (frame != null) emit(frame)
                continue
            }
            if (line.startsWith(":")) continue // keepalive
            when {
                line.startsWith("event:") -> eventName = line.removePrefix("event:").trim()
                line.startsWith("data:") -> dataLines.add(line.removePrefix("data:").removePrefix(" "))
            }
        }
        // A trailing frame with no closing blank line.
        val tail = buildFrame(eventName, dataLines)
        if (tail != null && tail !== DONE_FRAME) emit(tail)
    }

    /** Builds a frame, or returns [DONE_FRAME] for the sentinel, or null. */
    private fun buildFrame(event: String?, dataLines: List<String>): StreamEvent? {
        if (dataLines.isEmpty()) return null
        val raw = dataLines.joinToString("\n")
        if (raw == "[DONE]") return DONE_FRAME
        val decoded = runCatching { mapper.readValue<Map<String, Any>>(raw) }.getOrNull()
        return StreamEvent(event, decoded, raw)
    }

    /** Pulls the human-readable message out of an error envelope. */
    private fun messageFrom(body: String?): String {
        if (body.isNullOrBlank()) return "error"
        return runCatching {
            mapper.readValue<Map<String, Any>>(body)["error"]?.toString()
        }.getOrNull() ?: body
    }

    private fun planLimitFromBody(
        status: Int,
        raw: String,
        response: HttpResponse<*>,
    ): PlanLimitException {
        @Suppress("UNCHECKED_CAST")
        val root = runCatching { mapper.readValue<Map<String, Any>>(raw) }.getOrDefault(emptyMap())
        @Suppress("UNCHECKED_CAST")
        val offer = root["upgrade"] as? Map<String, Any> ?: emptyMap()
        @Suppress("UNCHECKED_CAST")
        val bodyUrl = (offer["urls"] as? Map<String, Any>)?.get("pricing")?.toString()
        val header = { name: String -> response.headers().firstValue(name).orElse(null) }

        return PlanLimitException(
            status = status,
            message = messageFrom(raw),
            plan = header("x-misar-plan") ?: offer["currentPlanSlug"]?.toString(),
            upgradeUrl = header("x-misar-upgrade-url") ?: bodyUrl,
            retryAfter = header("retry-after")?.toIntOrNull(),
            feature = offer["feature"]?.toString(),
        )
    }
}

/**
 * One decoded SSE frame.
 *
 * MisarMail emits unnamed frames — `data: {...}` with no `event:` line — so
 * [event] is normally null. [data] is the decoded JSON; [raw] is always the
 * payload exactly as received.
 */
data class StreamEvent(
    val event: String?,
    val data: Map<String, Any>?,
    val raw: String,
)

/** Marker returned by the frame builder for the `[DONE]` sentinel. */
private val DONE_FRAME = StreamEvent(null, null, "[DONE]")

