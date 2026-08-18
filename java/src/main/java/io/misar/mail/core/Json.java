package io.misar.mail.core;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.misar.mail.MisarMailException;
import java.util.Map;

/**
 * JSON encoding for the transport.
 *
 * <p>Wrapped in one place so the rest of the SDK never touches the mapper
 * directly and never has to decide what a decode failure means: a body that
 * will not parse is surfaced as an ordinary SDK exception rather than a
 * Jackson-specific one leaking through the public API.
 */
public final class Json {

  private static final ObjectMapper MAPPER = new ObjectMapper();
  private static final TypeReference<Map<String, Object>> OBJECT =
      new TypeReference<>() {};

  private Json() {}

  public static String write(Object value) throws MisarMailException {
    try {
      return MAPPER.writeValueAsString(value);
    } catch (Exception e) {
      throw new MisarMailException(0, "could not encode request body: " + e.getMessage(), "client_error");
    }
  }

  public static Map<String, Object> readObject(String raw) {
    try {
      return MAPPER.readValue(raw, OBJECT);
    } catch (Exception e) {
      // A non-JSON error body is still an error; the status carries the meaning.
      return Map.of();
    }
  }
}
