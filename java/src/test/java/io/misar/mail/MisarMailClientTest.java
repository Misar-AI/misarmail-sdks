package io.misar.mail;

import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import javax.net.ssl.SSLContext;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.ByteBuffer;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Flow;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for {@link MisarMailClient}.
 *
 * The real {@link HttpClient} is replaced with a minimal stub that returns
 * a fixed status code and body without making any network calls.
 */
class MisarMailClientTest {

    // -------------------------------------------------------------------------
    // Stub HttpClient
    // -------------------------------------------------------------------------

    /** Creates a stub {@link HttpClient} that always responds with the given status and body. */
    @SuppressWarnings("unchecked")
    private static HttpClient stubClient(int status, String body) {
        return new HttpClient() {
            @Override
            public <T> HttpResponse<T> send(HttpRequest request,
                                            HttpResponse.BodyHandler<T> handler)
                    throws IOException, InterruptedException {
                return stubResponse(request, status, body, handler);
            }

            @Override
            public <T> CompletableFuture<HttpResponse<T>> sendAsync(
                    HttpRequest request, HttpResponse.BodyHandler<T> handler) {
                throw new UnsupportedOperationException("not used in tests");
            }

            @Override
            public Optional<SSLContext> sslContext() { return Optional.empty(); }
            @Override
            public Optional<java.net.ProxySelector> proxy() { return Optional.empty(); }
            @Override
            public java.net.http.HttpClient.Redirect followRedirects() { return Redirect.NORMAL; }
            @Override
            public Optional<java.net.Authenticator> authenticator() { return Optional.empty(); }
            @Override
            public java.net.http.HttpClient.Version version() { return Version.HTTP_1_1; }
            @Override
            public Optional<java.util.concurrent.Executor> executor() { return Optional.empty(); }
            @Override
            public java.net.CookieHandler cookieHandler() { return null; }
            @Override
            public java.time.Duration connectTimeout() { return null; }

            private <T> HttpResponse<T> stubResponse(HttpRequest req, int code, String responseBody,
                                                      HttpResponse.BodyHandler<T> handler) {
                HttpResponse.ResponseInfo info = new HttpResponse.ResponseInfo() {
                    public int statusCode() { return code; }
                    public java.net.http.HttpHeaders headers() {
                        return java.net.http.HttpHeaders.of(java.util.Map.of(), (a, b) -> true);
                    }
                    public HttpClient.Version version() { return HttpClient.Version.HTTP_1_1; }
                };

                HttpResponse.BodySubscriber<T> subscriber = handler.apply(info);
                subscriber.onSubscribe(new Flow.Subscription() {
                    public void request(long n) {}
                    public void cancel() {}
                });
                if (responseBody != null && !responseBody.isEmpty()) {
                    byte[] bytes = responseBody.getBytes(java.nio.charset.StandardCharsets.UTF_8);
                    subscriber.onNext(List.of(ByteBuffer.wrap(bytes)));
                }
                subscriber.onComplete();

                T result = subscriber.getBody().toCompletableFuture().join();
                return new HttpResponse<>() {
                    public int statusCode() { return code; }
                    public HttpRequest request() { return req; }
                    public java.net.http.HttpHeaders headers() {
                        return java.net.http.HttpHeaders.of(java.util.Map.of(), (a, b) -> true);
                    }
                    public T body() { return result; }
                    public Optional<HttpResponse<T>> previousResponse() { return Optional.empty(); }
                    public Optional<URI> uri() { return Optional.of(req.uri()); }
                    public HttpClient.Version version() { return HttpClient.Version.HTTP_1_1; }
                    public Optional<javax.net.ssl.SSLSession> sslSession() { return Optional.empty(); }
                };
            }
        };
    }

    private static MisarMailClient clientWith(int status, String body) {
        return new MisarMailClient.Builder("your_api_key_here")
                .maxRetries(1)
                .httpClient(stubClient(status, body))
                .build();
    }

    // -------------------------------------------------------------------------
    // Tests
    // -------------------------------------------------------------------------

    @Test
    void sendEmail_returns200_parsedResponse() throws Exception {
        MisarMailClient client = clientWith(200, "{\"id\":\"msg_1\",\"status\":\"queued\"}");
        JSONObject result = client.sendEmail(new JSONObject().put("to", "a@b.com"));
        assertEquals("msg_1", result.getString("id"));
        assertEquals("queued", result.getString("status"));
    }

    @Test
    void contactsList_returns200_parsedResponse() throws Exception {
        MisarMailClient client = clientWith(200, "{\"data\":[]}");
        JSONObject result = client.contactsList();
        assertTrue(result.has("data"));
    }

    @Test
    void contactsCreate_returns201_parsedResponse() throws Exception {
        MisarMailClient client = clientWith(201, "{\"id\":\"c1\"}");
        JSONObject result = client.contactsCreate(new JSONObject().put("email", "x@y.com"));
        assertEquals("c1", result.getString("id"));
    }

    @Test
    void analyticsGet_returns200_parsedResponse() throws Exception {
        MisarMailClient client = clientWith(200, "{\"opens\":5,\"clicks\":1}");
        JSONObject result = client.analyticsGet("camp_1");
        assertEquals(5, result.getInt("opens"));
    }

    @Test
    void validateEmail_returns200_parsedResponse() throws Exception {
        MisarMailClient client = clientWith(200, "{\"valid\":true}");
        JSONObject result = client.validateEmail("test@example.com");
        assertTrue(result.getBoolean("valid"));
    }

    @Test
    void templatesRender_returns200_parsedResponse() throws Exception {
        MisarMailClient client = clientWith(200, "{\"html\":\"<p>Hi</p>\"}");
        JSONObject result = client.templatesRender("tmpl_1", new JSONObject().put("name", "User"));
        assertEquals("<p>Hi</p>", result.getString("html"));
    }

    @Test
    void non2xx_throwsMisarMailException_withStatus() {
        MisarMailClient client = clientWith(401, "{\"error\":\"Unauthorized\"}");
        MisarMailException ex = assertThrows(MisarMailException.class,
                () -> client.sendEmail(new JSONObject()));
        assertEquals(401, ex.getStatus());
    }

    @Test
    void emptyBody_on200_returnsEmptyObject() throws Exception {
        MisarMailClient client = clientWith(200, "");
        JSONObject result = client.sandboxList();
        assertEquals(0, result.length());
    }

    @Test
    void trackEvent_returns200_parsedResponse() throws Exception {
        MisarMailClient client = clientWith(200, "{\"tracked\":true}");
        JSONObject result = client.trackEvent(new JSONObject().put("event", "signup"));
        assertTrue(result.getBoolean("tracked"));
    }

    @Test
    void builderRejectsBlankApiKey() {
        assertThrows(IllegalArgumentException.class,
                () -> new MisarMailClient.Builder("").build());
    }
}
