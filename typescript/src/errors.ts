export class MisarMailError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly errorType: string = "api_error",
    readonly details?: unknown,
  ) {
    super(message);
    this.name = "MisarMailError";
  }

  /** The key was rejected outright — missing, revoked, expired, or wrong product. */
  get isUnauthorized(): boolean {
    return this.status === 401;
  }

  /**
   * The key is valid but the account's subscription does not cover this call:
   * the feature is not in the plan, a plan limit is exhausted, or a volume
   * ceiling was hit. Gating is decided server-side from the subscription behind
   * the key, so this is the signal to prompt an upgrade — distinguishing it
   * from a generic failure without parsing error strings.
   */
  get isPlanDenied(): boolean {
    return this.status === 402 || this.status === 403 || this.status === 429;
  }

  /** Worth retrying as-is: transient server or rate-limit conditions. */
  get isRetryable(): boolean {
    return this.status === 429 || (this.status >= 500 && this.status < 600);
  }
}

export class MisarMailNetworkError extends MisarMailError {
  constructor(
    message: string,
    readonly cause?: unknown,
  ) {
    super(0, message, "network_error");
    this.name = "MisarMailNetworkError";
  }
}

/**
 * Thrown when the subscription attached to the API key blocks the call.
 *
 * MisarMail meters per-plan server-side; when an allowance is spent the API
 * answers 429, and when a feature is not on the plan it answers 402. Both
 * carry an upgrade offer.
 *
 * It is a distinct type rather than a generic 429 because retrying cannot help
 * until the allowance resets or the plan changes — the client stops retrying as
 * soon as it sees this. Surface {@link upgradeUrl} rather than reporting a bare
 * failure.
 */
export class MisarMailPlanLimitError extends MisarMailError {
  constructor(
    status: number,
    message: string,
    /** The account's current plan slug, when the API reports it. */
    readonly plan?: string,
    /** Pricing page to send the user to. */
    readonly upgradeUrl?: string,
    /** Seconds until the allowance resets, when the API supplies it. */
    readonly retryAfter?: number,
    /** The feature whose allowance was exhausted. */
    readonly feature?: string,
    details?: unknown,
  ) {
    super(status, message, "plan_limit_exceeded", details);
    this.name = "MisarMailPlanLimitError";
  }
}
