package io.misar.mail;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.stream.Collectors;

/**
 * MisarMail API client.
 *
 * <p>All methods perform up to {@code maxRetries} attempts with exponential
 * back-off (starting at 500 ms) on retryable HTTP statuses (429, 500, 502, 503, 504).
 *
 * <p>Use {@link Builder} to construct:
 * <pre>{@code
 * MisarMailClient client = new MisarMailClient.Builder("msk_...")
 *         .maxRetries(3)
 *         .build();
 * Map<String, Object> result = client.email.send(Map.of(
 *         "to", "user@example.com",
 *         "subject", "Hello"));
 * }</pre>
 */
public final class MisarMailClient {

    private static final Set<Integer> RETRYABLE = Set.of(429, 500, 502, 503, 504);
    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(10);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(30);

    private final String apiKey;
    private final String baseUrl;
    private final String apiBase;
    private final int maxRetries;
    private final HttpClient http;
    private final ObjectMapper mapper = new ObjectMapper();

    // ── resource accessors ────────────────────────────────────────────────────
    public final EmailResource email;
    public final ContactsResource contacts;
    public final CampaignsResource campaigns;
    public final TemplatesResource templates;
    public final AutomationsResource automations;
    public final DomainsResource domains;
    public final AliasesResource aliases;
    public final DedicatedIpsResource dedicatedIps;
    public final ChannelsResource channels;
    public final AbTestsResource abTests;
    public final SandboxResource sandbox;
    public final InboundResource inbound;
    public final AnalyticsResource analytics;
    public final TrackResource track;
    public final KeysResource keys;
    public final ValidateResource validate;
    public final LeadsResource leads;
    public final AutopilotResource autopilot;
    public final SalesAgentResource salesAgent;
    public final CrmResource crm;
    public final WebhooksResource webhooks;
    public final UsageResource usage;
    public final BillingResource billing;
    public final WorkspacesResource workspaces;

    private MisarMailClient(Builder b) {
        this.apiKey = b.apiKey;
        this.baseUrl = b.baseUrl.endsWith("/") ? b.baseUrl.substring(0, b.baseUrl.length() - 1) : b.baseUrl;
        this.apiBase = b.apiBase.endsWith("/") ? b.apiBase.substring(0, b.apiBase.length() - 1) : b.apiBase;
        this.maxRetries = b.maxRetries;
        this.http = b.httpClient != null ? b.httpClient
                : HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build();

        this.email = new EmailResource();
        this.contacts = new ContactsResource();
        this.campaigns = new CampaignsResource();
        this.templates = new TemplatesResource();
        this.automations = new AutomationsResource();
        this.domains = new DomainsResource();
        this.aliases = new AliasesResource();
        this.dedicatedIps = new DedicatedIpsResource();
        this.channels = new ChannelsResource();
        this.abTests = new AbTestsResource();
        this.sandbox = new SandboxResource();
        this.inbound = new InboundResource();
        this.analytics = new AnalyticsResource();
        this.track = new TrackResource();
        this.keys = new KeysResource();
        this.validate = new ValidateResource();
        this.leads = new LeadsResource();
        this.autopilot = new AutopilotResource();
        this.salesAgent = new SalesAgentResource();
        this.crm = new CrmResource();
        this.webhooks = new WebhooksResource();
        this.usage = new UsageResource();
        this.billing = new BillingResource();
        this.workspaces = new WorkspacesResource();
    }

    // ── Builder ───────────────────────────────────────────────────────────────

    public static final class Builder {
        private final String apiKey;
        private String baseUrl = "https://mail.misar.io/api/v1";
        private String apiBase = "https://mail.misar.io/api";
        private int maxRetries = 3;
        private HttpClient httpClient;

        public Builder(String apiKey) {
            if (apiKey == null || apiKey.isBlank()) throw new IllegalArgumentException("apiKey must not be blank");
            this.apiKey = apiKey;
        }

