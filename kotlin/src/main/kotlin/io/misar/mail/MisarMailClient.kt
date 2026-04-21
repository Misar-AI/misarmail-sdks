package io.misar.mail

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import kotlinx.coroutines.Dispatchers
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
    private val baseUrl: String = "https://mail.misar.io/api/v1",
    private val maxRetries: Int = 3,
) {
    private val normalizedBase = baseUrl.trimEnd('/')
    private val apiBase = normalizedBase.removeSuffix("/v1")

    private val http: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(10))
        .build()

    private val mapper = jacksonObjectMapper()

    // ── resource accessors ────────────────────────────────────────────────────
    val email = EmailResource()
    val contacts = ContactsResource()
    val campaigns = CampaignsResource()
    val templates = TemplatesResource()
    val automations = AutomationsResource()
    val domains = DomainsResource()
    val aliases = AliasesResource()
    val dedicatedIps = DedicatedIpsResource()
    val channels = ChannelsResource()
    val abTests = AbTestsResource()
    val sandbox = SandboxResource()
    val inbound = InboundResource()
    val analytics = AnalyticsResource()
    val track = TrackResource()
    val keys = KeysResource()
    val validate = ValidateResource()
    val leads = LeadsResource()
    val autopilot = AutopilotResource()
    val salesAgent = SalesAgentResource()
    val crm = CrmResource()
    val webhooks = WebhooksResource()
    val usage = UsageResource()
    val billing = BillingResource()
    val workspaces = WorkspacesResource()

    // ── Core HTTP ─────────────────────────────────────────────────────────────

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

    /** /domains */
    inner class DomainsResource {
        suspend fun list(): Map<String, Any> =
            request("GET", "/domains")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/domains", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/domains/$id")

        suspend fun verify(id: String): Map<String, Any> =
            request("POST", "/domains/$id/verify")

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/domains/$id")
    }

    /** /aliases */
    inner class AliasesResource {
        suspend fun list(): Map<String, Any> =
            request("GET", "/aliases")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/aliases", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/aliases/$id")

        suspend fun update(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/aliases/$id", data)

        suspend fun delete(id: String): Map<String, Any> =
            request("DELETE", "/aliases/$id")
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

    /** /channels */
    inner class ChannelsResource {
        suspend fun sendWhatsApp(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/channels/whatsapp/send", data)

        suspend fun sendPush(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/channels/push/send", data)
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
            request("GET", "/analytics/overview${params.toQueryString()}")
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
            request("POST", "/validate/email", mapOf("email" to address))
    }

    /** /leads */
    inner class LeadsResource {
        suspend fun search(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/leads/search", data)

        suspend fun getJob(id: String): Map<String, Any> =
            request("GET", "/leads/jobs/$id")

        suspend fun listJobs(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/leads/jobs${params.toQueryString()}")

        suspend fun results(jobId: String): Map<String, Any> =
            request("GET", "/leads/jobs/$jobId/results")

        suspend fun importLeads(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/leads/import", data)

        suspend fun credits(): Map<String, Any> =
            request("GET", "/leads/credits")
    }

    /** /autopilot */
    inner class AutopilotResource {
        suspend fun start(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/autopilot", data)

        suspend fun get(id: String): Map<String, Any> =
            request("GET", "/autopilot/$id")

        suspend fun list(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/autopilot${params.toQueryString()}")

        suspend fun dailyPlan(): Map<String, Any> =
            request("GET", "/autopilot/daily-plan")
    }

    /** /sales-agent */
    inner class SalesAgentResource {
        suspend fun getConfig(): Map<String, Any> =
            request("GET", "/sales-agent/config")

        suspend fun updateConfig(data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/sales-agent/config", data)

        suspend fun getActions(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/sales-agent/actions${params.toQueryString()}")
    }

    /** /crm */
    inner class CrmResource {
        suspend fun listConversations(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/crm/conversations${params.toQueryString()}")

        suspend fun getConversation(id: String): Map<String, Any> =
            request("GET", "/crm/conversations/$id")

        suspend fun updateConversation(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/crm/conversations/$id", data)

        suspend fun listMessages(conversationId: String): Map<String, Any> =
            request("GET", "/crm/conversations/$conversationId/messages")

        suspend fun listDeals(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/crm/deals${params.toQueryString()}")

        suspend fun createDeal(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/crm/deals", data)

        suspend fun getDeal(id: String): Map<String, Any> =
            request("GET", "/crm/deals/$id")

        suspend fun updateDeal(id: String, data: Map<String, Any>): Map<String, Any> =
            request("PATCH", "/crm/deals/$id", data)

        suspend fun deleteDeal(id: String): Map<String, Any> =
            request("DELETE", "/crm/deals/$id")

        suspend fun listClients(params: Map<String, Any> = emptyMap()): Map<String, Any> =
            request("GET", "/crm/clients${params.toQueryString()}")

        suspend fun createClient(data: Map<String, Any>): Map<String, Any> =
            request("POST", "/crm/clients", data)
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

    /** /workspaces (uses apiBase) */
    inner class WorkspacesResource {
        suspend fun list(): Map<String, Any> =
            requestApi("GET", "/workspaces")

        suspend fun create(data: Map<String, Any>): Map<String, Any> =
            requestApi("POST", "/workspaces", data)

        suspend fun get(id: String): Map<String, Any> =
            requestApi("GET", "/workspaces/$id")

        suspend fun update(id: String, data: Map<String, Any>): Map<String, Any> =
            requestApi("PATCH", "/workspaces/$id", data)

        suspend fun delete(id: String): Map<String, Any> =
            requestApi("DELETE", "/workspaces/$id")

        suspend fun listMembers(wsId: String): Map<String, Any> =
            requestApi("GET", "/workspaces/$wsId/members")

        suspend fun inviteMember(wsId: String, data: Map<String, Any>): Map<String, Any> =
            requestApi("POST", "/workspaces/$wsId/members", data)

        suspend fun updateMember(wsId: String, userId: String, data: Map<String, Any>): Map<String, Any> =
            requestApi("PATCH", "/workspaces/$wsId/members/$userId", data)

        suspend fun removeMember(wsId: String, userId: String): Map<String, Any> =
            requestApi("DELETE", "/workspaces/$wsId/members/$userId")
    }

    companion object {
        private val RETRYABLE = setOf(429, 500, 502, 503, 504)
    }
}
