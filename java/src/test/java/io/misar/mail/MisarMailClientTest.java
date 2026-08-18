package io.misar.mail;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Consumer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Exercises the client against a real HTTP server.
 *
 * The JDK's own {@link HttpServer} rather than a mocking library: the client is
 * built on java.net.http, whose HttpClient cannot be meaningfully subclassed,
 * and the SSE tests need a server that can flush a body in pieces — which is
 * where frame-boundary bugs live.
 */
class MisarMailClientTest {

    private HttpServer server;
    private int port;
    private final Map<String, Consumer<HttpExchange>> routes = new HashMap<>();

    @BeforeEach
    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        port = server.getAddress().getPort();
        server.createContext("/", exchange -> {
            Consumer<HttpExchange> handler = routes.get(exchange.getRequestURI().getPath());
            if (handler == null) {
                respond(exchange, 404, "{\"error\":\"no route\"}", Map.of());
            } else {
                handler.accept(exchange);
            }
        });
        server.setExecutor(null);
        server.start();
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private MisarMailClient client(int maxRetries) {
        String base = "http://127.0.0.1:" + port + "/mail/v1";
        return new MisarMailClient.Builder("test-key")
                .baseUrl(base)
                .apiBase("http://127.0.0.1:" + port + "/mail")
                .maxRetries(maxRetries)
                .build();
    }

    private MisarMailClient client() {
        return client(1);
    }

