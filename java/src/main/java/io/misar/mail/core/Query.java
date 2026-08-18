package io.misar.mail.core;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

/** Query-string encoding shared by every generated GET/DELETE method. */
public final class Query {

  private Query() {}

  /**
   * Returns "" for a null or empty bag so a generated call site can always
   * append unconditionally. Null values are dropped so optional filters stay
   * out of the URL entirely rather than being sent as the string "null".
   */
  public static String encode(Map<String, String> params) {
    if (params == null || params.isEmpty()) {
      return "";
    }

    StringBuilder out = new StringBuilder();
    for (Map.Entry<String, String> entry : params.entrySet()) {
      if (entry.getValue() == null) {
        continue;
      }
      out.append(out.length() == 0 ? '?' : '&')
          .append(enc(entry.getKey()))
          .append('=')
          .append(enc(entry.getValue()));
    }
    return out.toString();
  }

  /**
   * Merges required query parameters under a caller-supplied bag, so an
   * explicit override still wins. Takes the extras as alternating key/value
   * arguments because the generated call sites always know them at compile time.
   */
  public static Map<String, String> with(Map<String, String> params, String... keyValuePairs) {
    Map<String, String> merged = new LinkedHashMap<>();
    for (int i = 0; i + 1 < keyValuePairs.length; i += 2) {
      merged.put(keyValuePairs[i], keyValuePairs[i + 1]);
    }
    if (params != null) {
      merged.putAll(params);
    }
    return merged;
  }

  /** Percent-encodes a single path or query component. */
  public static String enc(String value) {
    return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
  }
}
