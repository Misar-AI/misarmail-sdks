package io.misar.mail;

/**
 * Thrown when the subscription attached to the API key blocks the call.
 *
 * <p>MisarMail meters per-plan server-side: a spent allowance answers 429 and a
 * feature that is not on the plan answers 402. Both carry an upgrade offer.
 *
 * <p>A distinct type rather than a generic 429 because retrying cannot help
 * until the allowance resets or the plan changes — the client stops retrying as
 * soon as it sees this. Surface {@link #getUpgradeUrl()} rather than reporting
 * a bare failure.
 */
public class PlanLimitException extends MisarMailException {

    private final String plan;
    private final String upgradeUrl;
    private final Integer retryAfter;
    private final String feature;

    public PlanLimitException(
            int status, String message, String plan, String upgradeUrl, Integer retryAfter, String feature) {
        super(status, message);
        this.plan = plan;
        this.upgradeUrl = upgradeUrl;
        this.retryAfter = retryAfter;
        this.feature = feature;
    }

    /** The account's current plan slug, or {@code null} when not reported. */
    public String getPlan() {
        return plan;
    }

    /** Pricing page to send the user to, or {@code null}. */
    public String getUpgradeUrl() {
        return upgradeUrl;
    }

    /** Seconds until the allowance resets, or {@code null}. */
    public Integer getRetryAfter() {
        return retryAfter;
    }

    /** The allowance that was exhausted, or {@code null}. */
    public String getFeature() {
        return feature;
    }
}
