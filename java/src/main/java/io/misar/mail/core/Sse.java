package io.misar.mail.core;

import io.misar.mail.MisarMailException;
import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.function.Consumer;

/**
 * Server-Sent Events client for the MisarMail streaming endpoints.
 *
 * <p>Both streams frame events as {@code data: <json>} and close with the
 * sentinel {@code data: [DONE]}. One of the two is a POST, so the stream is
 * driven off a normal request with a streamed body rather than an
 * EventSource-style helper.
 */
public final class Sse {

  private static final String DONE = "[DONE]";

  private Sse() {}

  /**
   * Opens an SSE endpoint and hands each decoded frame to {@code onEvent} until
   * the stream terminates. Blocks the calling thread for the life of the stream.
   */
  public static void stream(
      String url, String apiKey, String method, String jsonBody, Consumer<Map<String, Object>> onEvent)
      throws MisarMailException {

    // A stream has no useful deadline, so it deliberately gets its own client
    // rather than inheriting the transport's per-request timeout.
    HttpClient http = HttpClient.newHttpClient();

    HttpRequest.Builder builder =
        HttpRequest.newBuilder(URI.create(url))
            .header("Authorization", "Bearer " + apiKey)
            .header("Accept", "text/event-stream");

    if (jsonBody != null) {
      builder.header("Content-Type", "application/json");
      builder.method(method, HttpRequest.BodyPublishers.ofString(jsonBody));
    } else {
      builder.method(method, HttpRequest.BodyPublishers.noBody());
    }

    try {
      HttpResponse<InputStream> response =
          http.send(builder.build(), HttpResponse.BodyHandlers.ofInputStream());

      if (response.statusCode() >= 400) {
        // Errors arrive as a normal JSON body, not as an SSE frame.
        String raw = new String(response.body().readAllBytes(), StandardCharsets.UTF_8);
        Map<String, Object> data = Json.readObject(raw);
        throw new MisarMailException(
            response.statusCode(),
            String.valueOf(data.getOrDefault("error", "stream failed")),
            "api_error");
      }

      try (BufferedReader reader =
          new BufferedReader(new InputStreamReader(response.body(), StandardCharsets.UTF_8))) {
        String line;
        while ((line = reader.readLine()) != null) {
          if (!line.startsWith("data:")) {
            continue;
          }
          String payload = line.substring(5).trim();
          if (DONE.equals(payload)) {
            return;
          }
          if (payload.isEmpty()) {
            continue;
          }
          Map<String, Object> decoded = Json.readObject(payload);
          // An unparseable frame surfaces as {"raw": ...} rather than killing
          // the stream and discarding everything already delivered.
          onEvent.accept(decoded.isEmpty() ? Map.of("raw", payload) : decoded);
        }
      }
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      throw new MisarMailException(0, "interrupted", "network_error");
    } catch (MisarMailException e) {
      throw e;
    } catch (Exception e) {
      throw new MisarMailException(0, e.getMessage(), "network_error");
    }
  }
}