        public Builder baseUrl(String baseUrl) { this.baseUrl = baseUrl; return this; }
        public Builder apiBase(String apiBase) { this.apiBase = apiBase; return this; }
        public Builder maxRetries(int maxRetries) { this.maxRetries = maxRetries; return this; }
        public Builder httpClient(HttpClient httpClient) { this.httpClient = httpClient; return this; }
        public MisarMailClient build() { return new MisarMailClient(this); }
    }

    // ── Core HTTP ─────────────────────────────────────────────────────────────

    private String qs(Map<String, Object> params) {
        if (params == null || params.isEmpty()) return "";
        return "?" + params.entrySet().stream()
                .map(e -> enc(e.getKey()) + "=" + enc(String.valueOf(e.getValue())))
                .collect(Collectors.joining("&"));
    }

    private static String enc(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8);
    }

    @SuppressWarnings("unchecked")
    Map<String, Object> requestUrl(String method, String url, Object body) throws MisarMailException {
        String bodyStr;
        try {
            bodyStr = body != null ? mapper.writeValueAsString(body) : "{}";
        } catch (Exception e) {
            throw new MisarMailException(0, "Failed to serialize request body: " + e.getMessage(), e);
        }

        Exception last = null;
        for (int attempt = 0; attempt < maxRetries; attempt++) {
            if (attempt > 0) {
                try { Thread.sleep(500L * (1L << (attempt - 1))); }
                catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    throw new MisarMailException(0, "Interrupted during retry back-off", ie);
                }
            }

            HttpRequest.Builder rb = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(REQUEST_TIMEOUT)
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .header("Accept", "application/json");

            HttpRequest.BodyPublisher bp = HttpRequest.BodyPublishers.ofString(bodyStr);
            switch (method) {
                case "GET"    -> rb.GET();
                case "POST"   -> rb.POST(bp);
                case "PATCH"  -> rb.method("PATCH", bp);
                case "PUT"    -> rb.PUT(bp);
                case "DELETE" -> rb.DELETE();
                default -> throw new IllegalArgumentException("Unsupported HTTP method: " + method);
            }

            HttpResponse<String> resp;
            try {
                resp = http.send(rb.build(), HttpResponse.BodyHandlers.ofString());
            } catch (IOException | InterruptedException e) {
                if (e instanceof InterruptedException) Thread.currentThread().interrupt();
                last = e;
                continue;
            }

            int status = resp.statusCode();
            if (RETRYABLE.contains(status) && attempt < maxRetries - 1) {
                last = new MisarMailException(status, resp.body());
                continue;
            }
            if (status >= 200 && status < 300) {
                String rb2 = resp.body();
                if (rb2 == null || rb2.isBlank()) return new HashMap<>();
                try { return mapper.readValue(rb2, Map.class); }
                catch (Exception e) { throw new MisarMailException(0, "Failed to parse response: " + e.getMessage(), e); }
            }
            String msg;
            try { msg = (String) mapper.readValue(resp.body(), Map.class).getOrDefault("error", resp.body()); }
            catch (Exception ignored) { msg = resp.body() != null ? resp.body() : "error"; }
            throw new MisarMailException(status, msg);
        }
        String cause = last != null ? last.getMessage() : "unknown";
        throw new MisarMailException(0, "Max retries exceeded: " + cause, last);
    }

    Map<String, Object> req(String method, String path, Object body) throws MisarMailException {
        return requestUrl(method, baseUrl + path, body);
    }

    Map<String, Object> reqApi(String method, String path, Object body) throws MisarMailException {
        return requestUrl(method, apiBase + path, body);
    }

    private CompletableFuture<Map<String, Object>> async(String method, String path, Object body) {
        return CompletableFuture.supplyAsync(() -> {
            try { return req(method, path, body); }
            catch (MisarMailException e) { throw new CompletionException(e); }
        });
    }

    private CompletableFuture<Map<String, Object>> asyncApi(String method, String path, Object body) {
        return CompletableFuture.supplyAsync(() -> {
            try { return reqApi(method, path, body); }
            catch (MisarMailException e) { throw new CompletionException(e); }
        });
    }

    // ── Resources ─────────────────────────────────────────────────────────────

    /** POST /send */
    public final class EmailResource {
        public Map<String, Object> send(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/send", data);
        }
        public CompletableFuture<Map<String, Object>> sendAsync(Map<String, Object> data) {
            return async("POST", "/send", data);
        }
    }

    /** /contacts */
    public final class ContactsResource {
        public Map<String, Object> list(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/contacts" + qs(params), null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/contacts", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/contacts/" + id, null);
        }
        public Map<String, Object> update(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/contacts/" + id, data);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/contacts/" + id, null);
        }
        public Map<String, Object> importContacts(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/contacts/import", data);
        }
        public CompletableFuture<Map<String, Object>> listAsync(Map<String, Object> params) {
            return async("GET", "/contacts" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/contacts", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/contacts/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/contacts/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/contacts/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> importContactsAsync(Map<String, Object> data) {
            return async("POST", "/contacts/import", data);
        }
    }

    /** /campaigns */
    public final class CampaignsResource {
        public Map<String, Object> list(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/campaigns" + qs(params), null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/campaigns", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/campaigns/" + id, null);
        }
        public Map<String, Object> update(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/campaigns/" + id, data);
        }
        public Map<String, Object> send(String id) throws MisarMailException {
            return req("POST", "/campaigns/" + id + "/send", null);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/campaigns/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync(Map<String, Object> params) {
            return async("GET", "/campaigns" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/campaigns", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/campaigns/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/campaigns/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> sendAsync(String id) {
            return async("POST", "/campaigns/" + id + "/send", null);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/campaigns/" + id, null);
        }
    }

    /** /templates */
    public final class TemplatesResource {
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/templates", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/templates", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/templates/" + id, null);
        }
        public Map<String, Object> update(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/templates/" + id, data);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/templates/" + id, null);
        }
        public Map<String, Object> render(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/templates/render", data);
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return async("GET", "/templates", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/templates", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/templates/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/templates/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/templates/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> renderAsync(Map<String, Object> data) {
            return async("POST", "/templates/render", data);
        }
    }

    /** /automations */
    public final class AutomationsResource {
        public Map<String, Object> list(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/automations" + qs(params), null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/automations", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/automations/" + id, null);
        }
        public Map<String, Object> update(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/automations/" + id, data);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/automations/" + id, null);
        }
        public Map<String, Object> activate(String id, boolean active) throws MisarMailException {
            return req("PATCH", "/automations/" + id + "/activate", Map.of("active", active));
        }
        public CompletableFuture<Map<String, Object>> listAsync(Map<String, Object> params) {
            return async("GET", "/automations" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/automations", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/automations/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/automations/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/automations/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> activateAsync(String id, boolean active) {
            return async("PATCH", "/automations/" + id + "/activate", Map.of("active", active));
        }
    }

    /** /domains */
    public final class DomainsResource {
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/domains", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/domains", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/domains/" + id, null);
        }
        public Map<String, Object> verify(String id) throws MisarMailException {
            return req("POST", "/domains/" + id + "/verify", null);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/domains/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return async("GET", "/domains", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/domains", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/domains/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> verifyAsync(String id) {
            return async("POST", "/domains/" + id + "/verify", null);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/domains/" + id, null);
        }
    }

    /** /aliases */
    public final class AliasesResource {
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/aliases", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/aliases", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/aliases/" + id, null);
        }
        public Map<String, Object> update(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/aliases/" + id, data);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/aliases/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return async("GET", "/aliases", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/aliases", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/aliases/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/aliases/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/aliases/" + id, null);
        }
    }

    /** /dedicated-ips */
    public final class DedicatedIpsResource {
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/dedicated-ips", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/dedicated-ips", data);
        }
        public Map<String, Object> update(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/dedicated-ips/" + id, data);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/dedicated-ips/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return async("GET", "/dedicated-ips", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/dedicated-ips", data);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/dedicated-ips/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/dedicated-ips/" + id, null);
        }
    }

    /** /channels */
    public final class ChannelsResource {
        public Map<String, Object> sendWhatsApp(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/channels/whatsapp/send", data);
        }
        public Map<String, Object> sendPush(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/channels/push/send", data);
        }
        public CompletableFuture<Map<String, Object>> sendWhatsAppAsync(Map<String, Object> data) {
            return async("POST", "/channels/whatsapp/send", data);
        }
        public CompletableFuture<Map<String, Object>> sendPushAsync(Map<String, Object> data) {
            return async("POST", "/channels/push/send", data);
        }
    }

    /** /ab-tests */
    public final class AbTestsResource {
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/ab-tests", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/ab-tests", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/ab-tests/" + id, null);
        }
        public Map<String, Object> setWinner(String id, String variantId) throws MisarMailException {
            return req("POST", "/ab-tests/" + id + "/winner", Map.of("variantId", variantId));
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return async("GET", "/ab-tests", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/ab-tests", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/ab-tests/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> setWinnerAsync(String id, String variantId) {
            return async("POST", "/ab-tests/" + id + "/winner", Map.of("variantId", variantId));
        }
    }

    /** /sandbox */
    public final class SandboxResource {
        public Map<String, Object> send(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/sandbox/send", data);
        }
        public Map<String, Object> list(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/sandbox" + qs(params), null);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/sandbox/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> sendAsync(Map<String, Object> data) {
            return async("POST", "/sandbox/send", data);
        }
        public CompletableFuture<Map<String, Object>> listAsync(Map<String, Object> params) {
            return async("GET", "/sandbox" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/sandbox/" + id, null);
        }
    }

    /** /inbound */
    public final class InboundResource {
        public Map<String, Object> list(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/inbound" + qs(params), null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/inbound", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/inbound/" + id, null);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/inbound/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync(Map<String, Object> params) {
            return async("GET", "/inbound" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/inbound", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/inbound/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/inbound/" + id, null);
        }
    }

    /** /analytics */
    public final class AnalyticsResource {
        public Map<String, Object> overview(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/analytics/overview" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> overviewAsync(Map<String, Object> params) {
            return async("GET", "/analytics/overview" + qs(params), null);
        }
    }

    /** /track */
    public final class TrackResource {
        public Map<String, Object> event(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/track/event", data);
        }
        public Map<String, Object> purchase(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/track/purchase", data);
        }
        public CompletableFuture<Map<String, Object>> eventAsync(Map<String, Object> data) {
            return async("POST", "/track/event", data);
        }
        public CompletableFuture<Map<String, Object>> purchaseAsync(Map<String, Object> data) {
            return async("POST", "/track/purchase", data);
        }
    }

    /** /keys */
    public final class KeysResource {
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/keys", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/keys", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/keys/" + id, null);
        }
        public Map<String, Object> revoke(String id) throws MisarMailException {
            return req("DELETE", "/keys/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return async("GET", "/keys", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/keys", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/keys/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> revokeAsync(String id) {
            return async("DELETE", "/keys/" + id, null);
        }
    }

    /** /validate */
    public final class ValidateResource {
        public Map<String, Object> email(String address) throws MisarMailException {
            return req("POST", "/validate/email", Map.of("email", address));
        }
        public CompletableFuture<Map<String, Object>> emailAsync(String address) {
            return async("POST", "/validate/email", Map.of("email", address));
        }
    }

    /** /leads */
    public final class LeadsResource {
        public Map<String, Object> search(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/leads/search", data);
        }
        public Map<String, Object> getJob(String id) throws MisarMailException {
            return req("GET", "/leads/jobs/" + id, null);
        }
        public Map<String, Object> listJobs(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/leads/jobs" + qs(params), null);
        }
        public Map<String, Object> results(String jobId) throws MisarMailException {
            return req("GET", "/leads/jobs/" + jobId + "/results", null);
        }
        public Map<String, Object> importLeads(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/leads/import", data);
        }
        public Map<String, Object> credits() throws MisarMailException {
            return req("GET", "/leads/credits", null);
        }
        public CompletableFuture<Map<String, Object>> searchAsync(Map<String, Object> data) {
            return async("POST", "/leads/search", data);
        }
        public CompletableFuture<Map<String, Object>> getJobAsync(String id) {
            return async("GET", "/leads/jobs/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listJobsAsync(Map<String, Object> params) {
            return async("GET", "/leads/jobs" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> resultsAsync(String jobId) {
            return async("GET", "/leads/jobs/" + jobId + "/results", null);
        }
        public CompletableFuture<Map<String, Object>> importLeadsAsync(Map<String, Object> data) {
            return async("POST", "/leads/import", data);
        }
        public CompletableFuture<Map<String, Object>> creditsAsync() {
            return async("GET", "/leads/credits", null);
        }
    }

    /** /autopilot */
    public final class AutopilotResource {
        public Map<String, Object> start(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/autopilot", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/autopilot/" + id, null);
        }
        public Map<String, Object> list(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/autopilot" + qs(params), null);
        }
        public Map<String, Object> dailyPlan() throws MisarMailException {
            return req("GET", "/autopilot/daily-plan", null);
        }
        public CompletableFuture<Map<String, Object>> startAsync(Map<String, Object> data) {
            return async("POST", "/autopilot", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/autopilot/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync(Map<String, Object> params) {
            return async("GET", "/autopilot" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> dailyPlanAsync() {
            return async("GET", "/autopilot/daily-plan", null);
        }
    }

    /** /sales-agent */
    public final class SalesAgentResource {
        public Map<String, Object> getConfig() throws MisarMailException {
            return req("GET", "/sales-agent/config", null);
        }
        public Map<String, Object> updateConfig(Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/sales-agent/config", data);
        }
        public Map<String, Object> getActions(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/sales-agent/actions" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> getConfigAsync() {
            return async("GET", "/sales-agent/config", null);
        }
        public CompletableFuture<Map<String, Object>> updateConfigAsync(Map<String, Object> data) {
            return async("PATCH", "/sales-agent/config", data);
        }
        public CompletableFuture<Map<String, Object>> getActionsAsync(Map<String, Object> params) {
            return async("GET", "/sales-agent/actions" + qs(params), null);
        }
    }

    /** /crm */
    public final class CrmResource {
        public Map<String, Object> listConversations(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/crm/conversations" + qs(params), null);
        }
        public Map<String, Object> getConversation(String id) throws MisarMailException {
            return req("GET", "/crm/conversations/" + id, null);
        }
        public Map<String, Object> updateConversation(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/crm/conversations/" + id, data);
        }
        public Map<String, Object> listMessages(String conversationId) throws MisarMailException {
            return req("GET", "/crm/conversations/" + conversationId + "/messages", null);
        }
        public Map<String, Object> listDeals(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/crm/deals" + qs(params), null);
        }
        public Map<String, Object> createDeal(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/crm/deals", data);
        }
        public Map<String, Object> getDeal(String id) throws MisarMailException {
            return req("GET", "/crm/deals/" + id, null);
        }
        public Map<String, Object> updateDeal(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/crm/deals/" + id, data);
        }
        public Map<String, Object> deleteDeal(String id) throws MisarMailException {
            return req("DELETE", "/crm/deals/" + id, null);
        }
        public Map<String, Object> listClients(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/crm/clients" + qs(params), null);
        }
        public Map<String, Object> createClient(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/crm/clients", data);
        }
        public CompletableFuture<Map<String, Object>> listConversationsAsync(Map<String, Object> params) {
            return async("GET", "/crm/conversations" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> getConversationAsync(String id) {
            return async("GET", "/crm/conversations/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateConversationAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/crm/conversations/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> listMessagesAsync(String conversationId) {
            return async("GET", "/crm/conversations/" + conversationId + "/messages", null);
        }
        public CompletableFuture<Map<String, Object>> listDealsAsync(Map<String, Object> params) {
            return async("GET", "/crm/deals" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> createDealAsync(Map<String, Object> data) {
            return async("POST", "/crm/deals", data);
        }
        public CompletableFuture<Map<String, Object>> getDealAsync(String id) {
            return async("GET", "/crm/deals/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateDealAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/crm/deals/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> deleteDealAsync(String id) {
            return async("DELETE", "/crm/deals/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listClientsAsync(Map<String, Object> params) {
            return async("GET", "/crm/clients" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> createClientAsync(Map<String, Object> data) {
            return async("POST", "/crm/clients", data);
        }
    }

    /** /webhooks */
    public final class WebhooksResource {
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/webhooks", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return req("POST", "/webhooks", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/webhooks/" + id, null);
        }
        public Map<String, Object> update(String id, Map<String, Object> data) throws MisarMailException {
            return req("PATCH", "/webhooks/" + id, data);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/webhooks/" + id, null);
        }
        public Map<String, Object> test(String id) throws MisarMailException {
            return req("POST", "/webhooks/" + id + "/test", null);
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return async("GET", "/webhooks", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return async("POST", "/webhooks", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return async("GET", "/webhooks/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String id, Map<String, Object> data) {
            return async("PATCH", "/webhooks/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/webhooks/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> testAsync(String id) {
            return async("POST", "/webhooks/" + id + "/test", null);
        }
    }

    /** /usage */
    public final class UsageResource {
        public Map<String, Object> get(Map<String, Object> params) throws MisarMailException {
            return req("GET", "/usage" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> getAsync(Map<String, Object> params) {
            return async("GET", "/usage" + qs(params), null);
        }
    }

    /** /billing (uses apiBase) */
    public final class BillingResource {
        public Map<String, Object> subscription() throws MisarMailException {
            return reqApi("GET", "/billing/subscription", null);
        }
        public Map<String, Object> checkout(Map<String, Object> data) throws MisarMailException {
            return reqApi("POST", "/billing/checkout", data);
        }
        public CompletableFuture<Map<String, Object>> subscriptionAsync() {
            return asyncApi("GET", "/billing/subscription", null);
        }
        public CompletableFuture<Map<String, Object>> checkoutAsync(Map<String, Object> data) {
            return asyncApi("POST", "/billing/checkout", data);
        }
    }

    /** /workspaces (uses apiBase) */
    public final class WorkspacesResource {
        public Map<String, Object> list() throws MisarMailException {
            return reqApi("GET", "/workspaces", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return reqApi("POST", "/workspaces", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return reqApi("GET", "/workspaces/" + id, null);
        }
        public Map<String, Object> update(String id, Map<String, Object> data) throws MisarMailException {
            return reqApi("PATCH", "/workspaces/" + id, data);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return reqApi("DELETE", "/workspaces/" + id, null);
        }
        public Map<String, Object> listMembers(String wsId) throws MisarMailException {
            return reqApi("GET", "/workspaces/" + wsId + "/members", null);
        }
        public Map<String, Object> inviteMember(String wsId, Map<String, Object> data) throws MisarMailException {
            return reqApi("POST", "/workspaces/" + wsId + "/members", data);
        }
        public Map<String, Object> updateMember(String wsId, String userId, Map<String, Object> data) throws MisarMailException {
            return reqApi("PATCH", "/workspaces/" + wsId + "/members/" + userId, data);
        }
        public Map<String, Object> removeMember(String wsId, String userId) throws MisarMailException {
            return reqApi("DELETE", "/workspaces/" + wsId + "/members/" + userId, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return asyncApi("GET", "/workspaces", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return asyncApi("POST", "/workspaces", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return asyncApi("GET", "/workspaces/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String id, Map<String, Object> data) {
            return asyncApi("PATCH", "/workspaces/" + id, data);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return asyncApi("DELETE", "/workspaces/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listMembersAsync(String wsId) {
            return asyncApi("GET", "/workspaces/" + wsId + "/members", null);
        }
        public CompletableFuture<Map<String, Object>> inviteMemberAsync(String wsId, Map<String, Object> data) {
            return asyncApi("POST", "/workspaces/" + wsId + "/members", data);
        }
        public CompletableFuture<Map<String, Object>> updateMemberAsync(String wsId, String userId, Map<String, Object> data) {
            return asyncApi("PATCH", "/workspaces/" + wsId + "/members/" + userId, data);
        }
        public CompletableFuture<Map<String, Object>> removeMemberAsync(String wsId, String userId) {
            return asyncApi("DELETE", "/workspaces/" + wsId + "/members/" + userId, null);
        }
    }
}
