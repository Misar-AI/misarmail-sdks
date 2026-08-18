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
import java.util.LinkedHashMap;
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
    public final PlanResource plan;
    public final StreamingResource streaming;
    public final AiResource ai;
    public final CreditRatesResource creditRates;
    public final DeliverabilityResource deliverability;
    public final DmarcResource dmarc;
    public final EmailAccountsResource emailAccounts;
    public final EmailsResource emails;
    public final LandingPagesResource landingPages;
    public final MonetizationResource monetization;
    public final RevenueResource revenue;
    public final SegmentsResource segments;
    public final SubscriptionResource subscription;
    public final TeamMembersResource teamMembers;
    public final WalletResource wallet;
    public final WarmupResource warmup;
    public final EmailResource email;
    public final ContactsResource contacts;
    public final CampaignsResource campaigns;
    public final TemplatesResource templates;
    public final AutomationsResource automations;
    public final DomainsResource domains;
    public final DedicatedIpsResource dedicatedIps;
    public final AbTestsResource abTests;
    public final SandboxResource sandbox;
    public final InboundResource inbound;
    public final AnalyticsResource analytics;
    public final TrackResource track;
    public final KeysResource keys;
    public final ValidateResource validate;
    public final WebhooksResource webhooks;
    public final UsageResource usage;
    public final BillingResource billing;

    private MisarMailClient(Builder b) {
        this.apiKey = b.apiKey;
        this.baseUrl = b.baseUrl.endsWith("/") ? b.baseUrl.substring(0, b.baseUrl.length() - 1) : b.baseUrl;
        this.apiBase = b.apiBase.endsWith("/") ? b.apiBase.substring(0, b.apiBase.length() - 1) : b.apiBase;
        this.maxRetries = b.maxRetries;
        this.http = b.httpClient != null ? b.httpClient
                : HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build();

        this.plan = new PlanResource();
        this.streaming = new StreamingResource();
        this.ai = new AiResource();
        this.creditRates = new CreditRatesResource();
        this.deliverability = new DeliverabilityResource();
        this.dmarc = new DmarcResource();
        this.emailAccounts = new EmailAccountsResource();
        this.emails = new EmailsResource();
        this.landingPages = new LandingPagesResource();
        this.monetization = new MonetizationResource();
        this.revenue = new RevenueResource();
        this.segments = new SegmentsResource();
        this.subscription = new SubscriptionResource();
        this.teamMembers = new TeamMembersResource();
        this.wallet = new WalletResource();
        this.warmup = new WarmupResource();

        this.email = new EmailResource();
        this.contacts = new ContactsResource();
        this.campaigns = new CampaignsResource();
        this.templates = new TemplatesResource();
        this.automations = new AutomationsResource();
        this.domains = new DomainsResource();
        this.dedicatedIps = new DedicatedIpsResource();
        this.abTests = new AbTestsResource();
        this.sandbox = new SandboxResource();
        this.inbound = new InboundResource();
        this.analytics = new AnalyticsResource();
        this.track = new TrackResource();
        this.keys = new KeysResource();
        this.validate = new ValidateResource();
        this.webhooks = new WebhooksResource();
        this.usage = new UsageResource();
        this.billing = new BillingResource();
    }

    // ── Builder ───────────────────────────────────────────────────────────────

    public static final class Builder {
        private final String apiKey;
        private String baseUrl = "https://api.misar.io/mail/v1";
        private String apiBase = "https://api.misar.io/mail";
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

            // A rate-limit 429 and a spent-allowance 429 are identical by
            // status, so the body decides. Only the first is worth retrying.
            if (isPlanLimit(resp.body())) {
                throw planLimitException(status, resp);
            }

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

    /** Pulls the human-readable message out of an error envelope. */
    @SuppressWarnings("unchecked")
    private String messageFrom(String body) {
        if (body == null || body.isBlank()) return "error";
        try {
            Object err = mapper.readValue(body, Map.class).get("error");
            if (err != null) return String.valueOf(err);
        } catch (Exception ignored) {
            // not JSON — fall through to the raw body
        }
        return body;
    }

    /** True when the body carries the API's plan-refusal marker. */
    @SuppressWarnings("unchecked")
    private boolean isPlanLimit(String body) {
        if (body == null || body.isBlank()) return false;
        try {
            Map<String, Object> m = mapper.readValue(body, Map.class);
            return "plan_limit_exceeded".equals(m.get("code"))
                    || "plan_limit_exceeded".equals(m.get("error_type"))
                    || m.get("upgrade") instanceof Map;
        } catch (Exception ignored) {
            return false;
        }
    }

    @SuppressWarnings("unchecked")
    private PlanLimitException planLimitException(int status, java.net.http.HttpResponse<String> resp) {
        String message = "plan limit exceeded";
        String plan = null, upgradeUrl = null, feature = null;

        try {
            Map<String, Object> root = mapper.readValue(resp.body(), Map.class);
            if (root.get("error") instanceof String e) message = e;
            if (root.get("upgrade") instanceof Map<?, ?> offer) {
                if (offer.get("currentPlanSlug") != null) plan = String.valueOf(offer.get("currentPlanSlug"));
                else if (offer.get("current_plan") instanceof Map<?, ?> cp && cp.get("slug") != null)
                    plan = String.valueOf(cp.get("slug"));
                if (offer.get("urls") instanceof Map<?, ?> urls && urls.get("pricing") != null)
                    upgradeUrl = String.valueOf(urls.get("pricing"));
                if (offer.get("feature") != null) feature = String.valueOf(offer.get("feature"));
            }
        } catch (Exception ignored) {
            // non-JSON body — headers below are the only source
        }

        // Headers are authoritative; the offer body is the fallback when a
        // proxy has stripped them.
        plan = resp.headers().firstValue("x-misar-plan").orElse(plan);
        upgradeUrl = resp.headers().firstValue("x-misar-upgrade-url").orElse(upgradeUrl);
        Integer retryAfter = resp.headers().firstValue("retry-after")
                .filter(v -> v.chars().allMatch(Character::isDigit))
                .map(Integer::valueOf)
                .orElse(null);

        return new PlanLimitException(status, message, plan, upgradeUrl, retryAfter, feature);
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
            return req("GET", "/contacts?id=" + enc(id), null);
        }
        public Map<String, Object> update(String email, Map<String, Object> data) throws MisarMailException {
            Map<String, Object> body = new HashMap<>(data);
            body.put("email", email);
            return req("PATCH", "/contacts", body);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return req("DELETE", "/contacts?id=" + enc(id), null);
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
            return async("GET", "/contacts?id=" + enc(id), null);
        }
        public CompletableFuture<Map<String, Object>> updateAsync(String email, Map<String, Object> data) {
            Map<String, Object> body = new HashMap<>(data);
            body.put("email", email);
            return async("PATCH", "/contacts", body);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return async("DELETE", "/contacts?id=" + enc(id), null);
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
            return reqApi("GET", "/domains", null);
        }
        public Map<String, Object> create(Map<String, Object> data) throws MisarMailException {
            return reqApi("POST", "/domains", data);
        }
        public Map<String, Object> get(String id) throws MisarMailException {
            return reqApi("GET", "/domains/" + id, null);
        }
        public Map<String, Object> verify(String id) throws MisarMailException {
            return reqApi("POST", "/domains/" + id + "/verify", null);
        }
        public Map<String, Object> delete(String id) throws MisarMailException {
            return reqApi("DELETE", "/domains/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> listAsync() {
            return asyncApi("GET", "/domains", null);
        }
        public CompletableFuture<Map<String, Object>> createAsync(Map<String, Object> data) {
            return asyncApi("POST", "/domains", data);
        }
        public CompletableFuture<Map<String, Object>> getAsync(String id) {
            return asyncApi("GET", "/domains/" + id, null);
        }
        public CompletableFuture<Map<String, Object>> verifyAsync(String id) {
            return asyncApi("POST", "/domains/" + id + "/verify", null);
        }
        public CompletableFuture<Map<String, Object>> deleteAsync(String id) {
            return asyncApi("DELETE", "/domains/" + id, null);
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
            return req("GET", "/analytics" + qs(params), null);
        }
        public CompletableFuture<Map<String, Object>> overviewAsync(Map<String, Object> params) {
            return async("GET", "/analytics" + qs(params), null);
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
            return req("POST", "/validate", Map.of("email", address));
        }
        public CompletableFuture<Map<String, Object>> emailAsync(String address) {
            return async("POST", "/validate", Map.of("email", address));
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


    /**
     * Live subscription standing for the key's owner.
     *
     * <p>Read this before an expensive call rather than discovering the ceiling
     * through a {@link PlanLimitException}: {@code usage} reports every metered
     * feature and {@code upgrade} is non-null as soon as one is spent.
     */
    public final class PlanResource {
        /** {@code GET /plan} — plan, allowances, per-feature usage, upgrade offer. */
        public Map<String, Object> get() throws MisarMailException {
            return req("GET", "/plan", null);
        }

        /** {@code GET /monetization/stats} — revenue and monetization counters. */
        public Map<String, Object> monetization() throws MisarMailException {
            return req("GET", "/monetization/stats", null);
        }
    }

    // ── Generated from scripts/sdk-endpoint-spec.json ────────────────────────
    //
    // These twenty endpoints were missing from every SDK except TypeScript.

    /** ai — generated. */
    public final class AiResource {
        /** {@code POST /ai/subject-lines} */
        public Map<String, Object> subjectLines(Map<String, Object> body) throws MisarMailException {
            return req("POST", "/ai/subject-lines", body);
        }

    }

    /** creditRates — generated. */
    public final class CreditRatesResource {
        /** {@code GET /credit-rates} */
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/credit-rates", null);
        }

    }

    /** deliverability — generated. */
    public final class DeliverabilityResource {
        /** {@code GET /deliverability/audit} */
        public Map<String, Object> audit() throws MisarMailException {
            return req("GET", "/deliverability/audit", null);
        }

        /** {@code GET /deliverability/score} */
        public Map<String, Object> score() throws MisarMailException {
            return req("GET", "/deliverability/score", null);
        }

    }

    /** dmarc — generated. */
    public final class DmarcResource {
        /** {@code GET /dmarc/check} */
        public Map<String, Object> check(String domain, String dkim_selector) throws MisarMailException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (domain != null) p.put("domain", domain);
            if (dkim_selector != null) p.put("dkim_selector", dkim_selector);
            return req("GET", "/dmarc/check" + qs(p), null);
        }

        /** {@code GET /dmarc/domains} */
        public Map<String, Object> listDomains() throws MisarMailException {
            return req("GET", "/dmarc/domains", null);
        }

        /** {@code POST /dmarc/domains} */
        public Map<String, Object> addDomain(Map<String, Object> body) throws MisarMailException {
            return req("POST", "/dmarc/domains", body);
        }

        /** {@code DELETE /dmarc/domains} */
        public Map<String, Object> removeDomain(String domain_id) throws MisarMailException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (domain_id != null) p.put("domain_id", domain_id);
            return req("DELETE", "/dmarc/domains" + qs(p), null);
        }

    }

    /** emailAccounts — generated. */
    public final class EmailAccountsResource {
        /** {@code GET /email-accounts} */
        public Map<String, Object> list() throws MisarMailException {
            return req("GET", "/email-accounts", null);
        }

    }

    /** emails — generated. */
    public final class EmailsResource {
        /** {@code GET /emails} */
        public Map<String, Object> list(String folder, String search, Integer limit) throws MisarMailException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (folder != null) p.put("folder", folder);
            if (search != null) p.put("search", search);
            if (limit != null) p.put("limit", limit);
            return req("GET", "/emails" + qs(p), null);
        }

        /** {@code GET /emails/:id} */
        public Map<String, Object> get(String id) throws MisarMailException {
            return req("GET", "/emails/" + enc(id), null);
        }

        /** {@code PATCH /emails/:id} */
        public Map<String, Object> update(String id, Map<String, Object> body) throws MisarMailException {
            return req("PATCH", "/emails/" + enc(id), body);
        }

    }

    /** landingPages — generated. */
    public final class LandingPagesResource {
        /** {@code POST /landing-pages} */
        public Map<String, Object> create(Map<String, Object> body) throws MisarMailException {
            return req("POST", "/landing-pages", body);
        }

    }

    /** monetization — generated. */
    public final class MonetizationResource {
        /** {@code POST /monetization/tip} */
        public Map<String, Object> tip(Map<String, Object> body) throws MisarMailException {
            return req("POST", "/monetization/tip", body);
        }

    }

    /** revenue — generated. */
    public final class RevenueResource {
        /** {@code GET /revenue/attribution} */
        public Map<String, Object> attribution(String campaign_id, String period) throws MisarMailException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (campaign_id != null) p.put("campaign_id", campaign_id);
            if (period != null) p.put("period", period);
            return req("GET", "/revenue/attribution" + qs(p), null);
        }

    }

    /** segments — generated. */
    public final class SegmentsResource {
        /** {@code GET /segments/:id/members} */
        public Map<String, Object> members(String id, Integer page, Integer limit) throws MisarMailException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (page != null) p.put("page", page);
            if (limit != null) p.put("limit", limit);
            return req("GET", "/segments/" + enc(id) + "/members" + qs(p), null);
        }

    }

    /** subscription — generated. */
    public final class SubscriptionResource {
        /** {@code GET /subscription} */
        public Map<String, Object> get(String product) throws MisarMailException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (product != null) p.put("product", product);
            return req("GET", "/subscription" + qs(p), null);
        }

        /** {@code POST /subscription} */
        public Map<String, Object> upsert(Map<String, Object> body) throws MisarMailException {
            return req("POST", "/subscription", body);
        }

        /** {@code DELETE /subscription} */
        public Map<String, Object> cancel(Map<String, Object> body) throws MisarMailException {
            return req("DELETE", "/subscription", body);
        }

    }

    /** teamMembers — generated. */
    public final class TeamMembersResource {
        /** {@code GET /team-members} */
        public Map<String, Object> get(String owner_id) throws MisarMailException {
            Map<String, Object> p = new LinkedHashMap<>();
            if (owner_id != null) p.put("owner_id", owner_id);
            return req("GET", "/team-members" + qs(p), null);
        }

    }

    /** wallet — generated. */
    public final class WalletResource {
        /** {@code GET /wallet} */
        public Map<String, Object> get() throws MisarMailException {
            return req("GET", "/wallet", null);
        }

        /** {@code POST /wallet/credit} */
        public Map<String, Object> credit(Map<String, Object> body) throws MisarMailException {
            return req("POST", "/wallet/credit", body);
        }

        /** {@code POST /wallet/debit} */
        public Map<String, Object> debit(Map<String, Object> body) throws MisarMailException {
            return req("POST", "/wallet/debit", body);
        }

    }

    /** warmup — generated. */
    public final class WarmupResource {
        /** {@code GET /warmup} */
        public Map<String, Object> get() throws MisarMailException {
            return req("GET", "/warmup", null);
        }

    }

    // ── Server-Sent Events ───────────────────────────────────────────────────

    /**
     * One decoded SSE frame.
     *
     * <p>MisarMail emits unnamed frames — {@code data: {...}} with no
     * {@code event:} line — so {@link #event()} is normally null. {@link #data()}
     * is the decoded JSON; {@link #raw()} is always the payload as received.
     */
    public record StreamEvent(String event, Map<String, Object> data, String raw) {}

    /**
     * The two Server-Sent Events endpoints.
     *
     * <p>Both live outside {@code /v1}, so they use the API base. Both are
     * API-key authenticated and metered, so a plan refusal on open throws
     * {@link PlanLimitException} exactly as a non-streaming call would.
     */
    public final class StreamingResource {

        /**
         * {@code POST /api/ai/generate-email/stream} — token-by-token generation.
         *
         * <p>{@code onEvent} is invoked per frame. Throwing from it stops the
         * stream and propagates, which is how a caller breaks out early.
         */
        public void generateEmail(Map<String, Object> body, java.util.function.Consumer<StreamEvent> onEvent)
                throws MisarMailException {
            stream("POST", "/ai/generate-email/stream", body, onEvent);
        }

        /** {@code GET /api/campaigns/{id}/send-stream} — live send progress. */
        public void campaignSend(String campaignId, java.util.function.Consumer<StreamEvent> onEvent)
                throws MisarMailException {
            stream("GET", "/campaigns/" + enc(campaignId) + "/send-stream", null, onEvent);
        }
    }

    /**
     * Opens an SSE connection and dispatches each frame.
     *
     * <p>Deliberately not retried: replaying a stream that failed mid-flight
     * would duplicate whatever the caller already consumed.
     */
    @SuppressWarnings("unchecked")
    private void stream(
            String method, String path, Map<String, Object> body, java.util.function.Consumer<StreamEvent> onEvent)
            throws MisarMailException {

        HttpRequest.BodyPublisher publisher;
        try {
            publisher = body == null
                    ? HttpRequest.BodyPublishers.noBody()
                    : HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(body));
        } catch (Exception e) {
            throw new MisarMailException(0, "Failed to serialize request body: " + e.getMessage(), e);
        }

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(apiBase + path))
                .header("Authorization", "Bearer " + apiKey)
                .header("Accept", "text/event-stream")
                .header("Content-Type", "application/json")
                .method(method, publisher)
                .build();

        HttpResponse<java.util.stream.Stream<String>> resp;
        try {
            resp = http.send(request, HttpResponse.BodyHandlers.ofLines());
        } catch (IOException | InterruptedException e) {
            if (e instanceof InterruptedException) Thread.currentThread().interrupt();
            throw new MisarMailException(0, "stream failed: " + e.getMessage(), e);
        }

        int status = resp.statusCode();
        if (status < 200 || status >= 300) {
            // The body is a line stream even on an error, so rejoin it to read
            // the JSON envelope.
            String raw = resp.body().collect(Collectors.joining("\n"));
            if (isPlanLimit(raw)) {
                throw planLimitFromBody(status, raw, resp);
            }
            throw new MisarMailException(status, messageFrom(raw));
        }

        String[] eventName = {null};
        java.util.List<String> dataLines = new java.util.ArrayList<>();

        // ofLines() already splits on line terminators, so a frame ends at the
        // first empty line rather than at a "\n\n" scan.
        java.util.Iterator<String> it = resp.body().iterator();
        while (it.hasNext()) {
            String line = it.next();

            if (line.isEmpty()) {
                if (flushFrame(eventName, dataLines, onEvent)) return; // [DONE]
                continue;
            }
            if (line.startsWith(":")) continue; // keepalive
            if (line.startsWith("event:")) {
                eventName[0] = line.substring(6).trim();
            } else if (line.startsWith("data:")) {
                String rest = line.substring(5);
                dataLines.add(rest.startsWith(" ") ? rest.substring(1) : rest);
            }
        }
        // A final frame with no trailing blank line.
        flushFrame(eventName, dataLines, onEvent);
    }

    /** Dispatches an accumulated frame. Returns true when it was the sentinel. */
    @SuppressWarnings("unchecked")
    private boolean flushFrame(
            String[] eventName, java.util.List<String> dataLines, java.util.function.Consumer<StreamEvent> onEvent) {
        if (dataLines.isEmpty()) {
            eventName[0] = null;
            return false;
        }
        String raw = String.join("\n", dataLines);
        String name = eventName[0];
        dataLines.clear();
        eventName[0] = null;

        if ("[DONE]".equals(raw)) return true;

        Map<String, Object> decoded = null;
        try {
            decoded = mapper.readValue(raw, Map.class);
        } catch (Exception ignored) {
            // not JSON — raw still carries the payload
        }
        onEvent.accept(new StreamEvent(name, decoded, raw));
        return false;
    }

    /** Builds a PlanLimitException from an already-read body. */
    @SuppressWarnings("unchecked")
    private PlanLimitException planLimitFromBody(int status, String raw, HttpResponse<?> resp) {
        String message = messageFrom(raw);
        String plan = null, upgradeUrl = null, feature = null;
        try {
            Map<String, Object> root = mapper.readValue(raw, Map.class);
            if (root.get("upgrade") instanceof Map<?, ?> offer) {
                if (offer.get("currentPlanSlug") != null) plan = String.valueOf(offer.get("currentPlanSlug"));
                if (offer.get("feature") != null) feature = String.valueOf(offer.get("feature"));
                if (offer.get("urls") instanceof Map<?, ?> urls && urls.get("pricing") != null)
                    upgradeUrl = String.valueOf(urls.get("pricing"));
            }
        } catch (Exception ignored) {
            // headers below are the only source
        }
        plan = resp.headers().firstValue("x-misar-plan").orElse(plan);
        upgradeUrl = resp.headers().firstValue("x-misar-upgrade-url").orElse(upgradeUrl);
        Integer retryAfter = resp.headers().firstValue("retry-after")
                .filter(v -> v.chars().allMatch(Character::isDigit))
                .map(Integer::valueOf)
                .orElse(null);
        return new PlanLimitException(status, message, plan, upgradeUrl, retryAfter, feature);
    }
}
