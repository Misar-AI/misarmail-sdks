package io.misar.mail.core;

import io.misar.mail.MisarMailException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * HTTP transport shared by the generated resource layer.
 *
 * <p>Everything the SDK does goes through one of three transports — HTTP for
 * REST, SSE for streaming, WebSocket for push — and all three authenticate the
 * same way: the account API key, sent as a bearer token. There is no second
 * credential path. What a key may do, and how much of it, is decided
 * server-side from the subscription behind that key.
 *
 * <p>Built on {@link java.net.http.HttpClient} so the SDK needs no third-party
 * HTTP dependency.
 */
public final class Transport {

  private static final Set<Integer> RETRYABLE = Set.of(429, 500, 502, 503, 504);

  private final String apiKey;
  private final String baseUrl;
  private final int maxRetries;
  private final HttpClient http;

  public Transport(String apiKey, String baseUrl, int maxRetries, Duration timeout) {
    if (apiKey == null || apiKey.isEmpty()) {
      throw new IllegalArgumentException(
          "A MisarMail API key is required. Create one at https://mail.misar.io/settings/api-keys.");
    }
    this.apiKey = apiKey;
    this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
    this.maxRetries = maxRetries;
    this.http = HttpClient.newBuilder().connectTimeout(timeout).build();
  }

  public String apiKey() {
    return apiKey;
  }

  public String baseUrl() {
    return baseUrl;
  }

  /** Issues a request against a manifest path and decodes the JSON body. */
  public Map<String, Object> request(String method, String path, Object body)
      throws MisarMailException {
    String url = baseUrl + path;

    for (int attempt = 0; ; attempt++) {
      try {
        HttpRequest.BodyPublisher publisher =
            body == null
                ? HttpRequest.BodyPublishers.noBody()
                : HttpRequest.BodyPublishers.ofString(Json.write(body));

        HttpRequest request =
            HttpRequest.newBuilder(URI.create(url))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .method(method, publisher)
                .build();

        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());

        if (RETRYABLE.contains(response.statusCode()) && attempt < maxRetries - 1) {
          Thread.sleep(backoffMillis(attempt, response));
          continue;
        }

        return decode(response);
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        throw new MisarMailException(0, "interrupted", "network_error");
      } catch (MisarMailException e) {
        throw e;
      } catch (Exception e) {
        if (attempt < maxRetries - 1) {
          try {
            Thread.sleep(backoffMillis(attempt, null));
          } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
            throw new MisarMailException(0, "interrupted", "network_error");
          }
          continue;
        }
        throw new MisarMailException(0, e.getMessage(), "network_error");
      }
    }
  }

  private Map<String, Object> decode(HttpResponse<String> response) throws MisarMailException {
    String raw = response.body();
    Map<String, Object> data = (raw == null || raw.isEmpty()) ? Map.of() : Json.readObject(raw);

    if (response.statusCode() >= 400) {
      Object message = data.get("error");
      if (message == null) {
        message = data.get("message");
      }
      throw new MisarMailException(
          response.statusCode(),
          message == null ? "HTTP " + response.statusCode() : String.valueOf(message),
          String.valueOf(data.getOrDefault("error_type", "api_error")));
    }

    return data;
  }

  /**
   * Exponential backoff, but honours {@code Retry-After} when the server sends
   * one: on a 429 the server knows when the window reopens, and guessing wastes
   * the caller's remaining budget.
   */
  private long backoffMillis(int attempt, HttpResponse<String> response) {
    if (response != null) {
      List<String> header = response.headers().allValues("retry-after");
      if (!header.isEmpty()) {
        try {
          long seconds = Long.parseLong(header.get(0).trim());
          if (seconds >= 0) {
            return Math.min(seconds, 60) * 1000L;
          }
        } catch (NumberFormatException ignored) {
          // Fall through to exponential backoff.
        }
      }
    }
    return 200L * (1L << attempt);
  }
}
