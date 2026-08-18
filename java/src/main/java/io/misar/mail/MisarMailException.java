package io.misar.mail;

/** Raised for any non-2xx response, and for transport failures with status 0. */
public class MisarMailException extends Exception {

  private final int status;
  private final String errorType;

  public MisarMailException(int status, String message, String errorType) {
    super("misar-mail: API error " + status + " (" + errorType + "): " + message);
    this.status = status;
    this.errorType = errorType;
  }

  public int status() {
    return status;
  }

  public String errorType() {
    return errorType;
  }

  /**
   * The key was rejected outright — missing, revoked, expired, or issued for a
   * different product.
   */
  public boolean isUnauthorized() {
    return status == 401;
  }

  /**
   * The key is valid but the account's subscription does not cover this call:
   * the feature is not in the plan, a plan limit is exhausted, or a volume
   * ceiling was hit. Gating is decided server-side from the subscription behind
   * the key, so this is the signal to prompt an upgrade — without parsing error
   * strings.
   */
  public boolean isPlanDenied() {
    return status == 402 || status == 403 || status == 429;
  }

  /** Worth retrying as-is: transient server or rate-limit conditions. */
  public boolean isRetryable() {
    return status == 429 || (status >= 500 && status < 600);
  }
}