    private void respond(HttpExchange exchange, int status, String body, Map<String, String> headers) {
        try {
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            headers.forEach((k, v) -> exchange.getResponseHeaders().add(k, v));
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, bytes.length);
            try (OutputStream out = exchange.getResponseBody()) {
                out.write(bytes);
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    /** Writes an SSE body, flushing after each piece so frames arrive split. */
    private void sse(HttpExchange exchange, String... pieces) {
        try {
            exchange.getResponseHeaders().add("Content-Type", "text/event-stream");
            exchange.sendResponseHeaders(200, 0);
            try (OutputStream out = exchange.getResponseBody()) {
                for (String piece : pieces) {
                    out.write(piece.getBytes(StandardCharsets.UTF_8));
                    out.flush();
                }
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    // -------------------------------------------------------------------------
    // REST
    // -------------------------------------------------------------------------

    @Test
    void emailSendReturnsParsedBody() throws Exception {
        routes.put("/mail/v1/send",
                e -> respond(e, 200, "{\"success\":true,\"message_id\":\"msg_123\"}", Map.of()));

        Map<String, Object> result = client().email.send(Map.of("from", "a@b.com"));

        assertEquals(Boolean.TRUE, result.get("success"));
        assertEquals("msg_123", result.get("message_id"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void contactsListReturnsData() throws Exception {
        routes.put("/mail/v1/contacts",
                e -> respond(e, 200, "{\"data\":[{\"id\":\"c1\",\"email\":\"a@b.com\"}],\"total\":1}", Map.of()));

        Map<String, Object> result = client().contacts.list(Map.of());
        List<Map<String, Object>> data = (List<Map<String, Object>>) result.get("data");

        assertEquals("a@b.com", data.get(0).get("email"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void planReportsTheSubscriptionBehindTheKey() throws Exception {
        routes.put("/mail/v1/plan",
                e -> respond(e, 200, "{\"plan\":{\"slug\":\"pro\"},\"limits\":{\"emails_per_month\":50000}}", Map.of()));

        Map<String, Object> result = client().plan.get();
        Map<String, Object> plan = (Map<String, Object>) result.get("plan");

        assertEquals("pro", plan.get("slug"));
    }

    @Test
    void unauthorizedThrowsWithStatus() {
        routes.put("/mail/v1/contacts", e -> respond(e, 401, "{\"error\":\"unauthorized\"}", Map.of()));

        MisarMailException ex = assertThrows(MisarMailException.class,
                () -> client().contacts.list(Map.of()));

        assertEquals(401, ex.getStatus());
    }

    @Test
    @SuppressWarnings("unchecked")
    void retriesA503ThenSucceeds() throws Exception {
        AtomicInteger attempts = new AtomicInteger();
        routes.put("/mail/v1/templates", e -> {
            if (attempts.incrementAndGet() < 3) {
                respond(e, 503, "{\"error\":\"unavailable\"}", Map.of());
            } else {
                respond(e, 200, "{\"data\":[{\"id\":\"t1\"}]}", Map.of());
            }
        });

        Map<String, Object> result = client(3).templates.list();
        List<Map<String, Object>> data = (List<Map<String, Object>>) result.get("data");

        assertEquals("t1", data.get(0).get("id"));
        assertEquals(3, attempts.get());
    }

    // -------------------------------------------------------------------------
    // Plan limits
    // -------------------------------------------------------------------------

    @Test
    void spentAllowanceThrowsPlanLimitAndIsNotRetried() {
        AtomicInteger attempts = new AtomicInteger();
        routes.put("/mail/v1/campaigns", e -> {
            attempts.incrementAndGet();
            respond(e, 429,
                    "{\"code\":\"plan_limit_exceeded\",\"error\":\"monthly campaign allowance spent\","
                            + "\"upgrade\":{\"feature\":\"campaigns\",\"currentPlanSlug\":\"starter\","
                            + "\"urls\":{\"pricing\":\"https://misarmail.com/pricing\"}}}",
                    Map.of("X-Misar-Plan", "starter", "Retry-After", "3600"));
        });

        // maxRetries 3, so a plain retryable 429 would have been retried twice more.
        PlanLimitException ex = assertThrows(PlanLimitException.class,
                () -> client(3).campaigns.create(Map.of("name", "Blast")));

        assertEquals(429, ex.getStatus());
        assertEquals("starter", ex.getPlan());
        assertEquals("campaigns", ex.getFeature());
        assertEquals(Integer.valueOf(3600), ex.getRetryAfter());
        assertEquals("https://misarmail.com/pricing", ex.getUpgradeUrl());

        // A spent allowance cannot be fixed by retrying.
        assertEquals(1, attempts.get());
    }

    // -------------------------------------------------------------------------
    // Server-Sent Events
    // -------------------------------------------------------------------------

    @Test
    void generateEmailDeliversEachFrame() throws Exception {
        routes.put("/mail/ai/generate-email/stream", e -> sse(e,
                // The frame boundary is deliberately split across two writes.
                "data: {\"delta\":\"Hel\"}\n",
                "\ndata: {\"delta\":\"lo\"}\n\n",
                ": keepalive\n\n",
                "data: {\"delta\":\"!\"}\n\n",
                "data: [DONE]\n\n"));

        List<String> deltas = new ArrayList<>();
        client().streaming.generateEmail(Map.of("prompt", "hi"),
                frame -> deltas.add((String) frame.data().get("delta")));

        assertEquals(List.of("Hel", "lo", "!"), deltas);
    }

    @Test
    void streamStopsAtDoneSentinel() throws Exception {
        routes.put("/mail/campaigns/camp1/send-stream", e -> sse(e,
                "data: {\"sent\":1}\n\n",
                "data: [DONE]\n\n",
                "data: {\"sent\":999}\n\n"));

        List<String> seen = new ArrayList<>();
        client().streaming.campaignSend("camp1", frame -> seen.add(frame.raw()));

        // Anything after the sentinel must never be delivered.
        assertEquals(List.of("{\"sent\":1}"), seen);
    }

    @Test
    void streamUsesTheUnversionedApiBase() throws Exception {
        // Registering the path without /v1 is the assertion: a versioned base
        // would 404 and this would throw.
        routes.put("/mail/campaigns/camp1/send-stream", e -> sse(e, "data: [DONE]\n\n"));

        List<String> seen = new ArrayList<>();
        client().streaming.campaignSend("camp1", frame -> seen.add(frame.raw()));

        assertTrue(seen.isEmpty());
    }

    @Test
    void streamRefusalThrowsPlanLimitBeforeAnyFrame() {
        routes.put("/mail/campaigns/locked/send-stream", e -> respond(e, 402,
                "{\"code\":\"plan_limit_exceeded\",\"error\":\"streaming is not on your plan\","
                        + "\"upgrade\":{\"feature\":\"campaign_streaming\","
                        + "\"urls\":{\"pricing\":\"https://misarmail.com/pricing\"}}}",
                Map.of("X-Misar-Plan", "free")));

        PlanLimitException ex = assertThrows(PlanLimitException.class,
                () -> client().streaming.campaignSend("locked",
                        frame -> { throw new AssertionError("no frame on a refusal"); }));

        assertEquals(402, ex.getStatus());
        assertEquals("free", ex.getPlan());
        assertEquals("campaign_streaming", ex.getFeature());
    }

    @Test
    void nonJsonStreamPayloadStillArrivesAsRaw() throws Exception {
        routes.put("/mail/campaigns/camp1/send-stream", e -> sse(e,
                "data: not json\n\n",
                "data: [DONE]\n\n"));

        List<MisarMailClient.StreamEvent> seen = new ArrayList<>();
        client().streaming.campaignSend("camp1", seen::add);

        assertEquals(1, seen.size());
        assertNull(seen.get(0).data());
        assertEquals("not json", seen.get(0).raw());
    }
}
